// lib/features/admin/data/services/registry_service.dart
//
// KEY FIXES IN THIS VERSION:
//
// 1. checkUser() is an INSTANCE method (not static).
//    register_screen.dart creates: final _registryService = RegistryService()
//    and calls: _registryService.checkUser(...)
//    If it's static, the instance call either fails to compile or silently
//    calls the old unfixed version.
//
// 2. All Firestore queries use AlumniRecord.fromMap(doc.id, doc.data())
//    NOT AlumniRecord.fromDoc(doc) — because in RegistryService we use
//    QueryDocumentSnapshot which is a subtype of DocumentSnapshot, but
//    calling doc.data() explicitly and passing to fromMap() is safer and
//    avoids any casting issues with QueryDocumentSnapshot vs DocumentSnapshot.
//
// 3. REMOVED .where('isMatched', isEqualTo: false) from ALL queries.
//    Firestore only returns docs where the field EXISTS and equals the value.
//    Old registry records created without the isMatched field are silently
//    excluded → matcher sees zero candidates → always returns isMatch=false.
//    FIX: Fetch all candidates for the batch/studentId, then filter
//    already-matched docs CLIENT-SIDE using d['isMatched'] == true.
//
// 4. uploadsStream() uses fromMap(), not fromDoc(), for the same reason.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni/features/admin/data/models/alumni_registry_models.dart';
import 'package:alumni/features/admin/data/services/registry_matcher.dart';
import 'package:flutter/foundation.dart';

class RegistryService {
  final _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════
  //  CHECK USER — called from RegisterScreen
  //
  //  Strategy (fastest to broadest):
  //    1. If studentId provided → exact ID lookup (1-5 docs)
  //    2. Batch narrowed scan (all docs for that batch year)
  //    3. Email lookup (if no batch match found)
  //    4. Full scan up to 500 (last resort, no batch provided)
  // ══════════════════════════════════════════════════════

  Future<MatchResult> checkUser({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    String studentId = '',
  }) async {
    try {
      // ── Strategy 1: Exact Student ID ─────────────────
      if (studentId.trim().isNotEmpty) {
        final result = await _checkByStudentId(
          studentId: studentId.trim(),
          fullName:  fullName,
          batch:     batch,
          course:    course,
          email:     email,
        );
        if (result != null &&
            result.confidence >= RegistryMatcher.matchThreshold) {
          debugPrint(
              '[Registry] Student ID match: ${result.confidence}');
          return result;
        }
      }

      // ── Strategy 2: Email lookup ──────────────────────
      if (email.trim().isNotEmpty) {
        final result = await _checkByEmail(
          email:    email.trim().toLowerCase(),
          fullName: fullName,
          batch:    batch,
          course:   course,
          studentId: studentId,
        );
        if (result != null &&
            result.confidence >= RegistryMatcher.matchThreshold) {
          debugPrint('[Registry] Email match: ${result.confidence}');
          return result;
        }
      }

      // ── Strategy 3: Batch + name scan ────────────────
      final result = await _checkByBatch(
        fullName:  fullName,
        batch:     batch,
        course:    course,
        email:     email,
        studentId: studentId,
      );
      debugPrint(
          '[Registry] Batch scan result: isMatch=${result.isMatch} '
          'confidence=${result.confidence}');
      return result;
    } catch (e) {
      debugPrint('[Registry] checkUser error: $e');
      return MatchResult.noMatch;
    }
  }

  // ── Strategy 1: Student ID ────────────────────────────

