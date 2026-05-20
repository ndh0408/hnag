import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL';
    let message = 'Có chuyện gì đó không ổn — Hà sẽ kiểm tra';
    let details: Record<string, unknown> | undefined;

    if (exception instanceof HttpException) {
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
    } else if (exception instanceof Error) {
      message = exception.message;
      this.logger.error(exception.stack);
    } else {
      this.logger.error(`Unknown error: ${JSON.stringify(exception)}`);
    }

    res.status(status).json({
      success: false,
      data: null,
      error: { code, message, details },
      meta: {
        ts: new Date().toISOString(),
        path: req.url,
        method: req.method,
      },
    });
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
