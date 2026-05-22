import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { randomBytes } from 'crypto';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): unknown {
    // Only HTTP requests get an HTTP JSON response written here. For GraphQL (and
    // WS) contexts there is no Express res/req, so we return the exception and let
    // that transport format it (otherwise we'd crash reading req.method).
    if (host.getType<string>() !== 'http') {
      if (exception instanceof HttpException) return exception;
      const e = exception as { code?: string };
      const mapped = mapPrismaError(exception);
      if (mapped) return new HttpException({ code: mapped.code, message: mapped.message }, mapped.status);
      // Log full detail server-side; surface a generic error to the client.
      this.logger.error(`[gql] ${e?.code ?? ''} ${exception instanceof Error ? exception.stack : JSON.stringify(exception)}`);
      return new HttpException('Internal error', HttpStatus.INTERNAL_SERVER_ERROR);
    }

    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const errorId = randomBytes(6).toString('hex');

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL';
    let message = 'Có chuyện gì đó không ổn — Hà sẽ kiểm tra';
    let details: Record<string, unknown> | undefined;

    if (exception instanceof HttpException) {
      // HttpExceptions carry intentional, user-safe messages.
      status = exception.getStatus();
      const r = exception.getResponse();
      if (typeof r === 'string') {
        message = r;
      } else if (typeof r === 'object' && r !== null) {
        const raw = r as Record<string, unknown>;
        code = (raw.code as string) ?? errorCodeFromStatus(status);
        message = (raw.message as string) ?? message;
        details = raw.details as Record<string, unknown>;
      }
      code = code ?? errorCodeFromStatus(status);
    } else {
      // Unexpected error: map known Prisma codes to safe messages, otherwise
      // return a generic message + correlation id. NEVER echo exception.message
      // to the client (it leaks SQL/Prisma/schema internals).
      const prisma = mapPrismaError(exception);
      if (prisma) {
        status = prisma.status;
        code = prisma.code;
        message = prisma.message;
      }
      this.logger.error(
        `[${errorId}] ${req.method} ${req.url} -> ${
          exception instanceof Error ? exception.stack : JSON.stringify(exception)
        }`,
      );
    }

    res.status(status).json({
      success: false,
      data: null,
      error: { code, message, details, errorId },
      meta: {
        ts: new Date().toISOString(),
        path: req.url,
        method: req.method,
      },
    });
  }
}

/** Translate common Prisma error codes into safe, user-facing responses. */
function mapPrismaError(
  exception: unknown,
): { status: number; code: string; message: string } | null {
  const e = exception as { code?: string };
  switch (e?.code) {
    case 'P2002':
      return { status: HttpStatus.CONFLICT, code: 'CONFLICT', message: 'Dữ liệu đã tồn tại' };
    case 'P2025':
      return { status: HttpStatus.NOT_FOUND, code: 'NOT_FOUND', message: 'Không tìm thấy' };
    case 'P2003':
      return { status: HttpStatus.BAD_REQUEST, code: 'BAD_REQUEST', message: 'Tham chiếu không hợp lệ' };
    default:
      return null;
  }
}

function errorCodeFromStatus(status: number): string {
  return (
    {
      [HttpStatus.BAD_REQUEST]: 'BAD_REQUEST',
      [HttpStatus.UNAUTHORIZED]: 'UNAUTHORIZED',
      [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
      [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
      [HttpStatus.CONFLICT]: 'CONFLICT',
      [HttpStatus.UNPROCESSABLE_ENTITY]: 'UNPROCESSABLE',
      [HttpStatus.TOO_MANY_REQUESTS]: 'RATE_LIMITED',
      [HttpStatus.PAYMENT_REQUIRED]: 'PAYMENT_REQUIRED',
    } as Record<number, string>
  )[status] ?? 'INTERNAL';
}