  Future<MatchResult?> _checkByStudentId({
    required String studentId,
    required String fullName,
    required String batch,
    required String course,
    required String email,
  }) async {
    try {
      // FIX: NO isMatched filter — query by studentId only
      final snap = await _db
          .collection('alumni_registry')
          .where('studentId', isEqualTo: studentId)
          .limit(10)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('[Registry] No docs found for studentId=$studentId');
        return null;
      }

      debugPrint(
          '[Registry] Found ${snap.docs.length} docs for studentId=$studentId');

      // FIX: Filter already-matched records CLIENT-SIDE
      // d['isMatched'] == true  → already taken by another user, skip
      // d['isMatched'] == false → available
      // d['isMatched'] == null  → field absent on old records, treat as false
      final candidates = snap.docs
          .where((d) => d.data()['isMatched'] != true)
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList();

      if (candidates.isEmpty) {
        debugPrint('[Registry] All studentId docs already matched');
        return null;
      }

      final result = RegistryMatcher.findBestMatch(
        fullName:  fullName,
        batch:     batch,
        course:    course,
        email:     email,
        studentId: studentId,
        registry:  candidates,
      );

      debugPrint(
          '[Registry] StudentID match score: ${result.confidence} '
          'record: ${result.record?.fullName}');
      return result;
    } catch (e) {
      debugPrint('[Registry] _checkByStudentId error: $e');
      return null;
    }
  }

  // ── Strategy 2: Email ─────────────────────────────────

  Future<MatchResult?> _checkByEmail({
    required String email,
    required String fullName,
    required String batch,
    required String course,
    required String studentId,
  }) async {
    try {
      final snap = await _db
          .collection('alumni_registry')
          .where('email', isEqualTo: email)
          .limit(10)
          .get();

      if (snap.docs.isEmpty) return null;

      final candidates = snap.docs
          .where((d) => d.data()['isMatched'] != true)
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList();

      if (candidates.isEmpty) return null;

      return RegistryMatcher.findBestMatch(
        fullName:  fullName,
        batch:     batch,
        course:    course,
        email:     email,
        studentId: studentId,
        registry:  candidates,
      );
    } catch (e) {
      debugPrint('[Registry] _checkByEmail error: $e');
      return null;
    }
  }

  // ── Strategy 3: Batch scan ────────────────────────────

  Future<MatchResult> _checkByBatch({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    required String studentId,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;

      if (batch.isNotEmpty) {
        // FIX: query only by batch — NO isMatched filter
        snap = await _db
            .collection('alumni_registry')
            .where('batch', isEqualTo: batch)
            .get();
        debugPrint(
            '[Registry] Batch query for "$batch" returned ${snap.docs.length} docs');
      } else {
        // No batch — scan all, capped at 500
        snap = await _db
            .collection('alumni_registry')
            .limit(500)
            .get();
        debugPrint(
            '[Registry] Full scan returned ${snap.docs.length} docs');
      }

      if (snap.docs.isEmpty) return MatchResult.noMatch;

      // FIX: Filter client-side
      final candidates = snap.docs
          .where((d) => d.data()['isMatched'] != true)
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList();

      debugPrint(
          '[Registry] Unmatched candidates: ${candidates.length}');

      if (candidates.isEmpty) return MatchResult.noMatch;

      // Log what we're about to match against (helpful for debugging)
      for (final c in candidates.take(5)) {
        debugPrint(
            '[Registry]   candidate: "${c.fullName}" batch="${c.batch}" '
            'course="${c.course}" id="${c.studentId}"');
      }

      final result = RegistryMatcher.findBestMatch(
        fullName:  fullName,
        batch:     batch,
        course:    course,
        email:     email,
        studentId: studentId,
        registry:  candidates,
      );

      debugPrint(
          '[Registry] Best match: "${result.record?.fullName}" '
          'score=${result.confidence} isMatch=${result.isMatch}');
      return result;
    } catch (e) {
      debugPrint('[Registry] _checkByBatch error: $e');
      return MatchResult.noMatch;
    }
  }

  // ══════════════════════════════════════════════════════
  //  UPLOAD RECORDS
  // ══════════════════════════════════════════════════════

  Future<RegistryUpload> uploadRecords({
    required List<AlumniRecord> records,
    required String fileName,
    required String uploadedByName,
  }) async {
    final batchId   = _db.collection('registry_uploads').doc().id;
    final uploadRef = _db.collection('registry_uploads').doc(batchId);

    await uploadRef.set({
      'fileName':       fileName,
      'totalRecords':   records.length,
      'matchedCount':   0,
      'status':         'processing',
      'uploadedByName': uploadedByName,
      'uploadedBy':     uploadedByName,
      'uploadedAt':     FieldValue.serverTimestamp(),
    });

    // Write records in chunks of 400
    const chunkSize = 400;
    for (var i = 0; i < records.length; i += chunkSize) {
      final end   = (i + chunkSize).clamp(0, records.length);
      final chunk = records.sublist(i, end);
      final wb    = _db.batch();

      for (final record in chunk) {
        final docRef = _db.collection('alumni_registry').doc();
        wb.set(docRef, {
          'firstName':     record.firstName,
          'lastName':      record.lastName,
          'fullName':      record.fullName,
          'batch':         record.batch,
          'course':        record.course,
          'email':         record.email.toLowerCase(),
          'studentId':     record.studentId,
          'uploadBatchId': batchId,
          'isMatched':     false,   // ALWAYS write this field explicitly
          'matchedUserId': '',
          'createdAt':     FieldValue.serverTimestamp(),
        });
      }
      await wb.commit();
    }

    // Auto-match pending users against newly uploaded records
    int matchedCount = 0;
    try {
      final pendingSnap = await _db
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final userDoc in pendingSnap.docs) {
        final userData  = userDoc.data();
        final userBatch = userData['batch']?.toString().trim() ?? '';

        // FIX: No isMatched filter — client-side filter below
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
          final wb = _db.batch();
          wb.update(_db.collection('users').doc(userDoc.id), {
            'verificationStatus': 'verified',
            'status':             'active',
            'verifiedAt':         FieldValue.serverTimestamp(),
            'verifiedBy':         'system_auto',
            'registryMatchId':    result.record!.id,
            'matchConfidence':    result.confidence,
          });
          wb.update(
              _db.collection('alumni_registry').doc(result.record!.id),
              {
                'isMatched':     true,
                'matchedUserId': userDoc.id,
              });
          await wb.commit();
        }
      }
    } catch (e) {
      debugPrint('[Registry] uploadRecords auto-match error: $e');
    }

    await uploadRef.update({
      'matchedCount': matchedCount,
      'status':       'done',
    });

    return RegistryUpload(
      id:             batchId,
      fileName:       fileName,
      totalRecords:   records.length,
      matchedCount:   matchedCount,
      status:         'done',
      uploadedBy:     uploadedByName,
      uploadedByName: uploadedByName,
      uploadedAt:     DateTime.now(),
    );
  }

  Future<void> deleteUpload(String uploadId) async {
    const chunkSize = 400;
    QuerySnapshot snap;
    do {
      snap = await _db
          .collection('alumni_registry')
          .where('uploadBatchId', isEqualTo: uploadId)
          .limit(chunkSize)
          .get();
      if (snap.docs.isEmpty) break;
      final wb = _db.batch();
      for (final doc in snap.docs) {
        wb.delete(doc.reference);
      }
      await wb.commit();
    } while (snap.docs.length == chunkSize);
    await _db.collection('registry_uploads').doc(uploadId).delete();
  }

  // ══════════════════════════════════════════════════════
  //  STREAMS
  // ══════════════════════════════════════════════════════

  Stream<List<RegistryUpload>> uploadsStream() {
    return _db
        .collection('registry_uploads')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RegistryUpload.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<AlumniRecord>> recordsStream(String uploadId) {
    return _db
        .collection('alumni_registry')
        .where('uploadBatchId', isEqualTo: uploadId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return list;
    });
  }

  Stream<List<AlumniRecord>> allRecordsStream({String? search}) {
    return _db.collection('alumni_registry').snapshots().map((snap) {
      var records = snap.docs
          .map((d) => AlumniRecord.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        records = records
            .where((r) =>
                r.fullName.toLowerCase().contains(q) ||
                r.studentId.toLowerCase().contains(q) ||
                r.course.toLowerCase().contains(q) ||
                r.batch.toLowerCase().contains(q) ||
                r.email.toLowerCase().contains(q))
            .toList();
      }
      return records;
    });
  }
}