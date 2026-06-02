import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/corpus_repository.dart';

class MonthEndSurplusScreen extends StatefulWidget {
  final String societyId;
  const MonthEndSurplusScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<MonthEndSurplusScreen> createState() =>
      _MonthEndSurplusScreenState();
}

class _MonthEndSurplusScreenState
    extends State<MonthEndSurplusScreen> {
  final _repo = CorpusRepository();
  late String _selectedMonth;
  Map<String, dynamic>? _result;
  bool _calculating = false;
  bool _applying    = false;
  String? _error;

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

  Future<void> _calculate() async {
    setState(() {
      _calculating = true;
      _error       = null;
      _result      = null;
    });
    try {
      final result =
      await _repo.calculateMonthEndSurplus(
        societyId: widget.societyId,
        month:     _selectedMonth,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _calculating = false);
    }
  }

  Future<void> _apply() async {
    if (_result == null) return;
    setState(() => _applying = true);
    try {
      final adminId =
          FirebaseAuth.instance.currentUser!.uid;
      final surplus =
          _result!['surplus'] as double;
      final corpusExpensesTotal =
          _result!['corpusExpenses'] as double;
      final corpusExpenseDetails =
          (_result!['corpusExpenseDetails']
          as List<dynamic>)
              .cast<Map<String, dynamic>>();

      await _repo.applyMonthEndSurplus(
        societyId:            widget.societyId,
        month:                _selectedMonth,
        surplus:              surplus,
        corpusExpensesTotal:  corpusExpensesTotal,
        corpusExpenseDetails: corpusExpenseDetails,
        adminId:              adminId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(surplus >= 0
                ? '✅ Surplus of ₹${surplus.toStringAsFixed(0)} added to corpus'
                : '⚠️ Deficit of ₹${surplus.abs().toStringAsFixed(0)} applied'),
            backgroundColor: surplus >= 0
                ? AppColors.success
                : AppColors.warning));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Month-End Surplus'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // How it works card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.info_outline,
                          color: AppColors.accent,
                          size: 18),
                      SizedBox(width: 8),
                      Text('How It Works',
                          style: AppText.h4),
                    ]),
                    const SizedBox(height: 10),
                    _FormulaRow(
                        label: 'Total Collected',
                        prefix: '',
                        color: AppColors.success),
                    _FormulaRow(
                        label: 'Operational Expenses',
                        prefix: '−',
                        color: AppColors.danger),
                    const Divider(height: 16),
                    _FormulaRow(
                        label: 'Net Surplus / Deficit',
                        prefix: '=',
                        color: AppColors.primary,
                        isBold: true),
                    const Divider(height: 16),
                    _FormulaRow(
                        label: 'Corpus Expenses (this month)',
                        prefix: '−',
                        color: AppColors.warning),
                    const SizedBox(height: 10),
                    const Text(
                        'Surplus is credited to corpus. '
                            'Deficit and corpus expenses '
                            'are deducted — all in one '
                            'month-end closing.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Month selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('SELECT MONTH',
                        style: AppText.label),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      decoration:
                      const InputDecoration(
                          prefixIcon: Icon(
                              Icons.calendar_month)),
                      items: _months.map((m) =>
                          DropdownMenuItem(
                              value: m,
                              child: Text(m))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedMonth = v;
                            _result        = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _calculating
                            ? null : _calculate,
                        icon: _calculating
                            ? const SizedBox(
                            width: 16, height: 16,
                            child:
                            CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                Colors.white))
                            : const Icon(
                            Icons.calculate),
                        label: Text(_calculating
                            ? 'Calculating...'
                            : 'Calculate Surplus'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius:
                      BorderRadius.circular(10)),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13))),
            ],

            // Result
            if (_result != null) ...[
              const SizedBox(height: 16),

              // Already-closed notice
              if (_result!['alreadyClosed'] == true)
                Container(
                  margin: const EdgeInsets.only(
                      bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius:
                      BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.danger)),
                  child: const Row(children: [
                    Icon(Icons.lock_outline,
                        color: AppColors.danger,
                        size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                        'This month is already closed. '
                            'Cannot apply again.',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger))),
                  ]),
                ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Preview for ${_result!['month']}',
                          style: AppText.h4),
                      const SizedBox(height: 16),

                      // Collected
                      _ResultRow(
                          label: 'Total Collected',
                          value: '+ ₹${NumberFormat('#,##0').format(_result!['totalCollected'])}',
                          color: AppColors.success),
                      const SizedBox(height: 8),

                      // Operational expenses
                      _ResultRow(
                          label: 'Operational Expenses',
                          value: '− ₹${NumberFormat('#,##0').format(_result!['operationalExpenses'])}',
                          color: AppColors.danger),

                      const Divider(height: 20),

                      // Surplus/Deficit
                      _ResultRow(
                          label: _result!['isDeficit']
                              ? '⚠️ Net Deficit'
                              : '✅ Net Surplus',
                          value: '${_result!['isDeficit'] ? '−' : '+'} ₹${NumberFormat('#,##0').format((_result!['surplus'] as double).abs())}',
                          color: _result!['isDeficit']
                              ? AppColors.danger
                              : AppColors.success,
                          isBold: true,
                          fontSize: 18),

                      // Corpus expenses section
                      if ((_result!['corpusExpenses']
                      as double) > 0) ...[
                        const Divider(height: 20),
                        _ResultRow(
                            label: '🏦 Corpus Expenses',
                            value: '− ₹${NumberFormat('#,##0').format(_result!['corpusExpenses'])}',
                            color: AppColors.warning,
                            isBold: true,
                            fontSize: 15),
                        const SizedBox(height: 6),
                        // List each corpus expense
                        ...(_result!['corpusExpenseDetails']
                        as List<dynamic>)
                            .map((e) {
                          final exp =
                          e as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets
                                .only(
                                left: 12, top: 4),
                            child: Row(children: [
                              const Text('·  ',
                                  style: TextStyle(
                                      color: AppColors
                                          .textMuted)),
                              Expanded(child: Text(
                                  exp['description']
                                  as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors
                                          .textSecondary))),
                              Text(
                                  '₹${NumberFormat('#,##0').format(exp['amount'])}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                      FontWeight.w700,
                                      color: AppColors
                                          .warning)),
                            ]),
                          );
                        }),
                      ],

                      const SizedBox(height: 16),

                      // Deficit warning
                      if (_result!['isDeficit']) ...[
                        Container(
                          padding:
                          const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius:
                              BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors
                                      .warning)),
                          child: const Row(children: [
                            Icon(Icons.warning_amber,
                                color: AppColors.warning,
                                size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text(
                                'Expenses exceeded '
                                    'collections. This '
                                    'deficit will be '
                                    'deducted from corpus.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors
                                        .warning))),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Apply button (disabled if already closed)
                      if (_result!['alreadyClosed'] != true)
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() {
                                        _result = null;
                                      }),
                                  child: const Text(
                                      'Recalculate'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: ElevatedButton(
                                onPressed: _applying
                                    ? null : _apply,
                                style: ElevatedButton
                                    .styleFrom(
                                    backgroundColor:
                                    _result!['isDeficit']
                                        ? AppColors.warning
                                        : AppColors.success),
                                child: _applying
                                    ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                        Colors.white))
                                    : Text(
                                    _result!['isDeficit']
                                        ? 'Apply Deficit'
                                        : 'Apply to Corpus'),
                              )),
                        ])
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () =>
                                  setState(() {
                                    _result = null;
                                  }),
                              child: const Text(
                                  'Check Another Month')),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final String label, prefix;
  final Color color;
  final bool isBold;
  const _FormulaRow({
    required this.label,
    required this.prefix,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
        vertical: 3),
    child: Row(children: [
      SizedBox(width: 20,
          child: Text(prefix,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16))),
      Expanded(child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: isBold
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: color))),
    ]),
  );
}

class _ResultRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isBold;
  final double fontSize;
  const _ResultRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold   = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment:
    MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold
                  ? FontWeight.w800
                  : FontWeight.w400,
              color: AppColors.textPrimary)),
      Text(value,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color)),
    ],
  );
}