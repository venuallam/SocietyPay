import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/society_model.dart';
import '../services/notification_service.dart';

class SocietyRepository {
  final _db = FirebaseFirestore.instance;

  // ── List members eligible to become admin ──────────
  // (society members who are owners/tenants, not the
  //  current admin).
  Future<List<Map<String, dynamic>>>
      getTransferCandidates(String societyId) async {
    final snap = await _db
        .collection('users')
        .where('societyId', isEqualTo: societyId)
        .get();
    return snap.docs
        .where((d) =>
    (d.data()['role'] as String?) != 'admin' &&
        (d.data()['flatId'] as String?) != null)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
  }

  // ── Direct admin transfer (current admin only) ─────
  // Runs on the current admin's device, so security
  // rules permit all three writes (the requester is
  // still admin at evaluation time, atomically).
  Future<void> transferAdmin({
    required String societyId,
    required String newAdminId,
    required String oldAdminId,
  }) async {
    final batch = _db.batch();

    // 1. Point the society to the new admin
    batch.update(
      _db.collection('societies').doc(societyId),
      {'adminId': newAdminId},
    );
    // 2. Promote new admin
    batch.update(
      _db.collection('users').doc(newAdminId),
      {'role': 'admin'},
    );
    // 3. Demote old admin to owner
    batch.update(
      _db.collection('users').doc(oldAdminId),
      {'role': 'owner'},
    );

    await batch.commit();

    // Notify the new admin
    notificationService.notifyUser(
      userId: newAdminId,
      title:  '👑 You are now the Admin',
      body:   'You have been made the admin of your '
              'society. You can now manage billing, '
              'expenses and members.',
      type:   'adminTransferred',
    ).catchError((_) {});
  }

  // ── Generate unique 6-char invite code ─────────────────────────────────────
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng   = Random();
    return List.generate(6,
            (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create Society ──────────────────────────────────────────────────────────
  // flats: list of {flatNumber: String, typeName: String}
  // The repository resolves typeName → flatTypeId using the
  // flat type docs it creates in the same batch.
  Future<SocietyModel> createSociety({
    required String adminId,
    required String adminName,
    required String name,
    required String address,
    required List<FlatTypeModel> flatTypes,
    required List<Map<String, dynamic>> flats,
  }) async {
    final societyRef = _db.collection('societies').doc();
    final inviteCode = _generateInviteCode();
    final now        = DateTime.now();

    // 1. Create society document FIRST (separate commit).
    //    Security rules determine admin status from
    //    society.adminId, so this doc must be committed
    //    before the batch below — otherwise isAdmin() can't
    //    resolve for the flat/corpus/contact writes.
    final society = SocietyModel(
      id:         societyRef.id,
      name:       name,
      totalFlats: flats.length,
      inviteCode: inviteCode,
      adminId:    adminId,
      address:    address.isEmpty ? null : address,
      createdAt:  now,
    );
    await societyRef.set(society.toMap());

    // Everything else in one atomic batch (isAdmin now true)
    final batch = _db.batch();

    // 2. Create flat type docs — build name→id map
    final typeNameToId   = <String, String>{};
    final typeNameToModel = <String, FlatTypeModel>{};

    for (final ft in flatTypes) {
      final ftRef = societyRef
          .collection('flatTypes').doc();
      batch.set(ftRef, ft.toMap());
      typeNameToId[ft.typeName]    = ftRef.id;
      typeNameToModel[ft.typeName] = ft;
    }

    // 3. Create flat documents using pre-built flat list
    for (final flat in flats) {
      final flatRef  = societyRef
          .collection('flats').doc();
      final typeName = flat['typeName'] as String;
      final typeId   = typeNameToId[typeName]
          ?? typeNameToId.values.first;

      batch.set(flatRef, {
        'flatNumber':           flat['flatNumber'],
        'flatTypeId':           typeId,
        'flatTypeName':         typeName,
        'status':               'vacant',
        'ownerId':              null,
        'tenantId':             null,
        'billingResponsibleId': null,
        'billingRole':          'vacant',
      });
    }

    // 4. Create corpus document (zeroed out)
    batch.set(
      _db.collection('corpus').doc(societyRef.id),
      {
        'currentBalance':   0.0,
        'minimumReserve':   0.0,
        'openingBalance':   0.0,
        'lastUpdated':      Timestamp.now(),
        'lastMonthSurplus': 0.0,
        'isInDeficit':      false,
        'isBelowReserve':   false,
      },
    );

    // 5. Default emergency contacts
    final defaultContacts = [
      {'name': 'Police',        'phone': '100',  'category': 'emergency'},
      {'name': 'Fire Brigade',  'phone': '101',  'category': 'emergency'},
      {'name': 'Ambulance',     'phone': '102',  'category': 'emergency'},
      {'name': 'Gas Emergency', 'phone': '1906', 'category': 'emergency'},
    ];
    for (final contact in defaultContacts) {
      final cRef = societyRef.collection('contacts').doc();
      batch.set(cRef, {
        ...contact,
        'isDefault': true,
        'addedBy':   adminId,
        'createdAt': Timestamp.now(),
      });
    }

    // 6. Set admin user profile (including name)
    batch.set(
      _db.collection('users').doc(adminId),
      {
        'name':      adminName.trim(),
        'societyId': societyRef.id,
        'role':      'admin',
        'createdAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return society;
  }

  // ── Get Society by Invite Code ──────────────────────────────────────────────
  Future<SocietyModel?> getSocietyByInviteCode(
      String code) async {
    final query = await _db
        .collection('societies')
        .where('inviteCode',
        isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return SocietyModel.fromDoc(query.docs.first);
  }

  // ── Get Society ─────────────────────────────────────────────────────────────
  Future<SocietyModel?> getSociety(
      String societyId) async {
    final doc = await _db
        .collection('societies')
        .doc(societyId)
        .get();
    if (!doc.exists) return null;
    return SocietyModel.fromDoc(doc);
  }
}
