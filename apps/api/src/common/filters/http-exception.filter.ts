import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const raw = exception instanceof HttpException ? exception.getResponse() : undefined;
    const message = typeof raw === 'string' ? raw : (raw && typeof raw === 'object' && 'message' in raw ? (raw as { message: unknown }).message : 'An unexpected error occurred.');
    if (status >= 500) this.logger.error(exception);
    response.status(status).json({ error: { code: status >= 500 ? 'INTERNAL_ERROR' : `HTTP_${status}`, message } });
  }
}
