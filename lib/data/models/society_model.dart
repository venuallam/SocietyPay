import 'package:cloud_firestore/cloud_firestore.dart';

// ── Society Model ─────────────────────────────────────────────────────────────
class SocietyModel {
  final String id;
  final String name;
  final int totalFlats;
  final String inviteCode;
  final String adminId;
  final String? address;
  final DateTime createdAt;

  const SocietyModel({
    required this.id,
    required this.name,
    required this.totalFlats,
    required this.inviteCode,
    required this.adminId,
    this.address,
    required this.createdAt,
  });

  factory SocietyModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SocietyModel(
      id:          doc.id,
      name:        d['name'] ?? '',
      totalFlats:  d['totalFlats'] ?? 0,
      inviteCode:  d['inviteCode'] ?? '',
      adminId:     d['adminId'] ?? '',
      address:     d['address'],
      createdAt:   (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':       name,
    'totalFlats': totalFlats,
    'inviteCode': inviteCode,
    'adminId':    adminId,
    'address':    address,
    'createdAt':  Timestamp.fromDate(createdAt),
  };
}

// ── Flat Type Model ───────────────────────────────────────────────────────────
class FlatTypeModel {
  final String id;
  final String typeName;
  final double maintenanceAmount;

  const FlatTypeModel({
    required this.id,
    required this.typeName,
    required this.maintenanceAmount,
  });

  factory FlatTypeModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FlatTypeModel(
      id:                doc.id,
      typeName:          d['typeName'] ?? '',
      maintenanceAmount: (d['maintenanceAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'typeName':          typeName,
    'maintenanceAmount': maintenanceAmount,
    'effectiveFrom':     Timestamp.now(),
  };
}