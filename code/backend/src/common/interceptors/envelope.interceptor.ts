import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/**
 * Wraps every HTTP response in the HNAG envelope: { success, data, error, meta }.
 * GraphQL responses bypass this (different transport).
 */
@Injectable()
export class EnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType<'http' | 'graphql'>() !== 'http') {
      return next.handle();
    }
    return next.handle().pipe(
      map((data) => {
        // Allow handlers to opt-out by returning { __raw__: true, payload }
        if (data && typeof data === 'object' && (data as any).__raw__) {
          return (data as any).payload;
        }
        return {
          success: true,
          data: data ?? null,
          error: null,
          meta: { ts: new Date().toISOString() },
        };
      }),
    );
  }
}
