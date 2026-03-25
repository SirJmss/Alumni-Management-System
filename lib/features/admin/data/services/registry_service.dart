import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alumni_registry_models.dart';
import 'registry_matcher.dart';

class RegistryService {
  final _fs = FirebaseFirestore.instance;

  // ─── Upload a batch of records ───
  Future<RegistryUpload> uploadRecords({
    required List<AlumniRecord> records,
    required String fileName,
    required String uploadedByName,
  }) async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final uploadId =
        _fs.collection('registry_uploads').doc().id;
    final now = FieldValue.serverTimestamp();

    // ─── Save upload metadata ───
    await _fs
        .collection('registry_uploads')
        .doc(uploadId)
        .set({
      'fileName': fileName,
      'totalRecords': records.length,
      'matchedCount': 0,
      'uploadedAt': now,
      'uploadedBy': uid,
      'uploadedByName': uploadedByName,
      'status': 'processing',
    });

    // ─── Batch write records (500 limit per batch) ───
    int saved = 0;
    const batchSize = 400;

    for (int i = 0; i < records.length; i += batchSize) {
      final chunk = records.sublist(
          i,
          i + batchSize > records.length
              ? records.length
              : i + batchSize);

      final batch = _fs.batch();
      for (final record in chunk) {
        final ref =
            _fs.collection('alumni_registry').doc();
        batch.set(ref, {
          ...record.toMap(),
          'uploadBatchId': uploadId,
          'uploadedAt': now,
          'isMatched': false,
          'matchedUserId': null,
        });
      }
      await batch.commit();
      saved += chunk.length;
    }

    // ─── Run auto-match against existing users ───
    final matchCount =
        await _autoMatchExistingUsers(uploadId);

    // ─── Update upload status ───
    await _fs
        .collection('registry_uploads')
        .doc(uploadId)
        .update({
      'status': 'done',
      'matchedCount': matchCount,
      'totalRecords': saved,
    });

    return RegistryUpload(
      id: uploadId,
      fileName: fileName,
      totalRecords: saved,
      matchedCount: matchCount,
      uploadedBy: uid,
      uploadedByName: uploadedByName,
      status: 'done',
    );
  }

  // ─── Auto-match existing pending users ───
  Future<int> _autoMatchExistingUsers(
      String uploadBatchId) async {
    int matchCount = 0;

    final registrySnap = await _fs
        .collection('alumni_registry')
        .where('uploadBatchId',
            isEqualTo: uploadBatchId)
        .get();

    final registry = registrySnap.docs
        .map((d) =>
            AlumniRecord.fromMap(d.id, d.data()))
        .toList();

    final usersSnap = await _fs
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .get();

    for (final userDoc in usersSnap.docs) {
      final data = userDoc.data();
      final result = RegistryMatcher.findMatch(
        fullName: data['name']?.toString() ??
            data['fullName']?.toString() ??
            '',
        batch: data['batch']?.toString() ??
            data['batchYear']?.toString() ??
            '',
        course: data['course']?.toString() ??
            data['program']?.toString() ??
            '',
        email: data['email']?.toString() ?? '',
        registry: registry,
      );

      if (result.isMatch && result.record != null) {
        // ─── Auto-verify user ───
        await _fs
            .collection('users')
            .doc(userDoc.id)
            .update({
          'status': 'active',
          'verificationStatus': 'verified',
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': 'system_auto',
          'registryMatchId': result.record!.id,
          'matchConfidence': result.confidence,
        });

        // ─── Mark registry record as matched ───
        await _fs
            .collection('alumni_registry')
            .doc(result.record!.id)
            .update({
          'isMatched': true,
          'matchedUserId': userDoc.id,
        });

        matchCount++;
      }
    }

    return matchCount;
  }

  // ─── Check single user against registry ───
  Future<MatchResult> checkUser({
    required String fullName,
    required String batch,
    required String course,
    required String email,
  }) async {
    final snap = await _fs
        .collection('alumni_registry')
        .get();

    final registry = snap.docs
        .map((d) =>
            AlumniRecord.fromMap(d.id, d.data()))
        .where((r) => !r.isMatched)
        .toList();

    return RegistryMatcher.findMatch(
      fullName: fullName,
      batch: batch,
      course: course,
      email: email,
      registry: registry,
    );
  }

  // ─── Get all uploads ───
  Stream<List<RegistryUpload>> uploadsStream() {
    return _fs
        .collection('registry_uploads')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                RegistryUpload.fromMap(d.id, d.data()))
            .toList());
  }

  // ─── Get registry records for an upload ───
  Stream<List<AlumniRecord>> recordsStream(
      String uploadBatchId) {
    return _fs
        .collection('alumni_registry')
        .where('uploadBatchId',
            isEqualTo: uploadBatchId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                AlumniRecord.fromMap(d.id, d.data()))
            .toList());
  }

  // ─── Delete an upload batch ───
  Future<void> deleteUpload(String uploadId) async {
    final records = await _fs
        .collection('alumni_registry')
        .where('uploadBatchId', isEqualTo: uploadId)
        .get();

    final batch = _fs.batch();
    for (final doc in records.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_fs
        .collection('registry_uploads')
        .doc(uploadId));
    await batch.commit();
  }

  // ─── Get all registry records ───
  Stream<List<AlumniRecord>> allRecordsStream(
      {String? search}) {
    return _fs
        .collection('alumni_registry')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) {
      final all = snap.docs
          .map((d) =>
              AlumniRecord.fromMap(d.id, d.data()))
          .toList();
      if (search == null || search.isEmpty) return all;
      final q = search.toLowerCase();
      return all
          .where((r) =>
              r.fullName.toLowerCase().contains(q) ||
              r.batch.contains(q) ||
              r.course.toLowerCase().contains(q) ||
              r.email.toLowerCase().contains(q))
          .toList();
    });
  }
}