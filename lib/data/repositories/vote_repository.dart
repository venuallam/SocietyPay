import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vote_model.dart';

class VoteRepository {
  final _db = FirebaseFirestore.instance;

  // ── Watch all votes ─────────────────────────────
  Stream<List<VoteModel>> watchVotes(
      String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) => VoteModel.fromDoc(d))
        .toList());
  }

  // ── Watch active votes ──────────────────────────
  Stream<List<VoteModel>> watchActiveVotes(
      String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs
        .map((d) => VoteModel.fromDoc(d))
        .toList());
  }

  // ── Create vote ─────────────────────────────────
  Future<String> createVote({
    required String societyId,
    required VoteType type,
    required String title,
    required String description,
    required String createdBy,
    required String createdByName,
    required int durationDays,
    required double passThreshold,
    Map<String, dynamic>? proposalData,
  }) async {
    // Count eligible voters
    final membersSnap = await _db
        .collection('users')
        .where('societyId', isEqualTo: societyId)
        .where('flatId', isNotEqualTo: null)
        .get();

    final eligible = membersSnap.docs
        .where((d) =>
    (d.data()['role'] as String?) != 'admin')
        .length;

    final ref = _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc();

    final vote = VoteModel(
      id:            ref.id,
      type:          type,
      title:         title,
      description:   description,
      status:        VoteStatus.active,
      createdBy:     createdBy,
      createdByName: createdByName,
      createdAt:     DateTime.now(),
      expiresAt:     DateTime.now().add(
          Duration(days: durationDays)),
      totalEligible: eligible,
      passThreshold: passThreshold,
      proposalData:  proposalData,
    );

    await ref.set(vote.toMap());
    return ref.id;
  }

  // ── Cast vote ───────────────────────────────────
  Future<void> castVote({
    required String societyId,
    required String voteId,
    required String userId,
    required String choice, // yes / no
  }) async {
    final batch   = _db.batch();
    final voteRef = _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId);

    // Save individual vote
    final castRef = voteRef
        .collection('casts')
        .doc(userId); // userId as doc ID prevents double voting

    batch.set(castRef, {
      'userId':   userId,
      'vote':     choice,
      'castedAt': Timestamp.now(),
    });

    // Increment counter
    batch.update(voteRef, {
      choice == 'yes'
          ? 'yesCount' : 'noCount':
      FieldValue.increment(1),
    });

    await batch.commit();

    // Check if vote should auto-pass/reject
    await _checkVoteResult(
      societyId: societyId,
      voteId:    voteId,
    );
  }

  // ── Check if user already voted ─────────────────
  Future<bool> hasUserVoted({
    required String societyId,
    required String voteId,
    required String userId,
  }) async {
    final doc = await _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId)
        .collection('casts')
        .doc(userId)
        .get();
    return doc.exists;
  }

  // ── Get user vote ───────────────────────────────
  Future<String?> getUserVote({
    required String societyId,
    required String voteId,
    required String userId,
  }) async {
    final doc = await _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId)
        .collection('casts')
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return (doc.data()
    as Map<String, dynamic>)['vote']
    as String?;
  }

  // ── Check vote result ───────────────────────────
  Future<void> _checkVoteResult({
    required String societyId,
    required String voteId,
  }) async {
    final voteDoc = await _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId)
        .get();

    if (!voteDoc.exists) return;
    final vote = VoteModel.fromDoc(voteDoc);

    // All eligible voted — determine result
    if (vote.totalVotes >= vote.totalEligible) {
      final passed =
          vote.yesPercentage >= vote.passThreshold;
      await _db
          .collection('societies')
          .doc(societyId)
          .collection('votes')
          .doc(voteId)
          .update({
        'status': passed
            ? VoteStatus.passed.name
            : VoteStatus.rejected.name,
      });

      // Handle vote result
      if (passed) {
        await _handlePassedVote(
          societyId: societyId,
          vote:      vote,
        );
      }
    }
  }

  // ── Handle passed vote ──────────────────────────
  Future<void> _handlePassedVote({
    required String societyId,
    required VoteModel vote,
  }) async {
    switch (vote.type) {
      case VoteType.maintenanceChange:
        final newAmount = vote.proposalData?
        ['newAmount'] as num?;
        final flatTypeId = vote.proposalData?
        ['flatTypeId'] as String?;
        if (newAmount != null &&
            flatTypeId != null) {
          await _db
              .collection('societies')
              .doc(societyId)
              .collection('flatTypes')
              .doc(flatTypeId)
              .update({
            'maintenanceAmount':
            newAmount.toDouble(),
            'effectiveFrom':
            Timestamp.now(),
          });
        }
        break;

      case VoteType.adminTransfer:
        final newAdminId = vote.proposalData?
        ['newAdminId'] as String?;
        final oldAdminId = vote.createdBy;
        if (newAdminId != null) {
          final batch = _db.batch();
          // Update new admin
          batch.update(
              _db.collection('users')
                  .doc(newAdminId),
              {'role': 'admin'});
          // Update old admin
          batch.update(
              _db.collection('users')
                  .doc(oldAdminId),
              {'role': 'owner'});
          // Update society
          batch.update(
              _db.collection('societies')
                  .doc(societyId),
              {'adminId': newAdminId});
          await batch.commit();
        }
        break;

      case VoteType.generalPoll:
      // No automatic action needed
        break;
    }
  }

  // ── Expire vote manually ────────────────────────
  Future<void> expireVote({
    required String societyId,
    required String voteId,
    required VoteModel vote,
  }) async {
    final passed =
        vote.yesPercentage >= vote.passThreshold &&
            vote.totalVotes > 0;

    await _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId)
        .update({
      'status': passed
          ? VoteStatus.passed.name
          : VoteStatus.rejected.name,
    });

    if (passed) {
      await _handlePassedVote(
        societyId: societyId,
        vote:      vote,
      );
    }
  }

  // ── Cancel vote (admin) ─────────────────────────
  Future<void> cancelVote({
    required String societyId,
    required String voteId,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId)
        .update({
      'status': VoteStatus.rejected.name,
    });
  }

  // ── Watch vote casts ────────────────────────────
  Stream<List<VoteCastModel>> watchCasts(
      String societyId, String voteId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('votes')
        .doc(voteId)
        .collection('casts')
        .snapshots()
        .map((s) => s.docs
        .map((d) => VoteCastModel.fromDoc(d))
        .toList());
  }
}