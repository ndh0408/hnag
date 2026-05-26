// Group Voting v2 — live indicator + ranked options + voter avatars + chat.
// Mirrors design/m-ai.jsx#Screen_GroupVoting.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/tokens.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class GroupOption {
  final String id;
  final String name;
  final String? imageUrl;
  final String foodSlug;
  final int priceVnd;
  final String? location;
  final String? proposerName;
  final List<String> voterAvatars;
  const GroupOption({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.foodSlug,
    required this.priceVnd,
    this.location,
    this.proposerName,
    required this.voterAvatars,
  });
}

class ChatTurn {
  final String name;
  final String text;
  final bool isMe;
  const ChatTurn({required this.name, required this.text, this.isMe = false});
}

class GroupVotingScreenV2 extends StatefulWidget {
  final String groupName;
  final int memberCount;
  final List<GroupOption> options;
  final List<ChatTurn> chat;
  final String userId;
  final Set<String>? userVotes;
  final ValueChanged<String>? onToggleVote;
  final ValueChanged<String>? onSend;
  final VoidCallback? onClose;
  final VoidCallback? onAddOption;
  final VoidCallback? onReveal;

  const GroupVotingScreenV2({
    super.key,
    required this.groupName,
    required this.memberCount,
    required this.options,
    required this.chat,
    required this.userId,
    this.userVotes,
    this.onToggleVote,
    this.onSend,
    this.onClose,
    this.onAddOption,
    this.onReveal,
  });

  @override
  State<GroupVotingScreenV2> createState() => _GroupVotingScreenV2State();
}

class _GroupVotingScreenV2State extends State<GroupVotingScreenV2> {
  late Set<String> _voted;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _voted = Set.from(widget.userVotes ?? {});
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggleVote(String id) {
    setState(() {
      _voted.contains(id) ? _voted.remove(id) : _voted.add(id);
    });
    widget.onToggleVote?.call(id);
  }

  String _vnd(int v) => '${(v / 1000).round()}k';

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final sorted = [...widget.options]..sort((a, b) => b.voterAvatars.length.compareTo(a.voterAvatars.length));
        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: widget.groupName,
            subtitle: '${widget.memberCount} người · ${_voted.length}/${widget.options.length} bạn đã vote',
            leading: HnagIconButton(icon: 'chevL', onPressed: widget.onClose ?? () => Navigator.maybePop(context)),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(HnagRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: t.success, shape: BoxShape.circle))
                        .animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
                    const SizedBox(width: 6),
                    Text('LIVE',
                      style: HnagType.micro.copyWith(color: t.success, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Options
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: sorted.length + 1,
                  itemBuilder: (_, i) {
                    if (i == sorted.length) {
                      return HnagCard(
                        variant: CardVariant.dashed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        onTap: widget.onAddOption,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HnagIcon('plus', color: t.brand),
                              const SizedBox(width: 8),
                              Text('Đề xuất món / quán', style: HnagType.label.copyWith(color: t.brand, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                            ],
                          ),
                        ),
                      );
                    }
                    final option = sorted[i];
                    final rank = i;
                    final medal = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HnagCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => _toggleVote(option.id),
                        child: Row(
                          children: [
                            if (medal.isNotEmpty)
                              SizedBox(width: 28, child: Text(medal, style: const TextStyle(fontSize: 24))),
                            HnagPhoto(width: 60, height: 60, foodSlug: option.foodSlug, imageUrl: option.imageUrl, radius: HnagRadius.sm),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.name,
                                    style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(option.location ?? _vnd(option.priceVnd),
                                    style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                  ),
                                  const SizedBox(height: 6),
                                  HnagAvatarStack(names: option.voterAvatars, size: 22, max: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _VoteButton(
                              active: _voted.contains(option.id),
                              count: option.voterAvatars.length,
                              onTap: () => _toggleVote(option.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Chat
              Container(
                height: 180,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        children: [
                          for (final c in widget.chat) _chatBubble(c, t),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: HnagInput(
                              controller: _ctrl,
                              placeholder: 'Nhắn cho nhóm...',
                            ),
                          ),
                          const SizedBox(width: 8),
                          HnagIconButton(
                            icon: 'arrowR',
                            variant: IconBtnVariant.primary,
                            onPressed: () {
                              if (_ctrl.text.trim().isEmpty) return;
                              widget.onSend?.call(_ctrl.text.trim());
                              _ctrl.clear();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Reveal CTA
              if (sorted.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: HnagButton(
                    label: 'Đã đủ vote — Reveal kết quả 🎉',
                    variant: BtnVariant.gradient,
                    size: BtnSize.lg,
                    fullWidth: true,
                    onPressed: widget.onReveal,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _chatBubble(ChatTurn c, SemanticTokens t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: c.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.isMe ? t.brand : t.bgMuted,
            borderRadius: BorderRadius.circular(HnagRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!c.isMe) Text(c.name,
                style: HnagType.micro.copyWith(color: t.brand, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
              ),
              Text(c.text,
                style: HnagType.body.copyWith(color: c.isMe ? Colors.white : t.text, fontFamily: HnagFonts.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;
  const _VoteButton({required this.active, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HnagMotion.fast,
        width: 60, height: 50,
        decoration: BoxDecoration(
          color: active ? t.brand : t.bgMuted,
          borderRadius: BorderRadius.circular(HnagRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HnagIcon('heart', color: active ? Colors.white : t.textMuted, size: 18),
            const SizedBox(height: 2),
            Text('$count',
              style: HnagType.labelSm.copyWith(
                color: active ? Colors.white : t.text,
                fontWeight: FontWeight.w700, fontFamily: HnagFonts.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
