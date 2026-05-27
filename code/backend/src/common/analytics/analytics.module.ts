import { Global, Module } from '@nestjs/common';

import { AnalyticsService } from './analytics.service';

/**
 * Make `AnalyticsService` injectable from any controller/service without
 * each downstream module having to `imports: [AnalyticsModule]`.
 *
 * Audit prompt-pack §11 ("event-driven analytics"): product analytics is
 * a horizontal concern — every domain wants to `track()`. A regular
 * module would force a chain of imports through 16 module files. The
 * @Global decorator says "register once, available everywhere."
 */
@Global()
@Module({
  providers: [AnalyticsService],
  exports: [AnalyticsService],
})
export class AnalyticsModule {}
