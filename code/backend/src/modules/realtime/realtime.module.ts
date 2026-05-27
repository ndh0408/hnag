import { Module } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';
import { RoomEventStreamService } from './room-stream.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  providers: [RealtimeGateway, RoomEventStreamService],
  // RoomEventStreamService is consumed by services that need to publish
  // events with replay support (groups vote coalescer, etc.) without
  // taking a hard dep on RealtimeGateway.
  exports: [RealtimeGateway, RoomEventStreamService],
})
export class RealtimeModule {}
