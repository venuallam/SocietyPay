import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/vote_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/vote_repository.dart';
import 'create_vote_screen.dart';
import 'vote_detail_screen.dart';

class VotingScreen extends StatefulWidget {
  final String societyId;
  final UserRole userRole;
  final String userName;

  const VotingScreen({
    super.key,
    required this.societyId,
    required this.userRole,
    required this.userName,
  });

  @override
  State<VotingScreen> createState() =>
      _VotingScreenState();
}

class _VotingScreenState
    extends State<VotingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _repo = VoteRepository();

  bool get _isAdmin =>
      widget.userRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voting'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor:
          Colors.white.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Active votes
          _VoteList(
            societyId: widget.societyId,
            userId: FirebaseAuth.instance
                .currentUser!.uid,
            isAdmin:  _isAdmin,
            userName: widget.userName,
            activeOnly: true,
          ),
          // Vote history
          _VoteList(
            societyId: widget.societyId,
            userId: FirebaseAuth.instance
                .currentUser!.uid,
            isAdmin:   _isAdmin,
            userName:  widget.userName,
            activeOnly: false,
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateVoteScreen(
                  societyId: widget.societyId,
                  adminId: FirebaseAuth.instance
                      .currentUser!.uid,
                  adminName: widget.userName,
                ))),
        backgroundColor: AppColors.primary,
        icon: const Icon(
            Icons.add, color: Colors.white),
        label: const Text(
            'Create Vote',
            style: TextStyle(
                color: Colors.white)),
      )
          : null,
    );
  }
}

// ── Vote List ─────────────────────────────────────────────────────────────────
class _VoteList extends StatelessWidget {
  final String societyId;
  final String userId;
  final bool isAdmin;
  final String userName;
  final bool activeOnly;

  const _VoteList({
    required this.societyId,
    required this.userId,
    required this.isAdmin,
    required this.userName,
    required this.activeOnly,
  });

  @override
  Widget build(BuildContext context) {
    final repo = VoteRepository();

    return StreamBuilder(
      stream: activeOnly
          ? repo.watchActiveVotes(societyId)
          : repo.watchVotes(societyId),
      builder: (BuildContext context,
          AsyncSnapshot<List<VoteModel>> snap) {

        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }

        var votes = snap.data ?? [];

        // For history tab filter out active
        if (!activeOnly) {
          votes = votes.where((v) =>
          v.status != VoteStatus.active)
              .toList();
        }

        if (votes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const Text('🗳️',
                    style: TextStyle(
                        fontSize: 52)),
                const SizedBox(height: 16),
                Text(
                    activeOnly
                        ? 'No active votes'
                        : 'No vote history',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                    activeOnly && isAdmin
                        ? 'Tap + to create a new vote'
                        : 'Completed votes will appear here',
                    style: const TextStyle(
                        color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: votes.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
          itemBuilder: (ctx, i) => _VoteCard(
            vote:      votes[i],
            userId:    userId,
            isAdmin:   isAdmin,
            societyId: societyId,
          ),
        );
      },
    );
  }
}

// ── Vote Card ─────────────────────────────────────────────────────────────────
class _VoteCard extends StatelessWidget {
  final VoteModel vote;
  final String userId;
  final bool isAdmin;
  final String societyId;

  const _VoteCard({
    required this.vote,
    required this.userId,
    required this.isAdmin,
    required this.societyId,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (vote.status) {
      VoteStatus.active   => AppColors.accent,
      VoteStatus.passed   => AppColors.success,
      VoteStatus.rejected => AppColors.danger,
      VoteStatus.expired  => AppColors.textMuted,
    };
    final statusBg = switch (vote.status) {
      VoteStatus.active   => AppColors.accentLight,
      VoteStatus.passed   => AppColors.successLight,
      VoteStatus.rejected => AppColors.dangerLight,
      VoteStatus.expired  => AppColors.bgLight,
    };
    final statusLabel = switch (vote.status) {
      VoteStatus.active   => 'ACTIVE',
      VoteStatus.passed   => 'PASSED ✅',
      VoteStatus.rejected => 'REJECTED ❌',
      VoteStatus.expired  => 'EXPIRED',
    };

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VoteDetailScreen(
                vote:      vote,
                userId:    userId,
                isAdmin:   isAdmin,
                societyId: societyId,
              ))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: vote.isActive
                    ? AppColors.accent.withOpacity(0.3)
                    : AppColors.border)),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius:
                      BorderRadius.circular(12)),
                  child: Center(child: Text(
                      vote.typeIcon,
                      style: const TextStyle(
                          fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(vote.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(vote.typeLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          color:
                          AppColors.textSecondary)),
                ],
              )),
              Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius:
                      BorderRadius.circular(20)),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor))),
            ]),

            const SizedBox(height: 12),

            // Progress bar
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: [
                    Text(
                        '${vote.yesCount} Yes  •  '
                            '${vote.noCount} No  •  '
                            '${vote.abstainCount} Abstain',
                        style: const TextStyle(
                            fontSize: 11,
                            color:
                            AppColors.textSecondary)),
                    Text(
                        '${vote.totalVotes}/'
                            '${vote.totalEligible} voted',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: vote.totalVotes == 0
                        ? 0
                        : vote.yesCount /
                        vote.totalVotes,
                    minHeight: 8,
                    backgroundColor:
                    AppColors.dangerLight,
                    valueColor:
                    const AlwaysStoppedAnimation(
                        AppColors.success),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: [
                    Text(
                        '${vote.yesPercentage.toStringAsFixed(0)}% Yes',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight:
                            FontWeight.w600)),
                    Text(
                        'Need ${vote.passThreshold.toStringAsFixed(0)}% to pass',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),

            // Time remaining / expiry
            if (vote.isActive) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                    _timeLeft(vote.timeLeft),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text(
                    'Tap to vote →',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accent)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _timeLeft(Duration d) {
    if (d.isNegative) return 'Expired';
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h left';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m left';
    }
    return '${d.inMinutes}m left';
  }
}