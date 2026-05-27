import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PostsService } from './posts.service';
import { CreateCommentDto, CreatePostDto, CreateStoryDto } from './dto/posts.dto';
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
  create(@CurrentUser() u: JwtPayload, @Body() dto: CreatePostDto) {
    return this.svc.create(u.sub, dto);
  }

  @Get('posts/:id')
  detail(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.svc.detail(id);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/like')
  like(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.svc.like(u.sub, id);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Delete('posts/:id/like')
  unlike(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.svc.unlike(u.sub, id);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/comment')
  comment(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.svc.comment(u.sub, id, dto.content, dto.parentId);
  }

  @Get('posts/:id/comments')
  comments(@Param('id', new ParseUUIDPipe()) id: string, @Query('page') page?: string) {
    return this.svc.listComments(id, page ? parseInt(page) : 1);
  }

  // Stories
  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post('stories')
  createStory(@CurrentUser() u: JwtPayload, @Body() dto: CreateStoryDto) {
    return this.svc.createStory(u.sub, dto);
  }

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Get('stories/feed')
  storiesFeed(@CurrentUser() u: JwtPayload) {
    return this.svc.storiesFeed(u.sub);
  }
}
