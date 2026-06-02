import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';

class ExpenseApprovalsScreen extends StatelessWidget {
  final String societyId;
  final String adminId;

  const ExpenseApprovalsScreen({
    super.key,
    required this.societyId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: ExpenseRepository()
            .watchPendingExpenses(societyId),
        builder: (context, snap) {

          if (snap.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary));
          }

          final expenses = snap.data ?? [];

          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: const [
                  Text('🎉',
                      style:
                      TextStyle(fontSize: 52)),
                  SizedBox(height: 16),
                  Text(
                      'All caught up!',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                          AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text(
                      'No pending expense approvals.',
                      style: TextStyle(
                          color:
                          AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
            itemBuilder: (ctx, i) =>
                _ApprovalCard(
                  expense:   expenses[i],
                  societyId: societyId,
                  adminId:   adminId,
                ),
          );
        },
      ),
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  final ExpenseModel expense;
  final String societyId;
  final String adminId;

  const _ApprovalCard({
    required this.expense,
    required this.societyId,
    required this.adminId,
  });

  @override
  State<_ApprovalCard> createState() =>
      _ApprovalCardState();
}

class _ApprovalCardState
    extends State<_ApprovalCard> {
  bool _loading = false;
  final _repo   = ExpenseRepository();

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await _repo.approveExpense(
        societyId:
        widget.societyId,
        expenseId:
        widget.expense.id,
        adminId:
        widget.adminId,
        amount:
        widget.expense.amount,
        isCorpusDeduction:
        widget.expense.isCorpusDeduction,
        description:
        widget.expense.description,
        category:
        widget.expense.category.name,
        month:
        widget.expense.month,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(
                '✅ Approved: '
                    '${widget.expense.description}'),
            backgroundColor:
            AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor:
            AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                widget.expense.description,
                style: const TextStyle(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              decoration:
              const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText:
                  'Why are you rejecting?'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  ctx,
                  ctrl.text.trim().isEmpty
                      ? 'No reason provided'
                      : ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Reject')),
        ],
      ),
    );

    if (reason == null) return;
    setState(() => _loading = true);
    try {
      await _repo.rejectExpense(
        societyId: widget.societyId,
        expenseId: widget.expense.id,
        reason:    reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('Expense rejected'),
            backgroundColor:
            AppColors.danger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor:
            AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.warning
                  .withOpacity(0.4))),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: Center(child: Text(
                  widget.expense.categoryIcon,
                  style: const TextStyle(
                      fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                    widget.expense.description,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                        AppColors.textPrimary),
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                    '${widget.expense.categoryLabel}  •  '
                        'By ${widget.expense.addedByName}',
                    style: const TextStyle(
                        fontSize: 11,
                        color:
                        AppColors.textSecondary)),
                Text(
                    DateFormat('d MMM yyyy')
                        .format(
                        widget.expense.createdAt),
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted)),
              ],
            )),
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                    '₹${NumberFormat('#,##0').format(widget.expense.amount)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                        AppColors.textPrimary)),
                if (widget.expense
                    .isCorpusDeduction)
                  Container(
                      margin: const EdgeInsets
                          .only(top: 4),
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2),
                      decoration: BoxDecoration(
                          color:
                          AppColors.dangerLight,
                          borderRadius:
                          BorderRadius.circular(
                              20)),
                      child: const Text(
                          '🏦 CORPUS',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              AppColors.danger))),
              ],
            ),
          ]),
        ),

        // Corpus warning
        if (widget.expense.isCorpusDeduction) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(
                14, 0, 14, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius:
                BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.warning_amber,
                  color: AppColors.warning,
                  size: 14),
              SizedBox(width: 6),
              Expanded(child: Text(
                  'Approving will deduct this '
                      'amount from corpus fund.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warning))),
            ]),
          ),
        ],

        const Divider(height: 1),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: _loading
              ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2))
              : Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                        foregroundColor:
                        AppColors.danger,
                        side: const BorderSide(
                            color: AppColors.danger),
                        padding:
                        const EdgeInsets.symmetric(
                            vertical: 10)),
                    child: const Text('Reject'))),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.success,
                        padding:
                        const EdgeInsets.symmetric(
                            vertical: 10)),
                    child: const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                            Icons.check_circle_rounded,
                            size: 16),
                        SizedBox(width: 6),
                        Text('Approve'),
                      ],
                    ))),
          ]),
        ),
      ]),
    );
  }
}