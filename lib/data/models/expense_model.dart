import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  maintenance,
  electricity,
  water,
  gas,
  society,
  security,
  cleaning,
  lift,
  internet,
  repairs;

  String get icon => switch (this) {
    ExpenseCategory.electricity => '⚡',
    ExpenseCategory.water       => '💧',
    ExpenseCategory.gas         => '🔥',
    ExpenseCategory.society     => '🏢',
    ExpenseCategory.maintenance => '🔧',
    ExpenseCategory.security    => '💂',
    ExpenseCategory.cleaning    => '🧹',
    ExpenseCategory.lift        => '🛗',
    ExpenseCategory.internet    => '📶',
    ExpenseCategory.repairs     => '🛠️',
  };

  String get label => switch (this) {
    ExpenseCategory.electricity => 'Electricity',
    ExpenseCategory.water       => 'Water',
    ExpenseCategory.gas         => 'Gas',
    ExpenseCategory.society     => 'Society',
    ExpenseCategory.maintenance => 'Maintenance',
    ExpenseCategory.security    => 'Security',
    ExpenseCategory.cleaning    => 'Cleaning',
    ExpenseCategory.lift        => 'Lift',
    ExpenseCategory.internet    => 'Internet',
    ExpenseCategory.repairs     => 'Repairs',
  };
}

enum ExpenseStatus {
  pending,
  approved,
  rejected,
}

class ExpenseModel {
  final String id;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final String month;
  final int year;
  final bool isCorpusDeduction;
  final ExpenseStatus status;
  final String addedBy;
  final String addedByName;
  final String? approvedBy;
  final String? rejectionReason;
  final String? linkedCorpusTxnId;
  final String? receiptLink;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.month,
    required this.year,
    this.isCorpusDeduction = false,
    required this.status,
    required this.addedBy,
    required this.addedByName,
    this.approvedBy,
    this.rejectionReason,
    this.linkedCorpusTxnId,
    this.receiptLink,
    required this.createdAt,
  });

  factory ExpenseModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id:          doc.id,
      category:    ExpenseCategory.values.firstWhere(
              (e) => e.name == (d['category'] ?? 'society'),
          orElse:    () => ExpenseCategory.society),
      description: d['description'] ?? '',
      amount:      (d['amount'] as num).toDouble(),
      month:       d['month'] ?? '',
      year:        d['year'] ?? DateTime.now().year,
      isCorpusDeduction:
      d['isCorpusDeduction'] ?? false,
      status: ExpenseStatus.values.firstWhere(
              (e) => e.name == (d['status'] ?? 'pending'),
          orElse: () => ExpenseStatus.pending),
      addedBy:     d['addedBy'] ?? '',
      addedByName: d['addedByName'] ?? '',
      approvedBy:  d['approvedBy'],
      rejectionReason: d['rejectionReason'],
      linkedCorpusTxnId: d['linkedCorpusTxnId'],
      receiptLink: d['receiptLink'],
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'category':          category.name,
    'description':       description,
    'amount':            amount,
    'month':             month,
    'year':              year,
    'isCorpusDeduction': isCorpusDeduction,
    'status':            status.name,
    'addedBy':           addedBy,
    'addedByName':       addedByName,
    'approvedBy':        approvedBy,
    'rejectionReason':   rejectionReason,
    'linkedCorpusTxnId': linkedCorpusTxnId,
    'receiptLink':       receiptLink,
    'createdAt':         Timestamp.fromDate(createdAt),
  };

  bool get isPending  => status == ExpenseStatus.pending;
  bool get isApproved => status == ExpenseStatus.approved;
  bool get isRejected => status == ExpenseStatus.rejected;

  String get categoryIcon  => category.icon;
  String get categoryLabel => category.label;
}