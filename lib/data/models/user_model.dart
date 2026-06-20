import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, owner, tenant }
enum FlatStatus { vacant, occupied }
enum MemberRequestStatus { pending, approved, rejected }

class UserModel {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String? societyId;
  final String? flatId;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.societyId,
    this.flatId,
    required this.createdAt,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      id:        doc.id,
      name:      d['name'] ?? '',
      phone:     d['phone'] ?? '',
      role:      UserRole.values.firstWhere(
              (e) => e.name == (d['role'] ?? 'owner'),
          orElse: () => UserRole.owner),
      societyId: d['societyId'],
      flatId:    d['flatId'],
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'phone':     phone,
    'role':      role.name,
    'societyId': societyId,
    'flatId':    flatId,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  bool get isAdmin  => role == UserRole.admin;
  bool get isOwner  => role == UserRole.owner;
  bool get isTenant => role == UserRole.tenant;
  bool get hasSociety => societyId != null;
}

class FlatModel {
  final String id;
  final String flatNumber;
  final String flatTypeId;
  final FlatStatus status;
  final String? ownerId;
  final String? ownerName;
  final String? tenantId;
  final String? tenantName;
  final String? billingResponsibleId;

  const FlatModel({
    required this.id,
    required this.flatNumber,
    required this.flatTypeId,
    required this.status,
    this.ownerId,
    this.ownerName,
    this.tenantId,
    this.tenantName,
    this.billingResponsibleId,
  });

  factory FlatModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FlatModel(
      id:          doc.id,
      flatNumber:  d['flatNumber'] ?? '',
      flatTypeId:  d['flatTypeId'] ?? '',
      status:      d['status'] == 'occupied'
          ? FlatStatus.occupied : FlatStatus.vacant,
      ownerId:     d['ownerId'],
      ownerName:   d['ownerName'],
      tenantId:    d['tenantId'],
      tenantName:  d['tenantName'],
      billingResponsibleId: d['billingResponsibleId'],
    );
  }

  bool get isVacant   => status == FlatStatus.vacant;
  bool get isOccupied => status == FlatStatus.occupied;
  bool get hasOwner   => ownerId != null;
  bool get hasTenant  => tenantId != null;

  // Display name: owner if present, else tenant
  String? get residentName =>
      ownerName ?? tenantName;
}

class MemberRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String flatId;
  final String flatNumber;
  final UserRole role;
  final MemberRequestStatus status;
  final DateTime requestedAt;

  const MemberRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.flatId,
    required this.flatNumber,
    required this.role,
    required this.status,
    required this.requestedAt,
  });

  factory MemberRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MemberRequestModel(
      id:          doc.id,
      userId:      d['userId'] ?? '',
      userName:    d['userName'] ?? '',
      userPhone:   d['userPhone'] ?? '',
      flatId:      d['flatId'] ?? '',
      flatNumber:  d['flatNumber'] ?? '',
      role:        UserRole.values.firstWhere(
              (e) => e.name == (d['role'] ?? 'owner'),
          orElse: () => UserRole.owner),
      status:      MemberRequestStatus.values.firstWhere(
              (e) => e.name == (d['status'] ?? 'pending'),
          orElse: () => MemberRequestStatus.pending),
      requestedAt: d['requestedAt'] != null
          ? (d['requestedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':      userId,
    'userName':    userName,
    'userPhone':   userPhone,
    'flatId':      flatId,
    'flatNumber':  flatNumber,
    'role':        role.name,
    'status':      status.name,
    'requestedAt': Timestamp.fromDate(requestedAt),
  };
}