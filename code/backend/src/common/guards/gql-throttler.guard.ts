import { ExecutionContext, Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import { GqlExecutionContext } from '@nestjs/graphql';

/**
 * ThrottlerGuard that also works for GraphQL requests.
 *
 * The stock ThrottlerGuard reads req/res from the HTTP context only; for a
 * GraphQL request that context is undefined, so it crashed reading `req.ip`
 * (turning every /graphql call — including legit admin ones — into a 500).
 * Here we pull req/res from the GraphQL context when needed.
 */
@Injectable()
export class GqlThrottlerGuard extends ThrottlerGuard {
  getRequestResponse(context: ExecutionContext) {
    if (context.getType<string>() === 'graphql') {
      const gqlCtx = GqlExecutionContext.create(context).getContext();
      return { req: gqlCtx.req, res: gqlCtx.res ?? gqlCtx.req?.res };
    }
    return super.getRequestResponse(context);
  }
}
