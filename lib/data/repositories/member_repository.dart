import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/society_model.dart';
import '../services/notification_service.dart';

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

    // Notify admin someone wants to join
    notificationService.notifyAdmin(
      societyId: societyId,
      title: '👤 New Join Request',
      body:  '$userName wants to join as '
             '${role.name} in Flat $flatNumber. '
             'Please review and approve.',
      type:  'memberRequestReceived',
    ).catchError((_) {});
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
    String? userName,
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

    // 2. Update flat with billing info + resident name
    final flatUpdate = role == UserRole.owner
        ? {
      'ownerId':              userId,
      'ownerName':            userName ?? '',
      'status':               'occupied',
      'billingResponsibleId': userId,
      'billingRole':          'owner',
    }
        : {
      'tenantId':   userId,
      'tenantName': userName ?? '',
      'status':     'occupied',
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

    // Notify the approved member
    notificationService.notifyUser(
      userId: userId,
      title:  '🎉 Request Approved!',
      body:   'Welcome! Your request to join '
              'Flat $flatId has been approved. '
              'You now have full access.',
      type:   'memberRequestApproved',
    ).catchError((_) {});
  }

  // ── Count unpaid/reported dues for a resident ───────────────────────────────
  Future<int> getUnpaidDuesCount(
      String societyId, String userId) async {
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('billingResponsibleId', isEqualTo: userId)
        .where('status', whereIn: ['unpaid', 'reported'])
        .get();
    return snap.docs.length;
  }

  // ── Remove a resident from a flat (e.g. flat sold) ──────────────────────────
  // Vacates the flat (or just clears the tenant slot if an owner/other
  // resident remains) and unlinks the user from the flat. Past bills are
  // left untouched so billing history stays intact.
  Future<void> removeResident({
    required String societyId,
    required String flatId,
    required String flatNumber,
    required String userId,
    required String userName,
    required UserRole role,
  }) async {
    final flatRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('flats')
        .doc(flatId);

    final flatSnap = await flatRef.get();
    final flatData = flatSnap.data() as Map<String, dynamic>? ?? {};

    final flatUpdate = <String, dynamic>{};
    if (role == UserRole.owner) {
      flatUpdate['ownerId']   = null;
      flatUpdate['ownerName'] = null;
    } else {
      flatUpdate['tenantId']   = null;
      flatUpdate['tenantName'] = null;
    }

    final remainingOwner =
        role == UserRole.owner ? null : flatData['ownerId'];
    final remainingTenant =
        role == UserRole.tenant ? null : flatData['tenantId'];

    if (remainingOwner == null && remainingTenant == null) {
      flatUpdate['status']               = 'vacant';
      flatUpdate['billingResponsibleId'] = null;
      flatUpdate['billingRole']          = null;
    } else if (flatData['billingResponsibleId'] == userId) {
      flatUpdate['billingResponsibleId'] = null;
      flatUpdate['billingRole']          = null;
    }

    final batch = _db.batch();
    batch.update(flatRef, flatUpdate);
    batch.update(
      _db.collection('users').doc(userId),
      {'flatId': null},
    );
    await batch.commit();

    // Notify all members that the flat is now vacant / changed hands
    notificationService.notifyAllMembers(
      societyId: societyId,
      title: '🏠 Flat $flatNumber Update',
      body:  '$userName has been removed as a resident '
             'of Flat $flatNumber. The flat is now vacant.',
      type:  'residentRemoved',
    ).catchError((_) {});
  }

  // ── Reject request ──────────────────────────────────────────────────────────
  Future<void> rejectRequest({
    required String societyId,
    required String requestId,
  }) async {
    // Read request to get userId
    final snap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('memberRequests')
        .doc(requestId)
        .get();
    final data       = snap.data() as Map<String, dynamic>?;
    final applicantId = data?['userId'] as String?;
    final flatNumber  = data?['flatNumber'] as String? ?? '';

    await _db
        .collection('societies')
        .doc(societyId)
        .collection('memberRequests')
        .doc(requestId)
        .update({'status': 'rejected'});

    // Notify the applicant
    if (applicantId != null) {
      notificationService.notifyUser(
        userId: applicantId,
        title:  '❌ Request Not Approved',
        body:   'Your request to join '
                'Flat $flatNumber was not approved. '
                'Please contact your society admin.',
        type:   'memberRequestRejected',
      ).catchError((_) {});
    }
  }
}