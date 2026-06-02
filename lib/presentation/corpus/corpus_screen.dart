import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/corpus_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/corpus_repository.dart';
import 'add_corpus_credit_screen.dart';
import 'month_end_surplus_screen.dart';
import 'set_reserve_screen.dart';
import 'set_opening_balance_screen.dart';
import '../../data/repositories/corpus_repository.dart';

class CorpusScreen extends StatefulWidget {
  final String societyId;
  final UserRole userRole;

  const CorpusScreen({
    super.key,
    required this.societyId,
    required this.userRole,
  });

  @override
  State<CorpusScreen> createState() =>
      _CorpusScreenState();
}

class _CorpusScreenState
    extends State<CorpusScreen> {
  final _repo = CorpusRepository();
  String _filter = 'all';

  bool get _isAdmin =>
      widget.userRole == UserRole.admin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<CorpusModel?>(
        stream: _repo.watchCorpus(widget.societyId),
        builder: (context, corpusSnap) {
          final corpus = corpusSnap.data;

          return CustomScrollView(
            slivers: [

              // ── Header ────────────────────────────
              SliverAppBar(
                expandedHeight: _isAdmin ? 340 : 280,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                title: const Text('Corpus Fund'),
                actions: [
                  if (_isAdmin)
                    PopupMenuButton<String>(
                      icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white),
                      onSelected: (val) {
                        if (val == 'reserve') {
                          Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SetReserveScreen(
                                        societyId:
                                        widget.societyId,
                                        current: corpus
                                            ?.minimumReserve
                                            ?? 0,
                                      )));
                        } else if (val == 'opening') {
                          Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SetOpeningBalanceScreen(
                                        societyId:
                                        widget.societyId,
                                        current: corpus
                                            ?.openingBalance
                                            ?? 0,
                                      )));
                        }
                      },
                      itemBuilder: (_) => [
                        // Show "Set Opening Balance"
                        // only if corpus not yet
                        // initialised
                        if (corpus == null ||
                            corpus.openingBalance == 0)
                          const PopupMenuItem(
                            value: 'opening',
                            child: Row(children: [
                              Icon(Icons.account_balance_outlined,
                                  size: 18),
                              SizedBox(width: 8),
                              Text('Set Opening Balance'),
                            ]),
                          ),
                        const PopupMenuItem(
                          value: 'reserve',
                          child: Row(children: [
                            Icon(Icons.shield_outlined,
                                size: 18),
                            SizedBox(width: 8),
                            Text('Set Min Reserve'),
                          ]),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primary,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: SingleChildScrollView(
                      child: Padding(
                        padding:
                        const EdgeInsets.fromLTRB(
                            20, 60, 20, 20),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            // Balance label
                            Text(
                                corpus == null
                                    ? 'CORPUS BALANCE'
                                    : corpus.isInDeficit
                                    ? '🔴 DEFICIT'
                                    : corpus.isBelowReserve
                                    ? '⚠️ BELOW RESERVE'
                                    : '✅ CORPUS BALANCE',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    color: corpus == null
                                        ? Colors.white
                                        .withOpacity(0.6)
                                        : corpus.isInDeficit
                                        ? AppColors.danger
                                        : corpus
                                        .isBelowReserve
                                        ? AppColors
                                        .warning
                                        : Colors.white
                                        .withOpacity(
                                        0.65))),

                            const SizedBox(height: 8),

                            // Balance amount
                            Text(
                              corpus == null
                                  ? '₹0'
                                  : corpus.isInDeficit
                                  ? '- ₹${_fmt(corpus.currentBalance.abs())}'
                                  : '₹${_fmt(corpus.currentBalance)}',
                              style: TextStyle(
                                  fontSize: 42,
                                  fontWeight:
                                  FontWeight.w800,
                                  color: corpus == null
                                      ? Colors.white
                                      : corpus.isInDeficit
                                      ? AppColors.danger
                                      : Colors.white),
                            ),

                            // Min reserve info
                            if (corpus != null &&
                                corpus.minimumReserve
                                    > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                    horizontal: 10,
                                    vertical: 4),
                                decoration:
                                BoxDecoration(
                                    color: corpus
                                        .isBelowReserve
                                        ? AppColors
                                        .warning
                                        .withOpacity(
                                        0.2)
                                        : Colors.white
                                        .withOpacity(
                                        0.1),
                                    borderRadius:
                                    BorderRadius
                                        .circular(20),
                                    border: Border.all(
                                        color: corpus
                                            .isBelowReserve
                                            ? AppColors
                                            .warning
                                            : Colors
                                            .white
                                            .withOpacity(
                                            0.2))),
                                child: Text(
                                    'Min Reserve: ₹${_fmt(corpus.minimumReserve)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                        FontWeight.w600,
                                        color: corpus
                                            .isBelowReserve
                                            ? AppColors
                                            .warning
                                            : Colors.white
                                            .withOpacity(
                                            0.7))),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Stats row
                            if (corpus != null)
                              Row(children: [
                                _BalanceStat(
                                    label:
                                    'Opening',
                                    value: '₹${_fmt(corpus.openingBalance)}'),
                                const SizedBox(
                                    width: 10),
                                _BalanceStat(
                                  label:
                                  'Last Surplus',
                                  value: corpus
                                      .lastMonthSurplus
                                      >= 0
                                      ? '+₹${_fmt(corpus.lastMonthSurplus)}'
                                      : '-₹${_fmt(corpus.lastMonthSurplus.abs())}',
                                  valueColor:
                                  corpus
                                      .lastMonthSurplus
                                      >= 0
                                      ? AppColors
                                      .success
                                      : AppColors
                                      .danger,
                                ),
                              ]),

                            // Admin action buttons
                            if (_isAdmin) ...[
                              const SizedBox(
                                  height: 12),
                              Row(children: [
                                Expanded(
                                    child:
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                      AddCorpusCreditScreen(
                                                        societyId:
                                                        widget
                                                            .societyId,
                                                      ))),
                                      icon: const Icon(
                                          Icons
                                              .add_circle_outline,
                                          color:
                                          Colors.white,
                                          size: 16),
                                      label: const Text(
                                          'Add Credit',
                                          style: TextStyle(
                                              color:
                                              Colors.white,
                                              fontSize: 12)),
                                      style:
                                      OutlinedButton
                                          .styleFrom(
                                          side: BorderSide(
                                              color:
                                              Colors.white
                                                  .withOpacity(
                                                  0.5)),
                                          padding: const EdgeInsets
                                              .symmetric(
                                              vertical:
                                              8)),
                                    )),
                                const SizedBox(
                                    width: 10),
                                Expanded(
                                    child:
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                      MonthEndSurplusScreen(
                                                        societyId:
                                                        widget
                                                            .societyId,
                                                      ))),
                                      icon: const Icon(
                                          Icons
                                              .calculate_outlined,
                                          color:
                                          Colors.white,
                                          size: 16),
                                      label: const Text(
                                          'Month Surplus',
                                          style: TextStyle(
                                              color:
                                              Colors.white,
                                              fontSize: 12)),
                                      style:
                                      OutlinedButton
                                          .styleFrom(
                                          side: BorderSide(
                                              color:
                                              Colors.white
                                                  .withOpacity(
                                                  0.5)),
                                          padding: const EdgeInsets
                                              .symmetric(
                                              vertical:
                                              8)),
                                    )),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              ),

              // ── Filter + History ────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      const Text(
                          'Transaction History',
                          style: AppText.h4),
                      Row(children: [
                        _TxnFilterChip(
                            label: 'All',
                            selected: _filter == 'all',
                            onTap: () => setState(
                                    () => _filter = 'all')),
                        const SizedBox(width: 6),
                        _TxnFilterChip(
                            label: 'Credits',
                            color: AppColors.success,
                            selected:
                            _filter == 'credit',
                            onTap: () => setState(
                                    () =>
                                _filter = 'credit')),
                        const SizedBox(width: 6),
                        _TxnFilterChip(
                            label: 'Debits',
                            color: AppColors.danger,
                            selected:
                            _filter == 'debit',
                            onTap: () => setState(
                                    () =>
                                _filter = 'debit')),
                      ]),
                    ],
                  ),
                ),
              ),

          // ── Transaction List ────────────────────
          _TransactionListSliver(
          societyId: widget.societyId,
          filter:    _filter,
          ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  String _fmt(double v) =>
      NumberFormat('#,##0').format(v);
}

