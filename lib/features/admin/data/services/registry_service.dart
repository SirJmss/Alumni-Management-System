// ─────────────────────────────────────────────────────────────────────────────
// RegistryService
// FILE: lib/features/admin/data/services/registry_service.dart
//
// ROOT-CAUSE FIX (the "auto-verified never triggers" bug):
//
//   The old queries used:
//     .where('isMatched', isEqualTo: false)
//
//   Firestore only returns documents where the field EXISTS AND equals the
//   value. Documents that were manually created in the Firebase Console, or
//   uploaded before the isMatched field was introduced, simply don't have that
//   field — so they are silently excluded from every query, meaning the
//   matcher never sees the candidate and always returns isMatch=false.
//
//   FIX: Removed the isMatched filter from all queries. Instead:
//     1. We fetch candidates by studentId or batch (cheap, narrow queries).
//     2. We pass them to RegistryMatcher which scores them.
//     3. After a successful match we mark isMatched=true to prevent
//        the same record from being matched again.
//     4. If the query returns a doc that is already matched (isMatched==true),
//        we skip it in the candidate list.
//
//   This is both more robust and more correct than relying on a boolean field
//   that may not exist on older documents.
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
    // ── Fast path: exact Student ID lookup ──────────────────────────────────
    // If a studentId is provided, try it first. This is the most reliable
    // signal and narrows the candidate pool to 1–5 docs.
    if (studentId.trim().isNotEmpty) {
      final idResult = await _checkByStudentId(
        studentId: studentId.trim(),
        fullName: fullName,
        batch: batch,
        course: course,
        email: email,
      );
      if (idResult != null &&
          idResult.confidence >= RegistryMatcher.matchThreshold) {
        return idResult;
      }
    }

    // ── Full scan narrowed by batch year ────────────────────────────────────
    return _checkByNameAndBatch(
      fullName: fullName,
      batch: batch,
      course: course,
      email: email,
      studentId: studentId,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _checkByStudentId
  //
  // FIX: Query only by studentId — NO isMatched filter.
  // Filter already-matched docs client-side after fetching.
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
          .limit(10)
          .get();

      if (snap.docs.isEmpty) return null;

      // FIX: Filter already-matched records CLIENT-SIDE.
      // This handles docs where isMatched field is missing (null/absent).
      final candidates = snap.docs
          .where((d) {
            final isMatched = d.data()['isMatched'];
            // Include if isMatched is false, null, or absent
            return isMatched != true;
          })
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList();

      if (candidates.isEmpty) return null;

      return RegistryMatcher.findBestMatch(
        fullName: fullName,
        batch: batch,
        course: course,
        email: email,
        studentId: studentId,
        registry: candidates,
      );
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _checkByNameAndBatch
  //
  // FIX: Query only by batch — NO isMatched filter.
  // Filter already-matched docs client-side after fetching.
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
        // Narrow by batch — removes ~95% of registry from consideration
        snap = await _db
            .collection('alumni_registry')
            .where('batch', isEqualTo: batch)
            .get();
      } else {
        // No batch provided — scan up to 500 records
        snap = await _db
            .collection('alumni_registry')
            .limit(500)
            .get();
      }
    } catch (_) {
      return const MatchResult(isMatch: false, confidence: 0, record: null);
    }

    if (snap.docs.isEmpty) {
      return const MatchResult(isMatch: false, confidence: 0, record: null);
    }

    // FIX: Filter already-matched records CLIENT-SIDE
    final candidates = snap.docs
        .where((d) {
          final isMatched = d.data()['isMatched'];
          return isMatched != true;
        })
        .map((d) => AlumniRecord.fromMap(d.id, d.data()))
        .toList();

    if (candidates.isEmpty) {
      return const MatchResult(isMatch: false, confidence: 0, record: null);
    }

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

    final uploadRef = _db.collection('registry_uploads').doc(batchId);
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
          'firstName':     record.firstName,
          'lastName':      record.lastName,
          'fullName':      record.fullName,
          'batch':         record.batch,
          'course':        record.course,
          'email':         record.email,
          'studentId':     record.studentId,
          'uploadBatchId': batchId,
          'isMatched':     false,      // always write the field explicitly
          'matchedUserId': '',
          'createdAt':     FieldValue.serverTimestamp(),
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
        final userBatch = userData['batch']?.toString().trim() ?? '';

        // FIX: No isMatched filter in query — filter client-side
        final candidateSnap = userBatch.isNotEmpty
            ? await _db
                .collection('alumni_registry')
                .where('batch', isEqualTo: userBatch)
                .get()
            : await _db
                .collection('alumni_registry')
                .limit(500)
                .get();

        if (candidateSnap.docs.isEmpty) continue;

        final candidates = candidateSnap.docs
            .where((d) => d.data()['isMatched'] != true)
            .map((d) => AlumniRecord.fromMap(d.id, d.data()))
            .toList();

        if (candidates.isEmpty) continue;

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
              'status':            'active',
              'verifiedAt':        FieldValue.serverTimestamp(),
              'verifiedBy':        'system_auto',
              'registryMatchId':   result.record!.id,
              'matchConfidence':   result.confidence,
            },
          );

          batchWrite.update(
            _db.collection('alumni_registry').doc(result.record!.id),
            {
              'isMatched':     true,
              'matchedUserId': userDoc.id,
            },
          );

          await batchWrite.commit();
        }
      }
    } catch (e) {
      // Non-fatal — upload succeeded even if auto-match fails
    }

    await uploadRef.update({
      'matchedCount': matchedCount,
      'status':       'done',
    });

    return RegistryUpload(
      id:              batchId,
      fileName:        fileName,
      totalRecords:    records.length,
      matchedCount:    matchedCount,
      status:          'done',
      uploadedBy:      uploadedByName,
      uploadedByName:  uploadedByName,
      uploadedAt:      DateTime.now(),
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
    await _db.collection('registry_uploads').doc(uploadId).delete();
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
            .map((doc) => RegistryUpload.fromMap(doc.id, doc.data()))
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