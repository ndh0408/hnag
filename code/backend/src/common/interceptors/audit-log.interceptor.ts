import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
  SetMetadata,
  applyDecorators,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable, tap } from 'rxjs';

import { AnalyticsService } from '../analytics/analytics.service';

const AUDIT_KEY = 'auditLog';

export interface AuditTag {
  /** `<domain>.<action>` — stable across copy iterations. */
  event: string;
  /** Optional severity hint for the dashboard (default 'info'). */
  level?: 'info' | 'warn' | 'critical';
}

/**
 * Decorator that flags a controller method as audit-loggable. Apply on
 * sensitive admin / owner / billing routes so every successful invocation
 * lands in the analytics_events stream tagged `audit:<event>`.
 *
 * Audit prompt-pack §7 ("audit trail"): batch-4 already shipped a deletion-
 * specific audit table (`account_deletions`); this interceptor is the
 * general-purpose version for everything else (admin ban, premium
 * grant, claim approval, role promotion, etc.).
 *
 * Usage:
 *
 *   @Audit({ event: 'admin.user.ban', level: 'critical' })
 *   @Roles('admin')
 *   @Post('admin/users/:id/ban')
 *   ban(@Param('id') id: string) { ... }
 */
export function Audit(tag: AuditTag): MethodDecorator & ClassDecorator {
  return applyDecorators(SetMetadata(AUDIT_KEY, tag));
}

/**
 * Interceptor that fires AFTER the handler returns successfully. Logs
 * (a) into analytics_events for product dashboards, and (b) as a
 * structured warn-level Logger line so Loki/Sentry retain a forensic copy.
 *
 * Failed requests (4xx/5xx) do NOT write an audit row — by design.
 * Failed admin attempts ARE interesting forensics but they're already
 * captured by the throttler / RBAC guard rejections in the pino-http
 * access log. Mixing successful + failed rows into one table makes
 * security review noisier.
 */
@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  private readonly logger = new Logger('Audit');

  constructor(
    private readonly reflector: Reflector,
    private readonly analytics: AnalyticsService,
  ) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<any> {
    const tag = this.reflector.getAllAndOverride<AuditTag | undefined>(AUDIT_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!tag) return next.handle();

    const req = ctx.switchToHttp().getRequest();
    const userId: string | undefined = req.user?.sub;
    const role = (req as any).userRole as string | undefined;
    const ip = req.ip ?? req.headers['x-forwarded-for'];
    const ua = req.headers['user-agent'];
    const method = req.method;
    const path = req.originalUrl ?? req.url;

    return next.handle().pipe(
      tap({
        next: () => {
          const level = tag.level ?? 'info';
          this.logger.log(
            `[${level}] ${tag.event} user=${userId ?? 'anon'} role=${role ?? 'unknown'} ${method} ${path}`,
          );
          this.analytics.track({
            event: `audit:${tag.event}`,
            userId: userId ?? null,
            properties: {
              level,
              method,
              path,
              role,
              ip,
              userAgent: typeof ua === 'string' ? ua.slice(0, 200) : undefined,
            },
          });
        },
        // Errors are intentionally NOT audited here (see comment above).
      }),
    );
  }
}