// ── Transaction Tile ──────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final CorpusTransactionModel txn;
  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final color    = isCredit
        ? AppColors.success : AppColors.danger;
    final bgColor  = isCredit
        ? AppColors.successLight
        : AppColors.dangerLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.border)),
      child: Row(children: [
        // Icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
              BorderRadius.circular(12)),
          child: Center(child: Text(
              txn.subTypeIcon,
              style: const TextStyle(
                  fontSize: 20))),
        ),
        const SizedBox(width: 12),

        // Details
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(txn.description,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius:
                      BorderRadius.circular(20)),
                  child: Text(txn.subTypeLabel,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color))),
              const SizedBox(width: 6),
              Text(
                  DateFormat('d MMM yyyy')
                      .format(txn.createdAt),
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted)),
            ]),
          ],
        )),

        // Amount + Balance
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            Text(
                '${isCredit ? '+' : '-'} ₹${NumberFormat('#,##0').format(txn.amount)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 3),
            Text(
                '₹${NumberFormat('#,##0').format(txn.balanceAfter.abs())}',
                style: TextStyle(
                    fontSize: 10,
                    color: txn.balanceAfter < 0
                        ? AppColors.danger
                        : AppColors.textMuted)),
          ],
        ),
      ]),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────
class _BalanceStat extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _BalanceStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? Colors.white)),
        ],
      ),
    ),
  );
}

