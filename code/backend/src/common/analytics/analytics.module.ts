import { Global, Module } from '@nestjs/common';

import { AnalyticsService } from './analytics.service';
import { AnalyticsController } from './analytics.controller';

/**
 * Make `AnalyticsService` injectable from any controller/service without
 * each downstream module having to `imports: [AnalyticsModule]`. Also
 * mounts the public ingest controller `/v1/analytics/batch` used by the
 * Flutter front-end analytics SDK.
 *
 * Audit prompt-pack §11 ("event-driven analytics"): product analytics is
 * a horizontal concern — every domain wants to `track()`. A regular
 * module would force a chain of imports through 16 module files. The
 * @Global decorator says "register once, available everywhere."
 */
@Global()
@Module({
  controllers: [AnalyticsController],
  providers: [AnalyticsService],
  exports: [AnalyticsService],
})
export class AnalyticsModule {}
