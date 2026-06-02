import 'package:cloud_firestore/cloud_firestore.dart';

class CorpusModel {
  final String societyId;
  final double currentBalance;
  final double minimumReserve;
  final double openingBalance;
  final DateTime lastUpdated;
  final double lastMonthSurplus;
  final bool isInDeficit;
  final bool isBelowReserve;

  const CorpusModel({
    required this.societyId,
    required this.currentBalance,
    this.minimumReserve   = 0,
    required this.openingBalance,
    required this.lastUpdated,
    this.lastMonthSurplus = 0,
    this.isInDeficit      = false,
    this.isBelowReserve   = false,
  });

  factory CorpusModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CorpusModel(
      societyId:       doc.id,
      currentBalance:
      (d['currentBalance'] as num? ?? 0)
          .toDouble(),
      minimumReserve:
      (d['minimumReserve'] as num? ?? 0)
          .toDouble(),
      openingBalance:
      (d['openingBalance'] as num? ?? 0)
          .toDouble(),
      lastUpdated: d['lastUpdated'] != null
          ? (d['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      lastMonthSurplus:
      (d['lastMonthSurplus'] as num? ?? 0)
          .toDouble(),
      isInDeficit:
      d['isInDeficit'] as bool? ?? false,
      isBelowReserve:
      d['isBelowReserve'] as bool? ?? false,
    );
  }
}

class CorpusTransactionModel {
  final String id;
  final String type;         // credit / debit
  final String subType;      // opening_balance /
  // monthly_surplus /
  // manual_credit /
  // expense_deduction /
  // deficit_entry
  final double amount;
  final double balanceAfter;
  final String description;
  final String? category;
  final String? linkedExpenseId;
  final String month;
  final String createdBy;
  final DateTime createdAt;

  const CorpusTransactionModel({
    required this.id,
    required this.type,
    required this.subType,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.category,
    this.linkedExpenseId,
    required this.month,
    required this.createdBy,
    required this.createdAt,
  });

  factory CorpusTransactionModel.fromDoc(
      DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CorpusTransactionModel(
      id:          doc.id,
      type:        d['type'] as String? ?? 'credit',
      subType:     d['subType'] as String?
          ?? 'manual_credit',
      amount:
      (d['amount'] as num? ?? 0).toDouble(),
      balanceAfter:
      (d['balanceAfter'] as num? ?? 0).toDouble(),
      description:
      d['description'] as String? ?? '',
      category:    d['category'] as String?,
      linkedExpenseId:
      d['linkedExpenseId'] as String?,
      month:       d['month'] as String? ?? '',
      createdBy:   d['createdBy'] as String? ?? '',
      createdAt:   d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  bool get isCredit => type == 'credit';
  bool get isDebit  => type == 'debit';

  String get subTypeLabel => switch (subType) {
    'openingBalance'   => 'Opening Balance',
    'monthlySurplus'   => 'Monthly Surplus',
    'manualCredit'     => 'Manual Credit',
    'expenseDeduction' => 'Expense Deduction',
    'deficitEntry'     => 'Monthly Deficit',
    'expenseReversal'  => 'Expense Reversal',
    _                  => subType,
  };

  String get subTypeIcon => switch (subType) {
    'openingBalance'   => '🏁',
    'monthlySurplus'   => '📈',
    'manualCredit'     => '💰',
    'expenseDeduction' => '💸',
    'deficitEntry'     => '📉',
    'expenseReversal'  => '↩️',
    _                  => '📋',
  };
}