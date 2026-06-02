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
  // flats: list of {flatNumber: String, typeName: String}
  // The repository resolves typeName → flatTypeId using the
  // flat type docs it creates in the same batch.
  Future<SocietyModel> createSociety({
    required String adminId,
    required String name,
    required String address,
    required List<FlatTypeModel> flatTypes,
    required List<Map<String, dynamic>> flats,
  }) async {
    final batch      = _db.batch();
    final societyRef = _db.collection('societies').doc();
    final inviteCode = _generateInviteCode();
    final now        = DateTime.now();

    // 1. Create society document
    final society = SocietyModel(
      id:         societyRef.id,
      name:       name,
      totalFlats: flats.length,
      inviteCode: inviteCode,
      adminId:    adminId,
      address:    address.isEmpty ? null : address,
      createdAt:  now,
    );
    batch.set(societyRef, society.toMap());

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

    // 6. Set admin user profile
    batch.set(
      _db.collection('users').doc(adminId),
      {
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
