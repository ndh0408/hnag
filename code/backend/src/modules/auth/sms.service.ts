import { Injectable, Logger } from '@nestjs/common';

export interface SmsProvider {
  name(): string;
  send(phone: string, body: string): Promise<void>;
}

class TwilioProvider implements SmsProvider {
  constructor(private readonly sid: string, private readonly token: string, private readonly from: string) {}
  name() { return 'twilio'; }
  async send(phone: string, body: string) {
    const url = `https://api.twilio.com/2010-04-01/Accounts/${this.sid}/Messages.json`;
    const auth = Buffer.from(`${this.sid}:${this.token}`).toString('base64');
    const params = new URLSearchParams({ To: phone, From: this.from, Body: body });
    const r = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });
    if (!r.ok) {
      const text = await r.text().catch(() => '');
      throw new Error(`Twilio SMS failed: ${r.status} ${text}`);
    }
  }
}

class EsmsProvider implements SmsProvider {
  constructor(private readonly apiKey: string, private readonly secretKey: string, private readonly brandname: string) {}
  name() { return 'esms'; }
  async send(phone: string, body: string) {
    const url = 'https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/';
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ApiKey: this.apiKey,
        SecretKey: this.secretKey,
        Brandname: this.brandname,
        SmsType: '2',
        Phone: phone.replace(/^\+84/, '0'),
        Content: body,
      }),
    });
    if (!r.ok) throw new Error(`eSMS failed: ${r.status}`);
    const data = await r.json().catch(() => ({}));
    if (data.CodeResult !== '100') throw new Error(`eSMS error: ${data.CodeResult} ${data.ErrorMessage ?? ''}`);
  }
}

class LogOnlyProvider implements SmsProvider {
  private readonly logger = new Logger('SmsLogOnly');
  name() { return 'log-only'; }
  async send(phone: string, body: string) {
    this.logger.warn(`SMS [DEV/UNCONFIGURED] to ${phone}: ${body}`);
  }
}

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  private readonly provider: SmsProvider;

  constructor() {
    this.provider = this.pickProvider();
    this.logger.log(`SMS provider: ${this.provider.name()}`);
  }

  private pickProvider(): SmsProvider {
    const twSid = process.env.TWILIO_ACCOUNT_SID;
    const twToken = process.env.TWILIO_AUTH_TOKEN;
    const twFrom = process.env.TWILIO_FROM_NUMBER;
    if (twSid && twToken && twFrom) return new TwilioProvider(twSid, twToken, twFrom);

    const esmsKey = process.env.ESMS_API_KEY;
    const esmsSecret = process.env.ESMS_SECRET_KEY;
    const esmsBrand = process.env.ESMS_BRANDNAME;
    if (esmsKey && esmsSecret && esmsBrand) return new EsmsProvider(esmsKey, esmsSecret, esmsBrand);

    return new LogOnlyProvider();
  }

  async send(phone: string, body: string): Promise<void> {
    try {
      await this.provider.send(phone, body);
    } catch (err) {
      this.logger.error(`SMS send to ${phone} failed via ${this.provider.name()}: ${(err as Error).message}`);
      throw err;
    }
  }

  providerName(): string { return this.provider.name(); }
}
