import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class PollOption {
  final String id;
  final String foodName;
  final String? restaurantName;
  final String? imageUrl;
  final int priceVnd;
  final int distanceM;
  final List<({String id, String name, String? avatar})> voters;
  const PollOption({
    required this.id,
    required this.foodName,
    this.restaurantName,
    this.imageUrl,
    required this.priceVnd,
    required this.distanceM,
    this.voters = const [],
  });
}

/// Real-time group voting screen — see docs/01-PRODUCT.md §3.7 + docs/07-AI-ENGINES.md §4.
class GroupVotingScreen extends StatefulWidget {
  final String groupName;
  final int memberCount;
  final Stream<List<PollOption>> optionsStream;
  final Future<void> Function(String optionId) onVote;
  final VoidCallback? onSpinWheel;
  final VoidCallback? onAddOption;

  const GroupVotingScreen({
    super.key,
    required this.groupName,
    required this.memberCount,
    required this.optionsStream,
    required this.onVote,
    this.onSpinWheel,
    this.onAddOption,
  });

  @override
  State<GroupVotingScreen> createState() => _GroupVotingScreenState();
}

class _GroupVotingScreenState extends State<GroupVotingScreen> {
  String? _votedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: StreamBuilder<List<PollOption>>(
        stream: widget.optionsStream,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
          final opts = [...snap.data!]..sort((a, b) => b.voters.length.compareTo(a.voters.length));
          final voted = opts.fold(0, (s, o) => s + o.voters.length);
          return Column(
            children: [
              _statusBar(voted),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  itemCount: opts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x3),
                  itemBuilder: (_, i) => _optionCard(opts[i], rank: i),
                ),
              ),
              _bottomActions(),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBar(int votedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
      decoration: BoxDecoration(
        gradient: AppGradients.pho,
      ),
      child: Row(
        children: [
          Icon(Icons.group, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 8),
          Text('${widget.memberCount} thành viên · $votedCount đã vote',
              style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('Live', style: AppTypography.caption.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _optionCard(PollOption o, {required int rank}) {
    final isVoted = _votedId == o.id;
    final medal = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () async {
          await widget.onVote(o.id);
          setState(() => _votedId = o.id);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isVoted ? AppColors.phoOrange : Colors.grey.shade200,
              width: isVoted ? 2.5 : 1,
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Row(children: [
            if (o.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: CachedNetworkImage(imageUrl: o.imageUrl!, width: 80, height: 80, fit: BoxFit.cover),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (medal.isNotEmpty) ...[Text(medal, style: const TextStyle(fontSize: 16)), const SizedBox(width: 4)],
                  Expanded(child: Text(o.foodName, style: AppTypography.headingSm, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                if (o.restaurantName != null)
                  Text(o.restaurantName!, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text('${(o.priceVnd / 1000).round()}k · ${(o.distanceM / 1000).toStringAsFixed(1)}km',
                    style: AppTypography.caption.copyWith(color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                Row(children: [
                  ...o.voters.take(5).map((v) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.phoOrange.withOpacity(0.15),
                          backgroundImage: v.avatar != null ? NetworkImage(v.avatar!) : null,
                          child: v.avatar == null ? Text(v.name.characters.first, style: const TextStyle(fontSize: 10)) : null,
                        ),
                      )),
                  if (o.voters.length > 5) Text('+${o.voters.length - 5}', style: AppTypography.caption),
                  const SizedBox(width: 6),
                  Text('${o.voters.length} vote${o.voters.length == 1 ? "" : "s"}',
                      style: AppTypography.caption.copyWith(color: Colors.grey.shade700)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm món'),
            onPressed: widget.onAddOption,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.casino_rounded),
            label: const Text('Quay random'),
            onPressed: widget.onSpinWheel,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.phoOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
            ),
          ),
        ),
      ]),
    );
  }
}
