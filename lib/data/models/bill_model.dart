import 'package:cloud_firestore/cloud_firestore.dart';

// unpaid → reported (resident claims paid, awaiting admin)
//        → paid (admin confirmed)
enum PaymentStatus { paid, unpaid, reported }

class BillModel {
  final String id;
  final String flatId;
  final String flatNumber;
  final String flatTypeId;
  final String flatTypeName;
  final String month;
  final int year;
  final double fixedAmount;
  final double variableAmount;
  final double totalAmount;
  final PaymentStatus status;
  final String billingResponsibleId;
  final String billingResponsibleName;
  final DateTime generatedAt;
  final DateTime? paidAt;
  final String? markedBy;
  // Payment-report fields (resident-submitted proof)
  final String? paymentProof;   // link / UTR / reference
  final DateTime? reportedAt;
  final String? reportedBy;

  const BillModel({
    required this.id,
    required this.flatId,
    required this.flatNumber,
    required this.flatTypeId,
    required this.flatTypeName,
    required this.month,
    required this.year,
    required this.fixedAmount,
    this.variableAmount = 0,
    required this.totalAmount,
    required this.status,
    required this.billingResponsibleId,
    required this.billingResponsibleName,
    required this.generatedAt,
    this.paidAt,
    this.markedBy,
    this.paymentProof,
    this.reportedAt,
    this.reportedBy,
  });

  factory BillModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BillModel(
      id:          doc.id,
      flatId:      d['flatId'] ?? '',
      flatNumber:  d['flatNumber'] ?? '',
      flatTypeId:  d['flatTypeId'] ?? '',
      flatTypeName: d['flatTypeName'] ?? '',
      month:       d['month'] ?? '',
      year:        d['year'] ?? DateTime.now().year,
      fixedAmount:
      (d['fixedAmount'] as num).toDouble(),
      variableAmount:
      (d['variableAmount'] as num? ?? 0)
          .toDouble(),
      totalAmount:
      (d['totalAmount'] as num).toDouble(),
      status: switch (d['status']) {
        'paid'     => PaymentStatus.paid,
        'reported' => PaymentStatus.reported,
        _          => PaymentStatus.unpaid,
      },
      billingResponsibleId:
      d['billingResponsibleId'] ?? '',
      billingResponsibleName:
      d['billingResponsibleName'] ?? '',
      generatedAt: d['generatedAt'] != null
          ? (d['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      paidAt: d['paidAt'] != null
          ? (d['paidAt'] as Timestamp).toDate()
          : null,
      markedBy: d['markedBy'],
      paymentProof: d['paymentProof'],
      reportedAt: d['reportedAt'] != null
          ? (d['reportedAt'] as Timestamp).toDate()
          : null,
      reportedBy: d['reportedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
    'flatId':                flatId,
    'flatNumber':            flatNumber,
    'flatTypeId':            flatTypeId,
    'flatTypeName':          flatTypeName,
    'month':                 month,
    'year':                  year,
    'fixedAmount':           fixedAmount,
    'variableAmount':        variableAmount,
    'totalAmount':           totalAmount,
    'status':                status.name,
    'billingResponsibleId':  billingResponsibleId,
    'billingResponsibleName':billingResponsibleName,
    'generatedAt':
    Timestamp.fromDate(generatedAt),
    'paidAt': paidAt != null
        ? Timestamp.fromDate(paidAt!) : null,
    'markedBy': markedBy,
    'paymentProof': paymentProof,
    'reportedAt': reportedAt != null
        ? Timestamp.fromDate(reportedAt!) : null,
    'reportedBy': reportedBy,
  };

  bool get isPaid     => status == PaymentStatus.paid;
  bool get isUnpaid   => status == PaymentStatus.unpaid;
  bool get isReported => status == PaymentStatus.reported;
}