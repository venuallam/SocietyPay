import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/member_repository.dart';

class MemberRequestsScreen extends StatelessWidget {
  final String societyId;
  final String adminId;

  const MemberRequestsScreen({
    super.key,
    required this.societyId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('societies')
            .doc(societyId)
            .collection('memberRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snap) {

          // Loading
          if (snap.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary));
          }

          // Error
          if (snap.hasError) {
            return Center(
                child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(
                        color: AppColors.danger)));
          }

          // Empty
          if (!snap.hasData ||
              snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  const Text('👥',
                      style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text(
                      'No Pending Requests',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text(
                      'All member requests have been\n'
                          'reviewed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          final requests = snap.data!.docs
              .map((d) => MemberRequestModel.fromDoc(d))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header count
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius:
                  BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning
                          .withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Text('⏳',
                      style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                      '${requests.length} request(s) '
                          'pending your approval',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),

              // Request cards
              ...requests.map((req) =>
                  _RequestCard(
                    request:  req,
                    societyId: societyId,
                    adminId:   adminId,
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────
class _RequestCard extends StatefulWidget {
  final MemberRequestModel request;
  final String societyId;
  final String adminId;

  const _RequestCard({
    required this.request,
    required this.societyId,
    required this.adminId,
  });

  @override
  State<_RequestCard> createState() =>
      _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await MemberRepository().approveRequest(
        societyId: widget.societyId,
        requestId: widget.request.id,
        userId:    widget.request.userId,
        flatId:    widget.request.flatId,
        role:      widget.request.role,
        userName:  widget.request.userName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${widget.request.userName} '
                    'approved for '
                    '${widget.request.flatNumber}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    // Show reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Reject Request',
              style: TextStyle(
                  fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                  'Rejecting request from '
                      '${widget.request.userName}',
                  style: const TextStyle(
                      color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText:
                  'e.g. Flat already occupied',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                ctx,
                ctrl.text.trim().isEmpty
                    ? 'No reason provided'
                    : ctrl.text.trim(),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    setState(() => _loading = true);
    try {
      await MemberRepository().rejectRequest(
        societyId: widget.societyId,
        requestId: widget.request.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ ${widget.request.userName} '
                    'request rejected'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleIcon = widget.request.role ==
        UserRole.owner ? '🏠' : '🔑';
    final roleColor = widget.request.role ==
        UserRole.owner
        ? AppColors.primary
        : AppColors.accent;
    final roleBg = widget.request.role ==
        UserRole.owner
        ? AppColors.accentLight
        : AppColors.accentLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [

        // ── Member Info ────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  widget.request.userName
                      .isNotEmpty
                      ? widget.request.userName[0]
                      .toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                    widget.request.userName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                    widget.request.userPhone,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                // Role badge
                Row(children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3),
                    decoration: BoxDecoration(
                        color: roleBg,
                        borderRadius:
                        BorderRadius.circular(20)),
                    child: Text(
                        '$roleIcon ${widget.request.role.name.toUpperCase()}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleColor)),
                  ),
                ]),
              ],
            )),
          ]),
        ),

        // ── Flat Info ──────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(
              16, 0, 16, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(
                Icons.door_front_door_outlined,
                color: AppColors.textSecondary,
                size: 18),
            const SizedBox(width: 8),
            Text(
                'Requesting: ',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary)),
            Text(
                widget.request.flatNumber,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text(
                _timeAgo(widget.request.requestedAt),
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted)),
          ]),
        ),

        // ── Divider ────────────────────────────────────
        const Divider(height: 1),

        // ── Action Buttons ─────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: _loading
              ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2)))
              : Row(children: [
            // Reject button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reject,
                icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.danger),
                label: const Text(
                    'Reject',
                    style: TextStyle(
                        color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.danger),
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 10)),
              ),
            ),
            const SizedBox(width: 10),

            // Approve button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _approve,
                icon: const Icon(
                    Icons.check,
                    size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.success,
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 10)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Time ago helper ──────────────────────────────────
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}