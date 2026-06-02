import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final _db = FirebaseFirestore.instance;

  // ── Get current month string ────────────────────────
  String _currentMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  // ── Watch all expenses (admin) ──────────────────────
  Stream<List<ExpenseModel>> watchAllExpenses(
      String societyId, {String? month}) {
    Query query = _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .orderBy('createdAt', descending: true);

    if (month != null) {
      query = query.where(
          'month', isEqualTo: month);
    }

    return query.snapshots().map((s) =>
        s.docs.map((d) =>
            ExpenseModel.fromDoc(d)).toList());
  }

  // ── Watch pending expenses (admin) ─────────────────
  Stream<List<ExpenseModel>> watchPendingExpenses(
      String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) => ExpenseModel.fromDoc(d))
        .toList());
  }

  // ── Watch member's own submitted expenses ──────────
  Stream<List<ExpenseModel>> watchMemberExpenses(
      String societyId, String userId, {String? month}) {
    Query query = _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .where('addedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (month != null) {
      query = query.where('month', isEqualTo: month);
    }

    return query.snapshots().map((s) =>
        s.docs.map((d) => ExpenseModel.fromDoc(d)).toList());
  }

  // ── Watch approved expenses (members) ─────────────
  Stream<List<ExpenseModel>> watchApprovedExpenses(
      String societyId, {String? month}) {
    Query query = _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true);

    if (month != null) {
      query = query.where(
          'month', isEqualTo: month);
    }

    return query.snapshots().map((s) =>
        s.docs.map((d) =>
            ExpenseModel.fromDoc(d)).toList());
  }

  // ── Add expense (admin — auto approved) ────────────
  Future<void> addExpense({
    required String societyId,
    required String adminId,
    required String adminName,
    required ExpenseCategory category,
    required String description,
    required double amount,
    required bool isCorpusDeduction,
  }) async {
    final now   = DateTime.now();
    final month = _currentMonth();
    final ref   = _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .doc();

    final expense = ExpenseModel(
      id:                ref.id,
      category:          category,
      description:       description,
      amount:            amount,
      month:             month,
      year:              now.year,
      isCorpusDeduction: isCorpusDeduction,
      status:            ExpenseStatus.approved,
      addedBy:           adminId,
      addedByName:       adminName,
      approvedBy:        adminId,
      createdAt:         now,
    );

    await ref.set(expense.toMap());

    // Corpus deduction is deferred to month-end closing.
    // No immediate corpus update here.
  }

  // ── Submit expense request (member) ────────────────
  Future<void> submitExpenseRequest({
    required String societyId,
    required String userId,
    required String userName,
    required ExpenseCategory category,
    required String description,
    required double amount,
    bool isCorpusDeduction = false,
  }) async {
    final now   = DateTime.now();
    final month = _currentMonth();
    final ref   = _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .doc();

    final expense = ExpenseModel(
      id:                ref.id,
      category:          category,
      description:       description,
      amount:            amount,
      month:             month,
      year:              now.year,
      isCorpusDeduction: isCorpusDeduction,
      status:            ExpenseStatus.pending,
      addedBy:           userId,
      addedByName:       userName,
      createdAt:         now,
    );

    await ref.set(expense.toMap());
  }

  // ── Approve expense (admin) ────────────────────────
  Future<void> approveExpense({
    required String societyId,
    required String expenseId,
    required String adminId,
    required double amount,
    required bool isCorpusDeduction,
    required String description,
    required String category,
    required String month,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .doc(expenseId)
        .update({
      'status':     'approved',
      'approvedBy': adminId,
    });

    // Corpus deduction is deferred to month-end closing.
    // No immediate corpus update here.
  }

  // ── Reject expense (admin) ─────────────────────────
  Future<void> rejectExpense({
    required String societyId,
    required String expenseId,
    required String reason,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .doc(expenseId)
        .update({
      'status':          'rejected',
      'rejectionReason': reason,
    });
  }

  // ── Get expense summary for month ─────────────────
  Future<Map<String, double>> getExpenseSummary(
      String societyId, String month,
      ) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .where('month', isEqualTo: month)
        .where('status', isEqualTo: 'approved')
        .get();

    double total   = 0;
    double corpus  = 0;
    double operational = 0;

    for (final doc in snap.docs) {
      final d = doc.data();
      final amount =
      (d['amount'] as num).toDouble();
      total += amount;
      if (d['isCorpusDeduction'] == true) {
        corpus += amount;
      } else {
        operational += amount;
      }
    }

    return {
      'total':       total,
      'corpus':      corpus,
      'operational': operational,
    };
  }

  // ── Deduct from corpus fund ────────────────────────
  Future<void> _deductFromCorpus({
    required String societyId,
    required String expenseId,
    required double amount,
    required String description,
    required String category,
    required String adminId,
    required String month,
  }) async {
    final batch      = _db.batch();
    final corpusRef  = _db
        .collection('corpus')
        .doc(societyId);
    final txnRef     = corpusRef
        .collection('transactions')
        .doc();

    // Get current balance
    final corpusDoc = await corpusRef.get();
    final current   = corpusDoc.exists
        ? (corpusDoc.data()!['currentBalance']
    as num).toDouble()
        : 0.0;
    final newBalance = current - amount;
    final minReserve = corpusDoc.exists
        ? (corpusDoc.data()!['minimumReserve']
    as num? ?? 0).toDouble()
        : 0.0;

    // Update corpus balance
    batch.update(corpusRef, {
      'currentBalance': newBalance,
      'isInDeficit':
      newBalance < 0,
      'isBelowReserve':
      minReserve > 0 &&
          newBalance < minReserve,
      'lastUpdated': Timestamp.now(),
    });

    // Create transaction record
    batch.set(txnRef, {
      'type':            'debit',
      'subType':         'expenseDeduction',
      'amount':          amount,
      'balanceAfter':    newBalance,
      'description':     description,
      'category':        category,
      'linkedExpenseId': expenseId,
      'month':           month,
      'createdBy':       adminId,
      'createdAt':       Timestamp.now(),
    });

    // Link transaction back to expense
    batch.update(
      _db.collection('societies')
          .doc(societyId)
          .collection('expenses')
          .doc(expenseId),
      {'linkedCorpusTxnId': txnRef.id},
    );

    await batch.commit();
  }
}