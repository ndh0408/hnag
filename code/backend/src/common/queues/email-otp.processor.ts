import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

import { EmailService } from '../../modules/auth/email.service';

export interface EmailOtpJob {
  email: string;
  code: string;
  purpose: 'login' | 'claim';
}

/**
 * Drains the `otp:email` queue. Each job contains a plaintext OTP code; we
 * never persist the job result, and BullMQ removeOnComplete drops the
 * payload within 10 minutes (see queues.module.ts).
 *
 * Audit hnag-audit-2026-05 §9: previously the SMTP call sat in the request
 * thread. With this worker the `/auth/email-otp/send` endpoint returns in
 * ≤10ms (just a Redis ENQUEUE) instead of 1-2s (full SMTP RTT).
 */
@Processor('otp:email', { concurrency: 5 })
export class EmailOtpProcessor extends WorkerHost {
  private readonly logger = new Logger(EmailOtpProcessor.name);

  constructor(private readonly email: EmailService) {
    super();
  }

  async process(job: Job<EmailOtpJob>): Promise<void> {
    const { email, code, purpose } = job.data;
    if (!this.email.configured()) {
      this.logger.debug(`OTP worker: email provider not configured, drop ${purpose} for ${email}`);
      return;
    }
    try {
      await this.email.sendOtp(email, code);
    } catch (err) {
      this.logger.warn(
        `OTP worker: send to ${email} attempt ${job.attemptsMade + 1} failed: ${(err as Error).message}`,
      );
      throw err; // let BullMQ retry per defaultJobOptions
    }
  }
}