class _TxnFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _TxnFilterChip({
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
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: selected
                ? c : c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? c : c.withOpacity(0.3))),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white : c)),
      ),
    );
  }
}

// ── Transaction List Sliver ───────────────────────────────────────────────────
class _TransactionListSliver extends StatelessWidget {
  final String societyId;
  final String filter;

  const _TransactionListSliver({
    required this.societyId,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final repo = CorpusRepository();

    return StreamBuilder<List<CorpusTransactionModel>>(
      stream: repo.watchTransactions(societyId),
      builder: (context, txnSnap) {
        // Loading
        if (txnSnap.connectionState ==
            ConnectionState.waiting) {
          return SliverToBoxAdapter(
              child: const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                          color: AppColors.primary))));
        }

        // Apply filter
        var txns = txnSnap.data ?? [];
        if (filter != 'all') {
          txns = txns
              .where((t) => t.type == filter)
              .toList();
        }

        // Empty state
        if (txns.isEmpty) {
          return SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(children: const [
                        Text('🏦',
                            style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text('No transactions yet',
                            style: TextStyle(
                                color: AppColors.textMuted)),
                      ]))));
        }

        // Group by month
        final grouped =
        <String, List<CorpusTransactionModel>>{};
        for (final txn in txns) {
          grouped
              .putIfAbsent(txn.month, () => [])
              .add(txn);
        }

        final months = grouped.keys.toList();

        // Build sliver list
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) {
              final month    = months[i];
              final monthTxns = grouped[month]!;
              return Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Month header
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                        16, 14, 16, 6),
                    child: Text(month,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1)),
                  ),
                  // Transaction tiles
                  ...monthTxns.map((t) =>
                      _TransactionTile(txn: t)),
                ],
              );
            },
            childCount: grouped.length,
          ),
        );
      },
    );
  }
}