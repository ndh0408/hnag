import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

/**
 * Sends OTP emails via SMTP (free with Gmail App Password).
 * Configure via env:
 *   SMTP_HOST (default smtp.gmail.com), SMTP_PORT (default 465),
 *   SMTP_USER (your gmail address), SMTP_PASS (16-char app password),
 *   SMTP_FROM (optional display name/from).
 * If SMTP_USER/SMTP_PASS are absent → log-only (dev mode).
 */
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private readonly from: string;

  constructor() {
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;
    this.from = process.env.SMTP_FROM || (user ? `Hôm Nay Ăn Gì? <${user}>` : 'HNAG');
    if (user && pass) {
      this.transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'smtp.gmail.com',
        port: Number(process.env.SMTP_PORT || 465),
        secure: Number(process.env.SMTP_PORT || 465) === 465,
        auth: { user, pass },
      });
      this.logger.log(`Email provider: SMTP ${process.env.SMTP_HOST || 'smtp.gmail.com'} as ${user}`);
    } else {
      this.logger.warn('Email provider: log-only (set SMTP_USER + SMTP_PASS to send real emails)');
    }
  }

  configured(): boolean {
    return this.transporter !== null;
  }

  async sendOtp(email: string, code: string): Promise<void> {
    if (!this.transporter) {
      this.logger.warn(`Email OTP [DEV] to ${email}: ${code}`);
      return;
    }
    await this.transporter.sendMail({
      from: this.from,
      to: email,
      subject: `Mã đăng nhập HNAG: ${code}`,
      text: `Mã đăng nhập Hôm Nay Ăn Gì? của bạn là: ${code}\nHiệu lực 5 phút. Không chia sẻ mã này với ai.`,
      html: `
        <div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:420px;margin:0 auto;padding:24px">
          <div style="font-size:32px;text-align:center">🍜</div>
          <h2 style="text-align:center;color:#FF6B2B;margin:8px 0">Hôm Nay Ăn Gì?</h2>
          <p style="color:#555">Mã đăng nhập của bạn:</p>
          <div style="font-size:36px;font-weight:800;letter-spacing:10px;text-align:center;color:#0F0F12;background:#FAFAF7;border-radius:12px;padding:16px;margin:12px 0">${code}</div>
          <p style="color:#999;font-size:13px">Hiệu lực 5 phút. Không chia sẻ mã này với ai. Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
        </div>`,
    });
  }
}
