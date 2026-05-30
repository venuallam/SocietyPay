import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/society_model.dart';

class SocietyRepository {
  final _db = FirebaseFirestore.instance;

  // ── Generate unique 6-char invite code ─────────────────────────────────────
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng   = Random();
    return List.generate(6,
            (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create Society ──────────────────────────────────────────────────────────
  Future<SocietyModel> createSociety({
    required String adminId,
    required String name,
    required int totalFlats,
    required List<FlatTypeModel> flatTypes,
  }) async {
    final batch      = _db.batch();
    final societyRef = _db.collection('societies').doc();
    final inviteCode = _generateInviteCode();
    final now        = DateTime.now();

    // 1. Create society document
    final society = SocietyModel(
      id:         societyRef.id,
      name:       name,
      totalFlats: totalFlats,
      inviteCode: inviteCode,
      adminId:    adminId,
      createdAt:  now,
    );
    batch.set(societyRef, society.toMap());

    // 2. Create flat type documents
    for (final ft in flatTypes) {
      final ftRef = societyRef
          .collection('flatTypes').doc();
      batch.set(ftRef, ft.toMap());
    }

    // 3. Create flat documents (all vacant)
    for (int i = 1; i <= totalFlats; i++) {
      final flatRef = societyRef
          .collection('flats').doc();
      batch.set(flatRef, {
        'flatNumber':          'Flat-$i',
        'flatTypeId':          flatTypes.first.id,
        'status':              'vacant',
        'ownerId':             null,
        'tenantId':            null,
        'billingResponsibleId':null,
        'billingRole':         'vacant',
      });
    }

    // 4. Create corpus document
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

    // 5. Add default emergency contacts
    final defaultContacts = [
      {'name': 'Police',       'phone': '100',  'category': 'emergency'},
      {'name': 'Fire Brigade', 'phone': '101',  'category': 'emergency'},
      {'name': 'Ambulance',    'phone': '102',  'category': 'emergency'},
      {'name': 'Gas Emergency','phone': '1906', 'category': 'emergency'},
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

    // 6. Update user with societyId and admin role
    batch.set(
      _db.collection('users').doc(adminId),
      {
        'societyId': societyRef.id,
        'role':      'admin',
        'createdAt': Timestamp.now(),
      },
      SetOptions(merge: true),   // ← merge: true creates if not exists
    );

    // Commit all at once
    await batch.commit();

    return society;
  }

  // ── Get Society by Invite Code ──────────────────────────────────────────────
  Future<SocietyModel?> getSocietyByInviteCode(String code) async {
    final query = await _db
        .collection('societies')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return SocietyModel.fromDoc(query.docs.first);
  }

  // ── Get Society ─────────────────────────────────────────────────────────────
  Future<SocietyModel?> getSociety(String societyId) async {
    final doc = await _db
        .collection('societies')
        .doc(societyId)
        .get();
    if (!doc.exists) return null;
    return SocietyModel.fromDoc(doc);
  }
}