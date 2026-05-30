import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/society_model.dart';

class MemberRepository {
  final _db = FirebaseFirestore.instance;

  // ── Get flats for society ───────────────────────────────────────────────────
  Future<List<FlatModel>> getFlats(String societyId) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('flats')
        .orderBy('flatNumber')
        .get();
    return snap.docs
        .map((d) => FlatModel.fromDoc(d))
        .toList();
  }

  // ── Get user document ───────────────────────────────────────────────────────
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  // ── Create or update user profile ──────────────────────────────────────────
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name':      name,
      'phone':     phone,
      'role':      'owner',
      'societyId': null,
      'flatId':    null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Submit join request ─────────────────────────────────────────────────────
  Future<void> submitJoinRequest({
    required String societyId,
    required String userId,
    required String userName,
    required String userPhone,
    required String flatId,
    required String flatNumber,
    required UserRole role,
  }) async {
    // Check if request already exists — prevent duplicates
    final existing = await _db
        .collection('societies')
        .doc(societyId)
        .collection('memberRequests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Request already exists — don't create another
      return;
    }

    final batch  = _db.batch();

    // Create member request
    final reqRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('memberRequests')
        .doc();

    batch.set(reqRef, MemberRequestModel(
      id:          reqRef.id,
      userId:      userId,
      userName:    userName,
      userPhone:   userPhone,
      flatId:      flatId,
      flatNumber:  flatNumber,
      role:        role,
      status:      MemberRequestStatus.pending,
      requestedAt: DateTime.now(),
    ).toMap());

    // ← KEY FIX: Save societyId to user profile
    // This prevents going back to InviteCodeScreen
    batch.set(
      _db.collection('users').doc(userId),
      {
        'societyId': societyId,
        'name':      userName,
        'phone':     userPhone,
        'role':      role.name,
        'flatId':    null,    // null until approved
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ── Get pending requests (for admin) ────────────────────────────────────────
  Stream<List<MemberRequestModel>> watchPendingRequests(
      String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('memberRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
        .map((d) => MemberRequestModel.fromDoc(d))
        .toList());
  }

  // ── Approve request ─────────────────────────────────────────────────────────
  Future<void> approveRequest({
    required String societyId,
    required String requestId,
    required String userId,
    required String flatId,
    required UserRole role,
  }) async {
    final batch = _db.batch();

    // 1. Update request status
    batch.update(
      _db.collection('societies')
          .doc(societyId)
          .collection('memberRequests')
          .doc(requestId),
      {'status': 'approved'},
    );

    // 2. Update flat with billing info
    final flatUpdate = role == UserRole.owner
        ? {
      'ownerId':              userId,
      'status':               'occupied',
      'billingResponsibleId': userId,
      'billingRole':          'owner',
    }
        : {
      'tenantId': userId,
      'status':   'occupied',
    };

    batch.update(
      _db.collection('societies')
          .doc(societyId)
          .collection('flats')
          .doc(flatId),
      flatUpdate,
    );

    // 3. Update user profile
    // Setting flatId triggers AuthWrapper
    // to show ResidentDashboard
    batch.update(
      _db.collection('users').doc(userId),
      {
        'societyId': societyId,
        'flatId':    flatId,
        'role':      role.name,
      },
    );

    await batch.commit();
  }

  // ── Reject request ──────────────────────────────────────────────────────────
  Future<void> rejectRequest({
    required String societyId,
    required String requestId,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('memberRequests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }
}