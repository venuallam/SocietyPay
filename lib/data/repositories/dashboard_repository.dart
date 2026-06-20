import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dashboard_model.dart';

class DashboardRepository {
  final _db = FirebaseFirestore.instance;

  Future<DashboardStats> getDashboardStats({
    required String societyId,
    required String month,
  }) async {
    // Run all queries in parallel
    final results = await Future.wait([
      // Total flats
      _db.collection('societies')
          .doc(societyId)
          .collection('flats')
          .get(),

      // Bills for current month
      _db.collection('societies')
          .doc(societyId)
          .collection('bills')
          .where('month', isEqualTo: month)
          .get(),

      // Corpus balance
      _db.collection('corpus')
          .doc(societyId)
          .get(),

      // Pending expenses count
      _db.collection('societies')
          .doc(societyId)
          .collection('expenses')
          .where('status', isEqualTo: 'pending')
          .get(),

      // Pending member requests
      _db.collection('societies')
          .doc(societyId)
          .collection('memberRequests')
          .where('status', isEqualTo: 'pending')
          .get(),

      // Approved expenses for current month
      _db.collection('societies')
          .doc(societyId)
          .collection('expenses')
          .where('month', isEqualTo: month)
          .where('status', isEqualTo: 'approved')
          .get(),
    ]);

    final flatsSnap    = results[0] as QuerySnapshot;
    final billsSnap    = results[1] as QuerySnapshot;
    final corpusSnap   = results[2] as DocumentSnapshot;
    final expSnap      = results[3] as QuerySnapshot;
    final reqSnap      = results[4] as QuerySnapshot;
    final approvedExpSnap = results[5] as QuerySnapshot;

    // Calculate stats
    final totalFlats   = flatsSnap.docs.length;
    final vacantFlats  = flatsSnap.docs.where((d) =>
    (d.data() as Map)['status'] == 'vacant').length;

    final paidBills    = billsSnap.docs.where((d) =>
    (d.data() as Map)['status'] == 'paid').toList();
    // 'reported' = resident claims paid but not yet
    // confirmed → still counts as pending/unpaid.
    final unpaidBills  = billsSnap.docs.where((d) {
      final st = (d.data() as Map)['status'];
      return st == 'unpaid' || st == 'reported';
    }).toList();
    final reportedCount = billsSnap.docs.where((d) =>
    (d.data() as Map)['status'] == 'reported').length;

    final collected    = paidBills.fold(0.0, (s, d) =>
    s + ((d.data() as Map)['totalAmount'] as num).toDouble());
    final pending      = unpaidBills.fold(0.0, (s, d) =>
    s + ((d.data() as Map)['totalAmount'] as num).toDouble());

    final corpusBalance = corpusSnap.exists
        ? ((corpusSnap.data() as Map)['currentBalance'] as num).toDouble()
        : 0.0;

    final monthlyApprovedExpenses = approvedExpSnap.docs.fold(0.0,
        (s, d) => s + ((d.data() as Map)['amount'] as num).toDouble());

    return DashboardStats(
      totalFlats:               totalFlats,
      paidFlats:                paidBills.length,
      unpaidFlats:              unpaidBills.length,
      vacantFlats:              vacantFlats,
      totalCollected:           collected,
      totalPending:             pending,
      corpusBalance:            corpusBalance,
      pendingExpenses:          expSnap.docs.length,
      pendingRequests:          reqSnap.docs.length,
      reportedPayments:         reportedCount,
      month:                    month,
      monthlyApprovedExpenses:  monthlyApprovedExpenses,
    );
  }

  // ── Last 6 months collection trend ─────────────────
  Future<List<MonthlyCollection>> getCollectionTrend(
      String societyId) async {
    final months = _lastSixMonths();

    // Fetch paid bills for each month in parallel
    final snaps = await Future.wait(
      months.map((m) => _db
          .collection('societies')
          .doc(societyId)
          .collection('bills')
          .where('month', isEqualTo: m)
          .get()),
    );

    return List.generate(months.length, (i) {
      final snap      = snaps[i];
      final collected = snap.docs
          .where((d) =>
      (d.data() as Map)['status'] == 'paid')
          .fold(0.0, (s, d) =>
      s + ((d.data() as Map)['totalAmount']
      as num).toDouble());
      final billed    = snap.docs
          .fold(0.0, (s, d) =>
      s + ((d.data() as Map)['totalAmount']
      as num).toDouble());
      return MonthlyCollection(
        month:     months[i],
        collected: collected,
        billed:    billed,
      );
    });
  }

  // ── Generate last 6 month strings ──────────────────
  List<String> _lastSixMonths() {
    const abbr = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    final now    = DateTime.now();
    final months = <String>[];
    for (int i = 5; i >= 0; i--) {
      // Go back i months from now
      int m = now.month - i;
      int y = now.year;
      while (m <= 0) { m += 12; y--; }
      months.add('${abbr[m - 1]}-$y');
    }
    return months;
  }
}