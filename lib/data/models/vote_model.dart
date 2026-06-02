import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteType {
  adminTransfer,
  maintenanceChange,
  generalPoll,
}

enum VoteStatus {
  active,
  passed,
  rejected,
  expired,
}

class VoteModel {
  final String id;
  final VoteType type;
  final String title;
  final String description;
  final VoteStatus status;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int totalEligible;
  final int yesCount;
  final int noCount;
  final double passThreshold; // e.g. 60.0 = 60%
  final Map<String, dynamic>? proposalData;

  const VoteModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.expiresAt,
    required this.totalEligible,
    this.yesCount       = 0,
    this.noCount        = 0,
    this.passThreshold  = 60.0,
    this.proposalData,
  });

  factory VoteModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VoteModel(
      id:   doc.id,
      type: VoteType.values.firstWhere(
              (e) => e.name ==
              (d['type'] as String? ?? 'generalPoll'),
          orElse: () => VoteType.generalPoll),
      title:       d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      status: VoteStatus.values.firstWhere(
              (e) => e.name ==
              (d['status'] as String? ?? 'active'),
          orElse: () => VoteStatus.active),
      createdBy:
      d['createdBy'] as String? ?? '',
      createdByName:
      d['createdByName'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: d['expiresAt'] != null
          ? (d['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(
          const Duration(days: 7)),
      totalEligible:
      d['totalEligible'] as int? ?? 0,
      yesCount:
      d['yesCount'] as int? ?? 0,
      noCount:
      d['noCount'] as int? ?? 0,
      passThreshold:
      (d['passThreshold'] as num? ?? 60)
          .toDouble(),
      proposalData:
      d['proposalData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
    'type':           type.name,
    'title':          title,
    'description':    description,
    'status':         status.name,
    'createdBy':      createdBy,
    'createdByName':  createdByName,
    'createdAt':
    Timestamp.fromDate(createdAt),
    'expiresAt':
    Timestamp.fromDate(expiresAt),
    'totalEligible':  totalEligible,
    'yesCount':       yesCount,
    'noCount':        noCount,
    'passThreshold':  passThreshold,
    'proposalData':   proposalData,
  };

  // Computed properties
  int get totalVotes   => yesCount + noCount;
  int get abstainCount =>
      totalEligible - totalVotes;

  double get yesPercentage =>
      totalVotes == 0
          ? 0
          : (yesCount / totalVotes) * 100;

  double get participationRate =>
      totalEligible == 0
          ? 0
          : (totalVotes / totalEligible) * 100;

  bool get isActive  =>
      status == VoteStatus.active &&
          DateTime.now().isBefore(expiresAt);

  bool get isPassed  =>
      status == VoteStatus.passed;

  bool get isExpired =>
      status == VoteStatus.expired ||
          (status == VoteStatus.active &&
              DateTime.now().isAfter(expiresAt));

  Duration get timeLeft =>
      expiresAt.difference(DateTime.now());

  String get typeLabel => switch (type) {
    VoteType.adminTransfer    =>
    'Admin Transfer',
    VoteType.maintenanceChange =>
    'Maintenance Change',
    VoteType.generalPoll      =>
    'General Poll',
  };

  String get typeIcon => switch (type) {
    VoteType.adminTransfer    => '👑',
    VoteType.maintenanceChange => '💰',
    VoteType.generalPoll      => '🗳️',
  };
}

class VoteCastModel {
  final String id;
  final String userId;
  final String vote; // yes / no
  final DateTime castedAt;

  const VoteCastModel({
    required this.id,
    required this.userId,
    required this.vote,
    required this.castedAt,
  });

  factory VoteCastModel.fromDoc(
      DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VoteCastModel(
      id:       doc.id,
      userId:   d['userId'] as String? ?? '',
      vote:     d['vote'] as String? ?? 'yes',
      castedAt: d['castedAt'] != null
          ? (d['castedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}