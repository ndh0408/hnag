import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { AuthModule } from '../auth/auth.module';

import { AiController } from './ai.controller';
import { AiPublicController } from './ai-public.controller';
import { AiOrchestratorService } from './services/ai-orchestrator.service';
import { TasteMemoryService } from './services/taste-memory.service';
import { MoodEngineService } from './services/mood-engine.service';
import { CandidateGeneratorService } from './services/candidate-generator.service';
import { RankerService } from './services/ranker.service';
import { LlmReasonService } from './services/llm-reason.service';
import { ContextBuilderService } from './services/context-builder.service';
import { EmbeddingService } from './services/embedding.service';
import { FridgeService } from './services/fridge.service';
import { VoiceService } from './services/voice.service';
import { ModelRouter } from './services/model-router.service';
import { PromptRegistry } from './prompts/prompt-registry.service';

@Module({
  imports: [HttpModule, AuthModule],
  controllers: [AiController, AiPublicController],
  providers: [
    AiOrchestratorService,
    TasteMemoryService,
    MoodEngineService,
    CandidateGeneratorService,
    RankerService,
    LlmReasonService,
    ContextBuilderService,
    EmbeddingService,
    FridgeService,
    VoiceService,
    PromptRegistry,
    ModelRouter,
  ],
  exports: [AiOrchestratorService, TasteMemoryService, EmbeddingService, PromptRegistry, ModelRouter],
})
export class AiModule {}
