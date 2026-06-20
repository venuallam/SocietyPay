import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class BillingRepository {
  final _db = FirebaseFirestore.instance;

  // ── Get current month ───────────────────────────────
  String _currentMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  // ── Check if bills already generated ──────────────
  Future<bool> billsAlreadyGenerated(
      String societyId, String month,
      ) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('month', isEqualTo: month)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Generate bills for all occupied flats ─────────
  Future<Map<String, dynamic>> generateBills({
    required String societyId,
    required String adminId,
    required double variableAmount,
    String? selectedMonth,         // pass null → use current month
  }) async {
    final month  = selectedMonth ?? _currentMonth();
    final now    = DateTime.now();
    // Derive year from the month string (e.g. "FEB-2025")
    final parts  = month.split('-');
    final year   = parts.length == 2
        ? int.tryParse(parts[1]) ?? now.year
        : now.year;

    // Check for duplicates
    final alreadyGenerated =
    await billsAlreadyGenerated(societyId, month);
    if (alreadyGenerated) {
      throw Exception(
          'Bills for $month are already generated.');
    }

    // Get all occupied flats
    final flatsSnap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('flats')
        .where('status', isEqualTo: 'occupied')
        .get();

    if (flatsSnap.docs.isEmpty) {
      throw Exception(
          'No occupied flats found. '
              'Approve member requests first.');
    }

    // Get all flat types
    final ftSnap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('flatTypes')
        .get();

    final flatTypes = <String, Map<String, dynamic>>{};
    for (final doc in ftSnap.docs) {
      flatTypes[doc.id] =
      doc.data() as Map<String, dynamic>;
    }

    // Get all users for names
    final userIds = flatsSnap.docs
        .map((d) => (d.data()
    as Map<String, dynamic>)
    ['billingResponsibleId'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final userNames = <String, String>{};
    for (final uid in userIds) {
      final userDoc = await _db
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        userNames[uid] =
            (userDoc.data()
            as Map<String, dynamic>)
            ['name'] as String? ?? '';
      }
    }

    // Create batch
    final batch   = _db.batch();
    int billCount = 0;

    for (final flatDoc in flatsSnap.docs) {
      final flat =
      flatDoc.data() as Map<String, dynamic>;
      final billingId =
      flat['billingResponsibleId'] as String?;

      // Skip if no billing responsible set
      if (billingId == null) continue;

      final flatTypeId =
          flat['flatTypeId'] as String? ?? '';

// Find flat type by ID
// If empty or not found → use first available
      Map<String, dynamic>? flatType =
      flatTypeId.isNotEmpty
          ? flatTypes[flatTypeId]
          : null;

// Fall back to first flat type
      if (flatType == null &&
          flatTypes.isNotEmpty) {
        flatType = flatTypes.values.first;
      }

// Skip if still no flat type found
      if (flatType == null) continue;

// Also get the typeName
      final flatTypeName =
          flatType['typeName'] as String? ?? '';

      final fixedAmount =
      (flatType['maintenanceAmount'] as num)
          .toDouble();
      final total = fixedAmount + variableAmount;
      final billRef = _db
          .collection('societies')
          .doc(societyId)
          .collection('bills')
          .doc();

      batch.set(billRef, BillModel(
        id:          billRef.id,
        flatId:      flatDoc.id,
        flatNumber:
        flat['flatNumber'] as String? ?? '',
        flatTypeId:  flatTypeId,
        flatTypeName: flatTypeName, // ← now correct
        month:       month,
        year:        year,
        fixedAmount: fixedAmount,
        variableAmount: variableAmount,
        totalAmount: total,
        status:      PaymentStatus.unpaid,
        billingResponsibleId: billingId,
        billingResponsibleName:
        userNames[billingId] ?? '',
        generatedAt: now,
      ).toMap());

      billCount++;
    }

    await batch.commit();

    // Notify all members their bill is ready
    if (billCount > 0) {
      notificationService.notifyAllMembers(
        societyId: societyId,
        title: '🧾 Maintenance Bill Generated',
        body:  'Your maintenance bill for '
               '$month is ready. '
               'Please pay before the due date.',
        type:  'billGenerated',
      ).catchError((_) {});
    }

    return {
      'month':    month,
      'count':    billCount,
      'variable': variableAmount,
    };
  }

  // ── Watch bills for month ──────────────────────────
  Stream<List<BillModel>> watchMonthBills(
      String societyId, String month,
      ) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('month', isEqualTo: month)
        .snapshots()
        .map((s) => s.docs
        .map((d) => BillModel.fromDoc(d))
        .toList()
      ..sort((a, b) =>
          a.flatNumber.compareTo(b.flatNumber)));
  }

  // ── Watch resident bills ───────────────────────────
  Stream<List<BillModel>> watchResidentBills(
      String societyId,
      String userId,
      ) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('billingResponsibleId',
        isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs
        .map((d) => BillModel.fromDoc(d))
        .toList()
      ..sort((a, b) =>
          b.generatedAt.compareTo(
              a.generatedAt)));
  }

  // ── Remind ALL residents with outstanding dues ──────
  // Across every month (not just one). Groups unpaid +
  // reported bills per resident and sends each a single
  // reminder with their total outstanding.
  Future<int> remindAllDefaulters({
    required String societyId,
    required String adminId,
  }) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('status',
        whereIn: ['unpaid', 'reported'])
        .get();

    // Group by billing-responsible resident
    final byUser = <String, _Outstanding>{};
    for (final d in snap.docs) {
      final data = d.data();
      final uid  =
          data['billingResponsibleId'] as String?;
      if (uid == null) continue;
      final amt = (data['totalAmount'] as num? ?? 0)
          .toDouble();
      final flat =
          data['flatNumber'] as String? ?? '';
      final agg = byUser.putIfAbsent(
          uid, () => _Outstanding(flat));
      agg.total += amt;
      agg.count += 1;
    }

    if (byUser.isEmpty) return 0;

    final batch = _db.batch();
    byUser.forEach((uid, o) {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc();
      batch.set(ref, {
        'title': '🔔 Maintenance Dues Pending',
        'body':
        'You have ₹${o.total.toStringAsFixed(0)} '
            'outstanding across ${o.count} bill(s) '
            'for ${o.flat}. Please clear your dues.',
        'type':      'duesReminder',
        'isRead':    false,
        'createdAt': Timestamp.now(),
      });
    });
    await batch.commit();

    return byUser.length;
  }

  // ── Resident reports a payment (awaiting admin) ─────
  Future<void> reportPayment({
    required String societyId,
    required String billId,
    required String userId,
    String? proof,
  }) async {
    final billRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .doc(billId);

    final snap = await billRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    await billRef.update({
      'status':       'reported',
      'paymentProof': proof ?? '',
      'reportedAt':   Timestamp.now(),
      'reportedBy':   userId,
    });

    // Notify admin a payment was reported
    final flatNumber =
        data?['flatNumber'] as String? ?? '';
    final amount =
        (data?['totalAmount'] as num?)
            ?.toStringAsFixed(0) ?? '';
    final month =
        data?['month'] as String? ?? '';

    notificationService.notifyAdmin(
      societyId: societyId,
      title: '💰 Payment Reported',
      body:  'Flat $flatNumber reported a '
             '₹$amount payment for $month. '
             'Please verify and confirm.',
      type:  'paymentReported',
    ).catchError((_) {});
  }

  // ── Admin rejects a reported payment ────────────────
  Future<void> rejectPaymentReport({
    required String societyId,
    required String billId,
  }) async {
    final billRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .doc(billId);
    final snap = await billRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    await billRef.update({
      'status':       'unpaid',
      'paymentProof': null,
      'reportedAt':   null,
      'reportedBy':   null,
    });

    final responsibleId =
        data?['billingResponsibleId'] as String?;
    final month = data?['month'] as String? ?? '';
    if (responsibleId != null) {
      notificationService.notifyUser(
        userId: responsibleId,
        title:  '⚠️ Payment Not Confirmed',
        body:   'Your reported payment for $month '
                'could not be verified. Please '
                'check with your admin.',
        type:   'paymentRejected',
      ).catchError((_) {});
    }
  }

  // ── Mark payment as paid (admin confirms) ───────────
  Future<void> markAsPaid({
    required String societyId,
    required String billId,
    required String adminId,
  }) async {
    final batch  = _db.batch();
    final billRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .doc(billId);

    // Read bill before updating to get billing responsible
    final billSnap = await billRef.get();
    final billData = billSnap.data() as Map<String, dynamic>?;

    batch.update(billRef, {
      'status':   'paid',
      'paidAt':   Timestamp.now(),
      'markedBy': adminId,
    });

    await batch.commit();

    // Notify the payer their payment is confirmed
    final responsibleId =
        billData?['billingResponsibleId'] as String?;
    final flatNumber =
        billData?['flatNumber'] as String? ?? '';
    final amount =
        (billData?['totalAmount'] as num?)
            ?.toStringAsFixed(0) ?? '';
    final month =
        billData?['month'] as String? ?? '';

    if (responsibleId != null) {
      notificationService.notifyUser(
        userId: responsibleId,
        title:  '✅ Payment Confirmed',
        body:   'Your maintenance payment of '
                '₹$amount for $flatNumber '
                '($month) has been marked as paid.',
        type:   'paymentConfirmed',
      ).catchError((_) {});
    }
  }

  // ── Undo payment ───────────────────────────────────
  Future<void> undoPayment({
    required String societyId,
    required String billId,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .doc(billId)
        .update({
      'status':   'unpaid',
      'paidAt':   null,
      'markedBy': null,
    });
  }

  // ── Get payment summary ────────────────────────────
  Future<Map<String, dynamic>> getPaymentSummary(
      String societyId, String month,
      ) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('month', isEqualTo: month)
        .get();

    final bills = snap.docs
        .map((d) => BillModel.fromDoc(d))
        .toList();

    final paid   = bills.where((b) => b.isPaid);
    final unpaid = bills.where((b) => b.isUnpaid);

    return {
      'total':         bills.length,
      'paid':          paid.length,
      'unpaid':        unpaid.length,
      'collected':     paid.fold(0.0,
              (s, b) => s + b.totalAmount),
      'pending':       unpaid.fold(0.0,
              (s, b) => s + b.totalAmount),
    };
  }
}
// Internal helper for grouping a resident's outstanding dues.
class _Outstanding {
  final String flat;
  double total = 0;
  int count = 0;
  _Outstanding(this.flat);
}
