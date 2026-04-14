// ─────────────────────────────────────────────────────────────────────────────
// RegistryService
// FILE: lib/features/admin/data/services/registry_service.dart
//
// CHANGES:
//  1. All scoring now delegates to RegistryMatcher.scoreOne() and
//     RegistryMatcher.findBestMatch() — no duplicate scoring logic here.
//
//  2. _checkByStudentId and _checkByNameAndBatch are simplified: they now
//     just fetch the right Firestore candidates and hand them to
//     RegistryMatcher.findBestMatch(). This eliminates the old _score()
//     method entirely.
//
//  3. uploadRecords() auto-match loop now uses RegistryMatcher.findBestMatch()
//     for consistency — previously it called checkUser() which had its own
//     path through the old _score() method.
//
//  4. After a successful registration, register() in RegisterScreen must now
//     also write a /student_id_map/{studentId} doc if studentId is non-empty.
//     That write is documented here but lives in register_screen.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni/features/admin/data/models/alumni_registry_models.dart';
import 'package:alumni/features/admin/data/services/registry_matcher.dart';

class RegistryService {
  final _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  CHECK USER AGAINST REGISTRY
  //  Called by RegisterScreen during the registry check step.
  // ══════════════════════════════════════════════════════════════════════════

  Future<MatchResult> checkUser({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    String studentId = '',
  }) async {
    // ── Fast path: if a studentId is provided, try an exact-ID lookup first ──
    // This narrows the candidate pool significantly and is deterministic.
    if (studentId.trim().isNotEmpty) {
      final idResult = await _checkByStudentId(
        studentId: studentId.trim(),
        fullName: fullName,
        batch: batch,
        course: course,
        email: email,
      );
      // Only short-circuit if we actually found a confident match.
      // If the ID is in the registry but the name is completely wrong
      // (score < threshold), fall through to the name+batch path.
      if (idResult != null &&
          idResult.confidence >= RegistryMatcher.matchThreshold) {
        return idResult;
      }
    }

    // ── Full scan narrowed by batch year ──
    return _checkByNameAndBatch(
      fullName: fullName,
      batch: batch,
      course: course,
      email: email,
      studentId: studentId,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch records matching the given studentId, then score with RegistryMatcher
  // ─────────────────────────────────────────────────────────────────────────
  Future<MatchResult?> _checkByStudentId({
    required String studentId,
    required String fullName,
    required String batch,
    required String course,
    required String email,
  }) async {
    try {
      final snap = await _db
          .collection('alumni_registry')
          .where('studentId', isEqualTo: studentId)
          .where('isMatched', isEqualTo: false)
          .limit(5)  // there should only ever be 1, but guard against dupes
          .get();

      if (snap.docs.isEmpty) return null;

      final candidates = snap.docs
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList();

      // Use RegistryMatcher as the single scorer
      final result = RegistryMatcher.findBestMatch(
        fullName: fullName,
        batch: batch,
        course: course,
        email: email,
        studentId: studentId,
        registry: candidates,
      );

      return result;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch all unmatched records for the given batch, then score
  // ─────────────────────────────────────────────────────────────────────────
  Future<MatchResult> _checkByNameAndBatch({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    required String studentId,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      if (batch.isNotEmpty) {
        // Narrow by batch first — O(batch_size) instead of O(registry_size)
        snap = await _db
            .collection('alumni_registry')
            .where('batch', isEqualTo: batch)
            .where('isMatched', isEqualTo: false)
            .get();
      } else {
        // No batch — scan up to 500 unmatched records
        snap = await _db
            .collection('alumni_registry')
            .where('isMatched', isEqualTo: false)
            .limit(500)
            .get();
      }
    } catch (_) {
      return const MatchResult(
          isMatch: false, confidence: 0, record: null);
    }

    if (snap.docs.isEmpty) {
      return const MatchResult(
          isMatch: false, confidence: 0, record: null);
    }

    final candidates = snap.docs
        .map((d) => AlumniRecord.fromMap(d.id, d.data()))
        .toList();

    // Delegate entirely to RegistryMatcher
    return RegistryMatcher.findBestMatch(
      fullName: fullName,
      batch: batch,
      course: course,
      email: email,
      studentId: studentId,
      registry: candidates,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPLOAD MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<RegistryUpload> uploadRecords({
    required List<AlumniRecord> records,
    required String fileName,
    required String uploadedByName,
  }) async {
    final batchId = _db.collection('registry_uploads').doc().id;

    final uploadRef =
        _db.collection('registry_uploads').doc(batchId);
    await uploadRef.set({
      'fileName': fileName,
      'totalRecords': records.length,
      'matchedCount': 0,
      'status': 'processing',
      'uploadedByName': uploadedByName,
      'uploadedBy': uploadedByName,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // ── Write registry records in chunks of 400 ──
    const chunkSize = 400;
    for (var i = 0; i < records.length; i += chunkSize) {
      final end = (i + chunkSize) > records.length
          ? records.length
          : i + chunkSize;
      final chunk = records.sublist(i, end);
      final wb = _db.batch();

      for (final record in chunk) {
        final docRef = _db.collection('alumni_registry').doc();
        wb.set(docRef, {
          'firstName':   record.firstName,
          'lastName':    record.lastName,
          'fullName':    record.fullName,
          'batch':       record.batch,
          'course':      record.course,
          'email':       record.email,
          'studentId':   record.studentId,
          'uploadBatchId': batchId,
          'isMatched':   false,
          'matchedUserId': '',
          'createdAt':   FieldValue.serverTimestamp(),
        });
      }
      await wb.commit();
    }

    // ── Auto-match existing pending users against the newly uploaded records ──
    int matchedCount = 0;
    try {
      final pendingSnap = await _db
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final userDoc in pendingSnap.docs) {
        final userData = userDoc.data();

        // Re-fetch fresh unmatched records for this user's batch
        final userBatch =
            userData['batch']?.toString().trim() ?? '';
        final candidateSnap = userBatch.isNotEmpty
            ? await _db
                .collection('alumni_registry')
                .where('batch', isEqualTo: userBatch)
                .where('isMatched', isEqualTo: false)
                .get()
            : await _db
                .collection('alumni_registry')
                .where('isMatched', isEqualTo: false)
                .limit(500)
                .get();

        if (candidateSnap.docs.isEmpty) continue;

        final candidates = candidateSnap.docs
            .map((d) => AlumniRecord.fromMap(d.id, d.data()))
            .toList();

        // Use RegistryMatcher — consistent with all other paths
        final result = RegistryMatcher.findBestMatch(
          fullName:  userData['name']?.toString() ?? '',
          batch:     userBatch,
          course:    userData['course']?.toString() ?? '',
          email:     userData['email']?.toString() ?? '',
          studentId: userData['studentId']?.toString() ?? '',
          registry:  candidates,
        );

        if (result.isMatch && result.record != null) {
          matchedCount++;
          final batchWrite = _db.batch();

          batchWrite.update(
            _db.collection('users').doc(userDoc.id),
            {
              'verificationStatus': 'verified',
              'status': 'active',
              'verifiedAt':  FieldValue.serverTimestamp(),
              'verifiedBy':  'system_auto',
              'registryMatchId':  result.record!.id,
              'matchConfidence':  result.confidence,
            },
          );

          batchWrite.update(
            _db.collection('alumni_registry').doc(result.record!.id),
            {
              'isMatched':    true,
              'matchedUserId': userDoc.id,
            },
          );

          await batchWrite.commit();
        }
      }
    } catch (e) {
      // Non-fatal — upload still succeeded even if auto-match fails
    }

    await uploadRef.update({
      'matchedCount': matchedCount,
      'status': 'done',
    });

    return RegistryUpload(
      id:           batchId,
      fileName:     fileName,
      totalRecords: records.length,
      matchedCount: matchedCount,
      status:       'done',
      uploadedBy:   uploadedByName,
      uploadedByName: uploadedByName,
      uploadedAt:   DateTime.now(),
    );
  }

  Future<void> deleteUpload(String uploadId) async {
    final snap = await _db
        .collection('alumni_registry')
        .where('uploadBatchId', isEqualTo: uploadId)
        .get();

    const chunkSize = 400;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final end = (i + chunkSize) > snap.docs.length
          ? snap.docs.length
          : i + chunkSize;
      final chunk = snap.docs.sublist(i, end);
      final wb = _db.batch();
      for (final doc in chunk) {
        wb.delete(doc.reference);
      }
      await wb.commit();
    }
    await _db
        .collection('registry_uploads')
        .doc(uploadId)
        .delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAMS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<RegistryUpload>> uploadsStream() {
    return _db
        .collection('registry_uploads')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                RegistryUpload.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<AlumniRecord>> recordsStream(String uploadId) {
    return _db
        .collection('alumni_registry')
        .where('uploadBatchId', isEqualTo: uploadId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => AlumniRecord.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return list;
    });
  }

  Stream<List<AlumniRecord>> allRecordsStream({String? search}) {
    return _db
        .collection('alumni_registry')
        .snapshots()
        .map((snap) {
      final records = snap.docs
          .map((doc) => AlumniRecord.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      if (search == null || search.trim().isEmpty) return records;

      final q = search.trim().toLowerCase();
      return records.where((r) {
        return r.fullName.toLowerCase().contains(q) ||
            r.batch.contains(q) ||
            r.course.toLowerCase().contains(q) ||
            r.email.toLowerCase().contains(q) ||
            r.studentId.toLowerCase().contains(q);
      }).toList();
    });
  }
}