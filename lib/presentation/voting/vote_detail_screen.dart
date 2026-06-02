import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/vote_model.dart';
import '../../data/repositories/vote_repository.dart';

class VoteDetailScreen extends StatefulWidget {
  final VoteModel vote;
  final String userId;
  final bool isAdmin;
  final String societyId;

  const VoteDetailScreen({
    super.key,
    required this.vote,
    required this.userId,
    required this.isAdmin,
    required this.societyId,
  });

  @override
  State<VoteDetailScreen> createState() =>
      _VoteDetailScreenState();
}

class _VoteDetailScreenState
    extends State<VoteDetailScreen> {
  final _repo     = VoteRepository();
  String? _myVote;
  bool _loading   = false;
  bool _checked   = false;

  @override
  void initState() {
    super.initState();
    _checkMyVote();
  }

  Future<void> _checkMyVote() async {
    final v = await _repo.getUserVote(
      societyId: widget.societyId,
      voteId:    widget.vote.id,
      userId:    widget.userId,
    );
    setState(() {
      _myVote  = v;
      _checked = true;
    });
  }

  Future<void> _castVote(String choice) async {
    setState(() => _loading = true);
    try {
      await _repo.castVote(
        societyId: widget.societyId,
        voteId:    widget.vote.id,
        userId:    widget.userId,
        choice:    choice,
      );
      setState(() => _myVote = choice);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(choice == 'yes'
                ? '✅ You voted YES'
                : '❌ You voted NO'),
            backgroundColor: choice == 'yes'
                ? AppColors.success
                : AppColors.danger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cancelVote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Vote'),
        content: const Text(
            'Are you sure you want to '
                'cancel this vote?'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Yes, Cancel')),
        ],
      ),
    );

    if (confirm != true) return;

    await _repo.cancelVote(
      societyId: widget.societyId,
      voteId:    widget.vote.id,
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _closeVote() async {
    await _repo.expireVote(
      societyId: widget.societyId,
      voteId:    widget.vote.id,
      vote:      widget.vote,
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
          content: Text('Vote closed'),
          backgroundColor: AppColors.primary));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vote = widget.vote;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isAdmin && vote.isActive)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'close') _closeVote();
                if (v == 'cancel') _cancelVote();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'close',
                    child: Text('Close Vote Early')),
                const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel Vote',
                        style: TextStyle(
                            color: AppColors.danger))),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            // ── Vote header ────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                    ],
                  ),
                  borderRadius:
                  BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(vote.typeIcon,
                        style: const TextStyle(
                            fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(vote.typeLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white
                                    .withOpacity(0.6),
                                letterSpacing: 1)),
                        Text(vote.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.w800,
                                color: Colors.white)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Text(vote.description,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white
                              .withOpacity(0.8),
                          height: 1.5)),
                  const SizedBox(height: 16),
                  // Status + time
                  Row(children: [
                    _StatusBadge(vote: vote),
                    const Spacer(),
                    if (vote.isActive)
                      Text(
                          _timeLeft(vote.timeLeft),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white
                                  .withOpacity(0.7))),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Proposal details ───────────────────
            if (vote.proposalData != null) ...[
              Card(child: Padding(
                padding:
                const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('📋 Proposal',
                        style: AppText.h4),
                    const SizedBox(height: 10),
                    ...(vote.proposalData!
                        .entries.map((e) =>
                        Padding(
                          padding:
                          const EdgeInsets.only(
                              bottom: 8),
                          child: Row(children: [
                            Text(
                                '${_formatKey(e.key)}: ',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color:
                                    AppColors
                                        .textSecondary)),
                            Text(
                                '${e.value}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.w700,
                                    color:
                                    AppColors
                                        .textPrimary)),
                          ]),
                        ))),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],

            // ── Results ────────────────────────────
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      const Text(
                          '📊 Results',
                          style: AppText.h4),
                      Text(
                          '${vote.totalVotes}/'
                              '${vote.totalEligible} voted',
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                              AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Yes bar
                  _VoteBar(
                      label: 'Yes',
                      count: vote.yesCount,
                      total: vote.totalVotes,
                      color: AppColors.success,
                      bgColor:
                      AppColors.successLight),
                  const SizedBox(height: 8),

                  // No bar
                  _VoteBar(
                      label: 'No',
                      count: vote.noCount,
                      total: vote.totalVotes,
                      color: AppColors.danger,
                      bgColor: AppColors.dangerLight),

                  const SizedBox(height: 16),

                  // Pass threshold indicator
                  Row(children: [
                    Expanded(child: Column(
                      children: [
                        Text(
                            '${vote.yesPercentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight:
                                FontWeight.w800,
                                color:
                                AppColors.success)),
                        const Text('Yes votes',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                AppColors.textMuted)),
                      ],
                    )),
                    Container(
                        width: 1, height: 40,
                        color: AppColors.border),
                    Expanded(child: Column(
                      children: [
                        Text(
                            '${vote.passThreshold.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight:
                                FontWeight.w800,
                                color:
                                AppColors.primary)),
                        const Text(
                            'Required to pass',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                AppColors.textMuted)),
                      ],
                    )),
                    Container(
                        width: 1, height: 40,
                        color: AppColors.border),
                    Expanded(child: Column(
                      children: [
                        Text(
                            '${vote.participationRate.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight:
                                FontWeight.w800,
                                color:
                                AppColors.accent)),
                        const Text('Participation',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                AppColors.textMuted)),
                      ],
                    )),
                  ]),
                ],
              ),
            )),

            const SizedBox(height: 16),

            // ── My vote / Cast vote ────────────────
            if (!_checked)
              const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary))
            else if (_myVote != null)
              Container(
                padding:
                const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _myVote == 'yes'
                        ? AppColors.successLight
                        : AppColors.dangerLight,
                    borderRadius:
                    BorderRadius.circular(14),
                    border: Border.all(
                        color: _myVote == 'yes'
                            ? AppColors.success
                            : AppColors.danger)),
                child: Row(children: [
                  Text(
                      _myVote == 'yes'
                          ? '✅' : '❌',
                      style: const TextStyle(
                          fontSize: 24)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text('Your Vote',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                              AppColors.textMuted)),
                      Text(
                          _myVote == 'yes'
                              ? 'You voted YES'
                              : 'You voted NO',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              AppColors.textPrimary)),
                    ],
                  ),
                ]),
              )
            else if (vote.isActive) ...[
                const Text('Cast Your Vote',
                    style: AppText.h4),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _loading
                          ? const Center(
                          child:
                          CircularProgressIndicator(
                              color:
                              AppColors.primary))
                          : OutlinedButton(
                          onPressed: () =>
                              _castVote('no'),
                          style: OutlinedButton
                              .styleFrom(
                              foregroundColor:
                              AppColors.danger,
                              side: const BorderSide(
                                  color:
                                  AppColors.danger,
                                  width: 2),
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                  vertical: 14)),
                          child: const Column(
                            children: [
                              Text('❌',
                                  style: TextStyle(
                                      fontSize: 24)),
                              SizedBox(height: 4),
                              Text('Vote NO',
                                  style: TextStyle(
                                      fontWeight:
                                      FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _loading
                          ? const SizedBox()
                          : ElevatedButton(
                          onPressed: () =>
                              _castVote('yes'),
                          style: ElevatedButton
                              .styleFrom(
                              backgroundColor:
                              AppColors.success,
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                  vertical: 14)),
                          child: const Column(
                            children: [
                              Text('✅',
                                  style: TextStyle(
                                      fontSize: 24)),
                              SizedBox(height: 4),
                              Text('Vote YES',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                      FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ))),
                ]),
              ] else
                Container(
                  padding:
                  const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius:
                      BorderRadius.circular(14)),
                  child: const Center(
                      child: Text(
                          'Voting has ended',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight:
                              FontWeight.w600))),
                ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _timeLeft(Duration d) {
    if (d.isNegative) return 'Expired';
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h remaining';
    }
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m remaining';
  }

  String _formatKey(String key) =>
      key.replaceAllMapped(
          RegExp(r'([A-Z])'),
              (m) => ' ${m[0]}')
          .trim()
          .split(' ')
          .map((w) => w.isEmpty
          ? '' : w[0].toUpperCase() + w.substring(1))
          .join(' ');
}

// ── Vote Bar ──────────────────────────────────────────────────────────────────
class _VoteBar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color, bgColor;

  const _VoteBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0
        ? 0.0 : count / total;

    return Row(children: [
      SizedBox(width: 28,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color))),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: AppColors.bgLight,
            valueColor:
            AlwaysStoppedAnimation(color)),
      )),
      const SizedBox(width: 8),
      Text('$count',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color)),
    ]);
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final VoteModel vote;
  const _StatusBadge({required this.vote});

  @override
  Widget build(BuildContext context) {
    final label = switch (vote.status) {
      VoteStatus.active   => '🔵 ACTIVE',
      VoteStatus.passed   => '✅ PASSED',
      VoteStatus.rejected => '❌ REJECTED',
      VoteStatus.expired  => '⏰ EXPIRED',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}