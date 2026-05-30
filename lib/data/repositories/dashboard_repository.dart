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

      // Pending expenses
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
    ]);

    final flatsSnap    = results[0] as QuerySnapshot;
    final billsSnap    = results[1] as QuerySnapshot;
    final corpusSnap   = results[2] as DocumentSnapshot;
    final expSnap      = results[3] as QuerySnapshot;
    final reqSnap      = results[4] as QuerySnapshot;

    // Calculate stats
    final totalFlats   = flatsSnap.docs.length;
    final vacantFlats  = flatsSnap.docs.where((d) =>
    (d.data() as Map)['status'] == 'vacant').length;

    final paidBills    = billsSnap.docs.where((d) =>
    (d.data() as Map)['status'] == 'paid').toList();
    final unpaidBills  = billsSnap.docs.where((d) =>
    (d.data() as Map)['status'] == 'unpaid').toList();

    final collected    = paidBills.fold(0.0, (s, d) =>
    s + ((d.data() as Map)['totalAmount'] as num).toDouble());
    final pending      = unpaidBills.fold(0.0, (s, d) =>
    s + ((d.data() as Map)['totalAmount'] as num).toDouble());

    final corpusBalance = corpusSnap.exists
        ? ((corpusSnap.data() as Map)['currentBalance'] as num).toDouble()
        : 0.0;

    return DashboardStats(
      totalFlats:      totalFlats,
      paidFlats:       paidBills.length,
      unpaidFlats:     unpaidBills.length,
      vacantFlats:     vacantFlats,
      totalCollected:  collected,
      totalPending:    pending,
      corpusBalance:   corpusBalance,
      pendingExpenses: expSnap.docs.length,
      pendingRequests: reqSnap.docs.length,
      month:           month,
    );
  }
}