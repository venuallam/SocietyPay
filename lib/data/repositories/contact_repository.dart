import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactRepository {
  final _db = FirebaseFirestore.instance;

  // ── Watch all contacts ──────────────────────────
  Stream<List<ContactModel>> watchContacts(
      String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('contacts')
        .snapshots()
        .map((s) => s.docs
        .map((d) => ContactModel.fromDoc(d))
        .toList()
      ..sort((a, b) =>
          a.category.index
              .compareTo(b.category.index)));
  }

  // ── Add contact (admin) ────────────────────────
  Future<void> addContact({
    required String societyId,
    required String name,
    required String phone,
    required ContactCategory category,
    required String adminId,
    bool isDefault = false,
  }) async {
    final ref = _db
        .collection('societies')
        .doc(societyId)
        .collection('contacts')
        .doc();

    await ref.set(ContactModel(
      id:        ref.id,
      name:      name,
      phone:     phone,
      category:  category,
      isDefault: isDefault,
      addedBy:   adminId,
      createdAt: DateTime.now(),
    ).toMap());
  }

  // ── Edit contact (admin) ───────────────────────
  Future<void> editContact({
    required String societyId,
    required String contactId,
    required String name,
    required String phone,
    required ContactCategory category,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('contacts')
        .doc(contactId)
        .update({
      'name':     name,
      'phone':    phone,
      'category': category.name,
    });
  }

  // ── Delete contact (admin, non-default) ────────
  Future<void> deleteContact({
    required String societyId,
    required String contactId,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  // ── Submit suggestion (member) ─────────────────
  Future<void> submitSuggestion({
    required String societyId,
    required String name,
    required String phone,
    required ContactCategory category,
    required String userId,
    required String userName,
  }) async {
    final ref = _db
        .collection('societies')
        .doc(societyId)
        .collection('contactSuggestions')
        .doc();

    await ref.set(ContactSuggestionModel(
      id:              ref.id,
      name:            name,
      phone:           phone,
      category:        category,
      suggestedBy:     userId,
      suggestedByName: userName,
      status:          'pending',
      createdAt:       DateTime.now(),
    ).toMap());
  }

  // ── Watch suggestions (admin) ──────────────────
  Stream<List<ContactSuggestionModel>>
  watchPendingSuggestions(String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('contactSuggestions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
        .map((d) =>
        ContactSuggestionModel.fromDoc(d))
        .toList());
  }

  // ── Approve suggestion (admin) ─────────────────
  Future<void> approveSuggestion({
    required String societyId,
    required String suggestionId,
    required String adminId,
    required ContactSuggestionModel suggestion,
  }) async {
    final batch = _db.batch();

    // Add as contact
    final contactRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('contacts')
        .doc();

    batch.set(contactRef, ContactModel(
      id:        contactRef.id,
      name:      suggestion.name,
      phone:     suggestion.phone,
      category:  suggestion.category,
      addedBy:   adminId,
      createdAt: DateTime.now(),
    ).toMap());

    // Update suggestion status
    batch.update(
      _db.collection('societies')
          .doc(societyId)
          .collection('contactSuggestions')
          .doc(suggestionId),
      {'status': 'approved'},
    );

    await batch.commit();
  }

  // ── Reject suggestion (admin) ──────────────────
  Future<void> rejectSuggestion({
    required String societyId,
    required String suggestionId,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('contactSuggestions')
        .doc(suggestionId)
        .update({'status': 'rejected'});
  }
}