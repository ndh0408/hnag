import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PostsService } from './posts.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Social')
@Controller()
export class PostsController {
  constructor(private readonly svc: PostsService) {}

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Get('feed')
  feed(
    @CurrentUser() u: JwtPayload,
    @Query('tab') tab?: 'for_you' | 'following' | 'nearby' | 'trending',
    @Query('page') page?: string,
  ) {
    return this.svc.feed(u.sub, tab ?? 'for_you', page ? parseInt(page) : 1);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('posts')
  create(@CurrentUser() u: JwtPayload, @Body() body: any) {
    return this.svc.create(u.sub, body);
  }

  @Get('posts/:id')
  detail(@Param('id') id: string) {
    return this.svc.detail(id);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/like')
  like(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.svc.like(u.sub, id);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Delete('posts/:id/like')
  unlike(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.svc.unlike(u.sub, id);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/comment')
  comment(@CurrentUser() u: JwtPayload, @Param('id') id: string, @Body() body: { content: string; parentId?: string }) {
    return this.svc.comment(u.sub, id, body.content, body.parentId);
  }

  @Get('posts/:id/comments')
  comments(@Param('id') id: string, @Query('page') page?: string) {
    return this.svc.listComments(id, page ? parseInt(page) : 1);
  }

  // Stories
  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('stories')
  createStory(@CurrentUser() u: JwtPayload, @Body() body: any) {
    return this.svc.createStory(u.sub, body);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Get('stories/feed')
  storiesFeed(@CurrentUser() u: JwtPayload) {
    return this.svc.storiesFeed(u.sub);
  }
}
