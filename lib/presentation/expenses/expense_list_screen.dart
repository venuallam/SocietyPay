import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/expense_repository.dart';
import 'add_expense_screen.dart';
import 'expense_approvals_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final String societyId;
  final UserRole userRole;
  final String userName;
  final String? userId;    // required for member own-expense view

  const ExpenseListScreen({
    super.key,
    required this.societyId,
    required this.userRole,
    required this.userName,
    this.userId,
  });

  @override
  State<ExpenseListScreen> createState() =>
      _ExpenseListScreenState();
}

class _ExpenseListScreenState
    extends State<ExpenseListScreen> {
  final _repo = ExpenseRepository();
  late String _selectedMonth;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonth();
  }

  String _currentMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  List<String> get _months {
    const m = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${m[d.month - 1]}-${d.year}';
    });
  }

  bool get _isAdmin =>
      widget.userRole == UserRole.admin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Month picker
          Padding(
            padding: const EdgeInsets.only(
                right: 8),
            child: DropdownButton<String>(
              value: _selectedMonth,
              dropdownColor: AppColors.primaryDark,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              iconEnabledColor: Colors.white,
              underline: const SizedBox(),
              items: _months.map((m) =>
                  DropdownMenuItem(
                      value: m,
                      child: Text(m))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() =>
                  _selectedMonth = v);
                }
              },
            ),
          ),
        ],
      ),

      body: Column(children: [

        // ── Filter chips ─────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(
                label: 'All',
                selected: _selectedFilter == 'all',
                onTap: () => setState(() =>
                _selectedFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Approved',
                color: AppColors.success,
                selected:
                _selectedFilter == 'approved',
                onTap: () => setState(() =>
                _selectedFilter = 'approved'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pending',
                color: AppColors.warning,
                selected:
                _selectedFilter == 'pending',
                onTap: () => setState(() =>
                _selectedFilter = 'pending'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Corpus',
                color: AppColors.danger,
                selected:
                _selectedFilter == 'corpus',
                onTap: () => setState(() =>
                _selectedFilter = 'corpus'),
              ),
            ]),
          ),
        ),

        // ── Expense List ─────────────────────────────
        Expanded(
          child: StreamBuilder<List<ExpenseModel>>(
            stream: _isAdmin
                ? _repo.watchAllExpenses(
                    widget.societyId,
                    month: _selectedMonth)
                : widget.userId != null
                    ? _repo.watchMemberExpenses(
                        widget.societyId,
                        widget.userId!,
                        month: _selectedMonth)
                    : _repo.watchApprovedExpenses(
                        widget.societyId,
                        month: _selectedMonth),
            builder: (context, snap) {

              if (snap.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary));
              }

              if (snap.hasError) {
                return Center(
                    child: Text(
                        'Error: ${snap.error}'));
              }

              var expenses =
                  snap.data ?? [];

              // Apply filter
              if (_selectedFilter == 'approved') {
                expenses = expenses.where(
                        (e) => e.isApproved).toList();
              } else if (_selectedFilter ==
                  'pending') {
                expenses = expenses.where(
                        (e) => e.isPending).toList();
              } else if (_selectedFilter ==
                  'corpus') {
                expenses = expenses.where(
                        (e) => e.isCorpusDeduction)
                    .toList();
              }

              if (expenses.isEmpty) {
                return _EmptyState(
                    month: _selectedMonth,
                    filter: _selectedFilter);
              }

              // Calculate summary
              final totalAmount = expenses
                  .where((e) => e.isApproved)
                  .fold(0.0,
                      (s, e) => s + e.amount);
              final corpusAmount = expenses
                  .where((e) =>
              e.isApproved &&
                  e.isCorpusDeduction)
                  .fold(0.0,
                      (s, e) => s + e.amount);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // Summary row
                  Row(children: [
                    _SummaryPill(
                        label: 'Total',
                        amount: totalAmount,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    _SummaryPill(
                        label: 'Corpus',
                        amount: corpusAmount,
                        color: AppColors.danger),
                    const SizedBox(width: 8),
                    _SummaryPill(
                        label: 'Operational',
                        amount:
                        totalAmount - corpusAmount,
                        color: AppColors.success),
                  ]),
                  const SizedBox(height: 16),

                  // Expense tiles
                  ...expenses.map((e) =>
                      _ExpenseTile(
                        expense:  e,
                        isAdmin:  _isAdmin,
                        societyId: widget.societyId,
                        adminId:
                        FirebaseAuth.instance
                            .currentUser?.uid ?? '',
                      )),
                ],
              );
            },
          ),
        ),
      ]),

      // ── FABs ───────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Admin: show pending approvals button
          if (_isAdmin) ...[
            StreamBuilder<List<ExpenseModel>>(
              stream: _repo.watchPendingExpenses(
                  widget.societyId),
              builder: (ctx, snap) {
                final count =
                    snap.data?.length ?? 0;
                if (count == 0) {
                  return const SizedBox();
                }
                return FloatingActionButton.small(
                  heroTag: 'approvals',
                  onPressed: () =>
                      Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ExpenseApprovalsScreen(
                                    societyId:
                                    widget.societyId,
                                    adminId: FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.uid ?? '',
                                  ))),
                  backgroundColor:
                  AppColors.warning,
                  child: Badge(
                      label: Text('$count'),
                      child: const Icon(
                          Icons.pending_actions,
                          color: Colors.white)),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(
                      societyId:  widget.societyId,
                      userId: FirebaseAuth.instance
                          .currentUser?.uid ?? '',
                      userName:   widget.userName,
                      userRole:   widget.userRole,
                    ))),
            backgroundColor: AppColors.primary,
            icon: const Icon(
                Icons.add,
                color: Colors.white),
            label: Text(
                _isAdmin
                    ? 'Add Expense'
                    : 'Suggest Expense',
                style: const TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Expense Tile ──────────────────────────────────────────────────────────────
class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final bool isAdmin;
  final String societyId;
  final String adminId;

  const _ExpenseTile({
    required this.expense,
    required this.isAdmin,
    required this.societyId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (expense.status) {
      ExpenseStatus.approved => AppColors.success,
      ExpenseStatus.pending  => AppColors.warning,
      ExpenseStatus.rejected => AppColors.danger,
    };
    final statusBg = switch (expense.status) {
      ExpenseStatus.approved => AppColors.successLight,
      ExpenseStatus.pending  => AppColors.warningLight,
      ExpenseStatus.rejected => AppColors.dangerLight,
    };
    final statusLabel = switch (expense.status) {
      ExpenseStatus.approved => 'APPROVED',
      ExpenseStatus.pending  => 'PENDING',
      ExpenseStatus.rejected => 'REJECTED',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: expense.isPending
                  ? AppColors.warning.withOpacity(0.4)
                  : AppColors.border)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Category icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: Center(child: Text(
                  expense.categoryIcon,
                  style: const TextStyle(
                      fontSize: 22))),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                    expense.description,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text(
                      expense.categoryLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          color:
                          AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  if (expense.isCorpusDeduction)
                    Container(
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1),
                        decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius:
                            BorderRadius.circular(
                                20)),
                        child: const Text(
                            'CORPUS',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight:
                                FontWeight.w700,
                                color:
                                AppColors.danger))),
                ]),
                const SizedBox(height: 4),
                Text(
                    'By ${expense.addedByName}  •  '
                        '${DateFormat('d MMM').format(expense.createdAt)}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted)),
              ],
            )),

            // Amount + Status
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                    '₹${NumberFormat('#,##0').format(expense.amount)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3),
                    decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius:
                        BorderRadius.circular(20)),
                    child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor))),
              ],
            ),
          ]),
        ),

        // Rejection reason
        if (expense.isRejected &&
            expense.rejectionReason != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 14,
                  color: AppColors.danger),
              const SizedBox(width: 6),
              Expanded(child: Text(
                  'Reason: ${expense.rejectionReason}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.danger))),
            ]),
          ),
        ],

        // Quick approve/reject for admin
        if (isAdmin && expense.isPending) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () =>
                          _showRejectDialog(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor:
                          AppColors.danger,
                          side: const BorderSide(
                              color: AppColors.danger),
                          padding:
                          const EdgeInsets.symmetric(
                              vertical: 8)),
                      child: const Text(
                          'Reject',
                          style: TextStyle(
                              fontSize: 12)))),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                      onPressed: () =>
                          _approveExpense(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                          AppColors.success,
                          padding:
                          const EdgeInsets.symmetric(
                              vertical: 8)),
                      child: const Text(
                          'Approve',
                          style: TextStyle(
                              fontSize: 12)))),
            ]),
          ),
        ],
      ]),
    );
  }

  Future<void> _approveExpense(
      BuildContext context) async {
    try {
      await ExpenseRepository().approveExpense(
        societyId:         societyId,
        expenseId:         expense.id,
        adminId:           adminId,
        amount:            expense.amount,
        isCorpusDeduction: expense.isCorpusDeduction,
        description:       expense.description,
        category:          expense.category.name,
        month:             expense.month,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('✅ Expense approved'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _showRejectDialog(
      BuildContext context) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense'),
        content: TextFormField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Why are you rejecting?'),
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

    try {
      await ExpenseRepository().rejectExpense(
        societyId: societyId,
        expenseId: expense.id,
        reason:    reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('Expense rejected'),
            backgroundColor: AppColors.danger));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────
class _SummaryPill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryPill({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(
            '₹${NumberFormat('#,##0').format(amount)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(
            label,
            style: TextStyle(
                fontSize: 9,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: selected
                ? c : c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? c : c.withOpacity(0.3))),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white : c)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String month;
  final String filter;
  const _EmptyState({
    required this.month,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          const Text('📊',
              style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
              filter == 'all'
                  ? 'No expenses for $month'
                  : 'No $filter expenses',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
              'Tap the + button to add\nan expense.',
              style: TextStyle(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}