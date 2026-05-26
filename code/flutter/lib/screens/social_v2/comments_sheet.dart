// CommentsSheet — modal bottom sheet that fetches + posts comments for a
// given post via /v1/posts/:id/comments. Used by TikTok feed and post detail.

import 'package:flutter/material.dart';

import '../../api/hnag_api.dart';
import '../../api/auth_service.dart';
import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final int initialCount;

  const CommentsSheet({super.key, required this.postId, this.initialCount = 0});

  static Future<int> show(BuildContext context, String postId, {int initialCount = 0}) async {
    final newCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId, initialCount: initialCount),
    );
    return newCount ?? initialCount;
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _api = HnagApi();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _api.commentsForPost(widget.postId);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
  }

  Future<void> _post() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty || _posting) return;
    if (AuthService.instance.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để bình luận')),
      );
      return;
    }
    setState(() => _posting = true);
    final created = await _api.commentOnPost(widget.postId, content);
    if (!mounted) return;
    if (created != null) {
      _ctrl.clear();
      setState(() {
        _comments = [created, ..._comments];
        _count += 1;
        _posting = false;
      });
    } else {
      // 400 usually means the underlying "post" doesn't exist (e.g. TikTok feed
      // is currently rendering food cards as a fallback when there are no real
      // posts yet). Show a friendly note rather than a retry prompt.
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('💬 Bài viết về món này chưa có — comment sẽ mở khi có user đăng đầu tiên')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: t.bgRaised,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('${_count} bình luận',
                        style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display),
                      ),
                      const Spacer(),
                      HnagIconButton(icon: 'x', variant: IconBtnVariant.soft, onPressed: () => Navigator.pop(context, _count)),
                    ],
                  ),
                ),
                Divider(color: t.divider, height: 24),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: t.brand))
                      : _comments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('💬', style: HnagType.d3),
                                  const SizedBox(height: 8),
                                  Text('Chưa có bình luận',
                                    style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Hãy là người đầu tiên!',
                                    style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (_, i) => _CommentTile(c: _comments[i]),
                            ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + inset),
                  child: Row(
                    children: [
                      Expanded(
                        child: HnagInput(
                          controller: _ctrl,
                          focusNode: _focus,
                          placeholder: 'Thêm bình luận…',
                          leading: 'chat',
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _post(),
                          maxLength: 500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      HnagIconButton(
                        icon: _posting ? 'clock' : 'arrowR',
                        variant: IconBtnVariant.primary,
                        onPressed: _posting ? null : _post,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CommentTile({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final user = (c['user'] as Map<String, dynamic>?) ?? const {};
    final author = (user['display_name'] as String?) ?? (user['username'] as String?) ?? 'Foodie';
    final avatar = user['avatar_url'] as String?;
    final content = (c['content'] as String?) ?? '';
    final createdAt = c['created_at'] as String?;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HnagAvatar(name: author, imageUrl: avatar, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(author,
                    style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                  ),
                  const SizedBox(width: 6),
                  if (createdAt != null)
                    Text(_relative(createdAt),
                      style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(content,
                style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _relative(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = DateTime.now().difference(dt);
      if (d.inMinutes < 1) return 'vừa xong';
      if (d.inHours < 1) return '${d.inMinutes}p';
      if (d.inDays < 1) return '${d.inHours}h';
      if (d.inDays < 7) return '${d.inDays}d';
      return '${d.inDays ~/ 7}w';
    } catch (_) {
      return '';
    }
  }
}
