import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/corpus_model.dart';
import '../services/notification_service.dart';

class CorpusRepository {
  final _db = FirebaseFirestore.instance;

  String _currentMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  // ── Watch corpus balance ────────────────────────
  Stream<CorpusModel?> watchCorpus(
      String societyId) {
    return _db
        .collection('corpus')
        .doc(societyId)
        .snapshots()
        .map((doc) => doc.exists
        ? CorpusModel.fromDoc(doc) : null);
  }

  // ── Watch transaction history ──────────────────
  Stream<List<CorpusTransactionModel>>
  watchTransactions(String societyId) {
    return _db
        .collection('corpus')
        .doc(societyId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) =>
        CorpusTransactionModel.fromDoc(d))
        .toList());
  }

  // ── Set opening balance ────────────────────────
  Future<void> setOpeningBalance({
    required String societyId,
    required double amount,
    required String adminId,
  }) async {
    // Guard: allow only once — check for existing
    // openingBalance transaction
    final existing = await _db
        .collection('corpus')
        .doc(societyId)
        .collection('transactions')
        .where('subType', isEqualTo: 'openingBalance')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
          'Opening balance has already been set. '
          'Use "Add Manual Credit" to adjust the '
          'corpus balance instead.');
    }

    final batch     = _db.batch();
    final corpusRef = _db
        .collection('corpus').doc(societyId);
    final txnRef    = corpusRef
        .collection('transactions').doc();

    // Note: minimumReserve intentionally excluded —
    // never overwrite a reserve the admin may have set.
    batch.set(corpusRef, {
      'currentBalance':   amount,
      'openingBalance':   amount,
      'lastUpdated':      Timestamp.now(),
      'lastMonthSurplus': 0.0,
      'isInDeficit':      false,
      'isBelowReserve':   false,
    }, SetOptions(merge: true));

    batch.set(txnRef, {
      'type':        'credit',
      'subType':     'openingBalance',
      'amount':      amount,
      'balanceAfter':amount,
      'description': 'Opening balance set by admin',
      'month':       _currentMonth(),
      'createdBy':   adminId,
      'createdAt':   Timestamp.now(),
    });

    await batch.commit();
  }

  // ── Manual credit ──────────────────────────────
  Future<void> addManualCredit({
    required String societyId,
    required double amount,
    required String reason,
    required String adminId,
  }) async {
    final corpusDoc = await _db
        .collection('corpus')
        .doc(societyId)
        .get();

    final current = corpusDoc.exists
        ? (corpusDoc.data()!['currentBalance']
    as num).toDouble()
        : 0.0;
    final minReserve = corpusDoc.exists
        ? (corpusDoc.data()!['minimumReserve']
    as num? ?? 0).toDouble()
        : 0.0;
    final newBalance = current + amount;

    final batch     = _db.batch();
    final corpusRef = _db
        .collection('corpus').doc(societyId);
    final txnRef    = corpusRef
        .collection('transactions').doc();

    batch.update(corpusRef, {
      'currentBalance': newBalance,
      'isInDeficit':    newBalance < 0,
      'isBelowReserve': minReserve > 0 &&
          newBalance < minReserve,
      'lastUpdated':    Timestamp.now(),
    });

    batch.set(txnRef, {
      'type':        'credit',
      'subType':     'manualCredit',
      'amount':      amount,
      'balanceAfter':newBalance,
      'description': reason,
      'month':       _currentMonth(),
      'createdBy':   adminId,
      'createdAt':   Timestamp.now(),
    });

    await batch.commit();
  }

  // ── Set minimum reserve ────────────────────────
  Future<void> setMinimumReserve({
    required String societyId,
    required double amount,
  }) async {
    final corpusDoc = await _db
        .collection('corpus')
        .doc(societyId)
        .get();

    final current = corpusDoc.exists
        ? (corpusDoc.data()!['currentBalance']
    as num).toDouble()
        : 0.0;

    await _db
        .collection('corpus')
        .doc(societyId)
        .update({
      'minimumReserve': amount,
      'isBelowReserve': amount > 0 &&
          current < amount,
    });
  }

  // ── Check if month is already closed ──────────
  Future<bool> isMonthClosed({
    required String societyId,
    required String month,
  }) async {
    final snap = await _db
        .collection('corpus')
        .doc(societyId)
        .collection('transactions')
        .where('month', isEqualTo: month)
        .where('subType', whereIn: [
      'monthlySurplus',
      'deficitEntry',
    ])
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Check if previous month is closed ─────────
  Future<bool> isPreviousMonthClosed(
      String societyId) async {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    final prev = DateTime(now.year, now.month - 1);
    final prevMonth =
        '${months[prev.month - 1]}-${prev.year}';

    // Check if previous month had any bills at all
    final billsSnap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('month', isEqualTo: prevMonth)
        .limit(1)
        .get();

    // No bills last month — nothing to close
    if (billsSnap.docs.isEmpty) return true;

    return isMonthClosed(
      societyId: societyId,
      month:     prevMonth,
    );
  }

  // ── Calculate month end surplus ────────────────
  Future<Map<String, dynamic>>
  calculateMonthEndSurplus({
    required String societyId,
    required String month,
  }) async {
    // Run all three queries in parallel
    final results = await Future.wait([
      // Total paid bills this month
      _db.collection('societies')
          .doc(societyId)
          .collection('bills')
          .where('month', isEqualTo: month)
          .where('status', isEqualTo: 'paid')
          .get(),

      // Operational (non-corpus) approved expenses
      _db.collection('societies')
          .doc(societyId)
          .collection('expenses')
          .where('month', isEqualTo: month)
          .where('status', isEqualTo: 'approved')
          .where('isCorpusDeduction', isEqualTo: false)
          .get(),

      // Corpus-deduction approved expenses
      _db.collection('societies')
          .doc(societyId)
          .collection('expenses')
          .where('month', isEqualTo: month)
          .where('status', isEqualTo: 'approved')
          .where('isCorpusDeduction', isEqualTo: true)
          .get(),
    ]);

    final billsSnap       = results[0] as QuerySnapshot;
    final opExpSnap       = results[1] as QuerySnapshot;
    final corpusExpSnap   = results[2] as QuerySnapshot;

    final totalCollected = billsSnap.docs.fold(
        0.0, (s, d) =>
    s + ((d.data() as Map)['totalAmount'] as num)
        .toDouble());

    final totalOperationalExpenses =
    opExpSnap.docs.fold(0.0, (s, d) =>
    s + ((d.data() as Map)['amount'] as num)
        .toDouble());

    final totalCorpusExpenses =
    corpusExpSnap.docs.fold(0.0, (s, d) =>
    s + ((d.data() as Map)['amount'] as num)
        .toDouble());

    // Surplus = collections minus operational costs
    // (corpus deductions are handled separately)
    final surplus =
        totalCollected - totalOperationalExpenses;

    // Corpus expense IDs + details for audit trail
    final corpusExpenseDetails = corpusExpSnap.docs
        .map((d) => {
      'id':          d.id,
      'description': (d.data() as Map)
      ['description'] as String? ?? '',
      'category':    (d.data() as Map)
      ['category'] as String? ?? '',
      'amount':      ((d.data() as Map)['amount']
      as num).toDouble(),
    })
        .toList();

    return {
      'month':                month,
      'totalCollected':       totalCollected,
      'operationalExpenses':  totalOperationalExpenses,
      'corpusExpenses':       totalCorpusExpenses,
      'corpusExpenseDetails': corpusExpenseDetails,
      'surplus':              surplus,
      'isDeficit':            surplus < 0,
      'alreadyClosed': await isMonthClosed(
          societyId: societyId, month: month),
    };
  }

  // ── Apply month end surplus ────────────────────
  Future<void> applyMonthEndSurplus({
    required String societyId,
    required String month,
    required double surplus,
    required double corpusExpensesTotal,
    required List<Map<String, dynamic>> corpusExpenseDetails,
    required String adminId,
  }) async {
    // Guard: prevent double-closing same month
    final alreadyClosed = await isMonthClosed(
      societyId: societyId,
      month:     month,
    );
    if (alreadyClosed) {
      throw Exception(
          'Month $month is already closed. '
              'Cannot apply again.');
    }

    final corpusDoc = await _db
        .collection('corpus')
        .doc(societyId)
        .get();

    final current = corpusDoc.exists
        ? (corpusDoc.data()!['currentBalance']
    as num).toDouble()
        : 0.0;
    final minReserve = corpusDoc.exists
        ? (corpusDoc.data()!['minimumReserve']
    as num? ?? 0).toDouble()
        : 0.0;

    // Net change = operational surplus + corpus deductions
    final netChange    = surplus - corpusExpensesTotal;
    final newBalance   = current + netChange;
    final isCredit     = surplus >= 0;

    final batch     = _db.batch();
    final corpusRef = _db
        .collection('corpus').doc(societyId);

    // 1. Update corpus balance
    batch.update(corpusRef, {
      'currentBalance':   newBalance,
      'lastMonthSurplus': surplus,
      'isInDeficit':      newBalance < 0,
      'isBelowReserve':   minReserve > 0 &&
          newBalance < minReserve,
      'lastUpdated':      Timestamp.now(),
    });

    // 2. Surplus / deficit transaction
    double runningBalance = current + surplus;
    final surplusTxnRef  = corpusRef
        .collection('transactions').doc();
    batch.set(surplusTxnRef, {
      'type':        isCredit ? 'credit' : 'debit',
      'subType':     isCredit
          ? 'monthlySurplus' : 'deficitEntry',
      'amount':      surplus.abs(),
      'balanceAfter':runningBalance,
      'description': isCredit
          ? 'Monthly surplus — $month'
          : 'Monthly deficit — $month',
      'month':       month,
      'createdBy':   adminId,
      'createdAt':   Timestamp.now(),
    });

    // 3. One expenseDeduction transaction per
    //    corpus expense — full audit trail
    for (final exp in corpusExpenseDetails) {
      runningBalance -= (exp['amount'] as double);
      final txnRef = corpusRef
          .collection('transactions').doc();

      batch.set(txnRef, {
        'type':            'debit',
        'subType':         'expenseDeduction',
        'amount':          exp['amount'],
        'balanceAfter':    runningBalance,
        'description':     exp['description'],
        'category':        exp['category'],
        'linkedExpenseId': exp['id'],
        'month':           month,
        'createdBy':       adminId,
        'createdAt':       Timestamp.now(),
      });

      // Link txnId back to the expense document
      batch.update(
        _db.collection('societies')
            .doc(societyId)
            .collection('expenses')
            .doc(exp['id'] as String),
        {'linkedCorpusTxnId': txnRef.id},
      );
    }

    await batch.commit();

    // ── Post-closing notifications to admin ──────────

    // 1. Month-end closed successfully
    if (isCredit) {
      notificationService.notifyUser(
        userId: adminId,
        title:  '🏦 Month-End Closed — $month',
        body:   'Surplus of ₹${surplus.toStringAsFixed(0)} '
                'added to Corpus Fund. '
                'New balance: ₹${newBalance.toStringAsFixed(0)}.',
        type:   'monthEndSurplus',
      ).catchError((_) {});
    } else {
      // 2. Deficit warning
      notificationService.notifyUser(
        userId: adminId,
        title:  '⚠️ Corpus Deficit — $month',
        body:   'Expenses exceeded collections by '
                '₹${surplus.abs().toStringAsFixed(0)}. '
                'Deficit deducted from corpus.',
        type:   'corpusDeficit',
      ).catchError((_) {});
    }

    // 3. Below minimum reserve warning
    if (minReserve > 0 && newBalance < minReserve) {
      notificationService.notifyUser(
        userId: adminId,
        title:  '🔴 Corpus Below Reserve',
        body:   'Corpus balance (₹${newBalance.toStringAsFixed(0)}) '
                'is below the minimum reserve '
                '(₹${minReserve.toStringAsFixed(0)}). '
                'Please review society finances.',
        type:   'corpusBelowReserve',
      ).catchError((_) {});
    }
  }
}