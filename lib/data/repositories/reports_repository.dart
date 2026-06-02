import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';

class ReportsRepository {
  final _db = FirebaseFirestore.instance;

  // ── Get bills for month ─────────────────────────
  Future<List<BillModel>> getBillsForMonth({
    required String societyId,
    required String month,
  }) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('month', isEqualTo: month)
        .get();
    return snap.docs
        .map((d) => BillModel.fromDoc(d))
        .toList()
      ..sort((a, b) =>
          a.flatNumber.compareTo(b.flatNumber));
  }

  // ── Get expenses for month ──────────────────────
  Future<List<ExpenseModel>> getExpensesForMonth({
    required String societyId,
    required String month,
  }) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('expenses')
        .where('month', isEqualTo: month)
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs
        .map((d) => ExpenseModel.fromDoc(d))
        .toList();
  }

  // ── Get corpus balance ──────────────────────────
  Future<Map<String, dynamic>?> getCorpusData(
      String societyId) async {
    final doc = await _db
        .collection('corpus')
        .doc(societyId)
        .get();
    return doc.data();
  }

  // ── Get corpus transactions ─────────────────────
  Future<List<Map<String, dynamic>>>
  getCorpusTransactions({
    required String societyId,
    required String month,
  }) async {
    final snap = await _db
        .collection('corpus')
        .doc(societyId)
        .collection('transactions')
        .where('month', isEqualTo: month)
        .get();
    return snap.docs
        .map((d) => {
      ...d.data(),
      'id': d.id,
    })
        .toList();
  }

  // ── Build complete report data ──────────────────
  Future<Map<String, dynamic>> buildReportData({
    required String societyId,
    required String month,
    required String societyName,
  }) async {
    final results = await Future.wait([
      getBillsForMonth(
          societyId: societyId, month: month),
      getExpensesForMonth(
          societyId: societyId, month: month),
      getCorpusData(societyId),
    ]);

    final bills    = results[0] as List<BillModel>;
    final expenses =
    results[1] as List<ExpenseModel>;
    final corpus   =
    results[2] as Map<String, dynamic>?;

    final paidBills   =
    bills.where((b) => b.isPaid).toList();
    final unpaidBills =
    bills.where((b) => b.isUnpaid).toList();

    final totalBilled = bills.fold(0.0,
            (s, b) => s + b.totalAmount);
    final totalCollected = paidBills.fold(0.0,
            (s, b) => s + b.totalAmount);
    final totalPending = unpaidBills.fold(0.0,
            (s, b) => s + b.totalAmount);
    final totalExpenses = expenses.fold(0.0,
            (s, e) => s + e.amount);
    final corpusExpenses = expenses
        .where((e) => e.isCorpusDeduction)
        .fold(0.0, (s, e) => s + e.amount);
    final opExpenses =
        totalExpenses - corpusExpenses;
    final surplus = totalCollected - opExpenses;

    return {
      'societyName':     societyName,
      'month':           month,
      'bills':           bills,
      'expenses':        expenses,
      'corpus':          corpus,
      'totalBilled':     totalBilled,
      'totalCollected':  totalCollected,
      'totalPending':    totalPending,
      'totalExpenses':   totalExpenses,
      'corpusExpenses':  corpusExpenses,
      'opExpenses':      opExpenses,
      'surplus':         surplus,
      'paidCount':       paidBills.length,
      'unpaidCount':     unpaidBills.length,
      'totalFlats':      bills.length,
      'corpusBalance': (corpus?['currentBalance']
      as num? ?? 0).toDouble(),
    };
  }
}