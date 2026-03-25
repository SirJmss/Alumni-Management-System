import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni/features/admin/data/models/alumni_registry_models.dart';

class RegistryService {
  final _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════
  //  CHECK USER AGAINST REGISTRY
  // ══════════════════════════════════════════

  Future<MatchResult> checkUser({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    String studentId = '',
  }) async {
    if (studentId.trim().isNotEmpty) {
      final idResult = await _checkByStudentId(
        studentId: studentId.trim(),
        fullName: fullName,
        batch: batch,
        course: course,
        email: email,
      );
      if (idResult != null) return idResult;
    }

    return _checkByNameAndBatch(
      fullName: fullName,
      batch: batch,
      course: course,
      email: email,
      studentId: studentId,
    );
  }

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
          .limit(5)
          .get();

      if (snap.docs.isEmpty) return null;

      MatchResult? best;
      for (final doc in snap.docs) {
        final record =
            AlumniRecord.fromMap(doc.id, doc.data());
        final confidence = _score(
          record: record,
          inputName: fullName,
          inputBatch: batch,
          inputCourse: course,
          inputEmail: email,
          inputStudentId: studentId,
        );
        if (best == null ||
            confidence > best.confidence) {
          best = MatchResult(
            isMatch: confidence >= 0.65,
            confidence: confidence,
            record: record,
          );
        }
      }
      if (best != null && best.confidence >= 0.65) {
        return best;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

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
        snap = await _db
            .collection('alumni_registry')
            .where('batch', isEqualTo: batch)
            .where('isMatched', isEqualTo: false)
            .get();
      } else {
        snap = await _db
            .collection('alumni_registry')
            .where('isMatched', isEqualTo: false)
            .limit(300)
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

    AlumniRecord? bestRecord;
    double bestScore = 0;

    for (final doc in snap.docs) {
      final record =
          AlumniRecord.fromMap(doc.id, doc.data());
      final confidence = _score(
        record: record,
        inputName: fullName,
        inputBatch: batch,
        inputCourse: course,
        inputEmail: email,
        inputStudentId: studentId,
      );
      if (confidence > bestScore) {
        bestScore = confidence;
        bestRecord = record;
      }
    }

    return MatchResult(
      isMatch: bestScore >= 0.65,
      confidence: bestScore,
      record: bestRecord,
    );
  }

  double _score({
    required AlumniRecord record,
    required String inputName,
    required String inputBatch,
    required String inputCourse,
    required String inputEmail,
    required String inputStudentId,
  }) {
    double score = 0.0;

    final recId = record.studentId.trim().toLowerCase();
    final inId = inputStudentId.trim().toLowerCase();
    if (recId.isNotEmpty && inId.isNotEmpty) {
      if (recId == inId) score += 0.40;
    }

    final nameSim = _nameSimilarity(
      inputName.trim().toLowerCase(),
      record.fullName.trim().toLowerCase(),
    );
    score += nameSim * 0.30;

    final recBatch = record.batch.trim();
    final inBatch = inputBatch.trim();
    if (recBatch.isNotEmpty && inBatch.isNotEmpty) {
      if (recBatch == inBatch) {
        score += 0.20;
      }
    } else if (recBatch.isEmpty && inBatch.isEmpty) {
      score += 0.10;
    }

    final courseSim = _courseSimilarity(
      inputCourse.trim().toLowerCase(),
      record.course.trim().toLowerCase(),
    );
    score += courseSim * 0.10;

    if (record.email.trim().isNotEmpty &&
        inputEmail.trim().isNotEmpty &&
        record.email.trim().toLowerCase() ==
            inputEmail.trim().toLowerCase()) {
      score = (score + 0.05).clamp(0.0, 1.0);
    }

    return score.clamp(0.0, 1.0);
  }

  double _nameSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    a = _normaliseName(a);
    b = _normaliseName(b);

    if (a == b) return 1.0;

    final tokenScore = _tokenOverlap(a, b);
    final levScore = _levenshteinSimilarity(a, b);
    return (tokenScore * 0.65 + levScore * 0.35)
        .clamp(0.0, 1.0);
  }

  String _normaliseName(String s) {
    return s
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _tokenOverlap(String a, String b) {
    final tokensA = a.split(' ').toSet();
    final tokensB = b.split(' ').toSet();
    tokensA.removeWhere((t) => t.length < 2);
    tokensB.removeWhere((t) => t.length < 2);
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
    final intersection =
        tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  double _levenshteinSimilarity(String a, String b) {
    final distance = _levenshtein(a, b);
    final maxLen =
        a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    if (s.length > 60 || t.length > 60) {
      return (s.length - t.length).abs();
    }
    final m = s.length;
    final n = t.length;
    final dp = List.generate(
        m + 1, (i) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (s[i - 1] == t[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((a, b) => a < b ? a : b);
        }
      }
    }
    return dp[m][n];
  }

  double _courseSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    a = _expandCourse(a);
    b = _expandCourse(b);
    if (a == b) return 1.0;
    return _tokenOverlap(a, b);
  }

  String _expandCourse(String s) {
    const map = {
      'bsn': 'bs nursing',
      'bscs': 'bs computer science',
      'bsit': 'bs information technology',
      'bsba': 'bs business administration',
      'bsa': 'bs accountancy',
      'bsed': 'bs education',
      'beed': 'bachelor of elementary education',
      'bsme': 'bs mechanical engineering',
      'bsce': 'bs civil engineering',
      'bsee': 'bs electrical engineering',
      'bsece':
          'bs electronics and communications engineering',
      'bshm': 'bs hospitality management',
      'bstm': 'bs tourism management',
      'bsmt': 'bs medical technology',
      'bspt': 'bs physical therapy',
      'bsphrm': 'bs pharmacy',
      'ab': 'bachelor of arts',
      'bs': 'bachelor of science',
    };
    String result = s.toLowerCase().trim();
    map.forEach((abbr, full) {
      if (result == abbr) result = full;
    });
    return result;
  }

  // ══════════════════════════════════════════
  //  UPLOAD MANAGEMENT
  // ══════════════════════════════════════════

  Future<RegistryUpload> uploadRecords({
    required List<AlumniRecord> records,
    required String fileName,
    required String uploadedByName,
  }) async {
    final batchId =
        _db.collection('registry_uploads').doc().id;

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

    // ─── Write records in chunks of 400 ───
    const chunkSize = 400;
    for (var i = 0; i < records.length; i += chunkSize) {
      final end = (i + chunkSize) > records.length
          ? records.length
          : i + chunkSize;
      final chunk = records.sublist(i, end);
      final writeBatch = _db.batch();

      for (final record in chunk) {
        final docRef =
            _db.collection('alumni_registry').doc();
        writeBatch.set(docRef, {
          'firstName': record.firstName,
          'lastName': record.lastName,
          'fullName': record.fullName,
          'batch': record.batch,
          'course': record.course,
          'email': record.email,
          'studentId': record.studentId,
          'uploadBatchId': batchId,
          'isMatched': false,
          'matchedUserId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await writeBatch.commit();
    }

    // ─── Auto-match existing pending users ───
    int matchedCount = 0;
    try {
      final pendingSnap = await _db
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final userDoc in pendingSnap.docs) {
        final userData = userDoc.data();
        final result = await checkUser(
          fullName: userData['name']?.toString() ?? '',
          batch: userData['batch']?.toString() ?? '',
          course: userData['course']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          studentId:
              userData['studentId']?.toString() ?? '',
        );
        if (result.isMatch && result.record != null) {
          matchedCount++;
          final userBatch = _db.batch();
          userBatch.update(
            _db.collection('users').doc(userDoc.id),
            {
              'verificationStatus': 'verified',
              'status': 'active',
              'verifiedAt':
                  FieldValue.serverTimestamp(),
              'verifiedBy': 'system_auto',
              'registryMatchId': result.record!.id,
              'matchConfidence': result.confidence,
            },
          );
          userBatch.update(
            _db
                .collection('alumni_registry')
                .doc(result.record!.id),
            {
              'isMatched': true,
              'matchedUserId': userDoc.id,
            },
          );
          await userBatch.commit();
        }
      }
    } catch (e) {
    }

    await uploadRef.update({
      'matchedCount': matchedCount,
      'status': 'done',
    });

    return RegistryUpload(
      id: batchId,
      fileName: fileName,
      totalRecords: records.length,
      matchedCount: matchedCount,
      status: 'done',
      uploadedBy: uploadedByName,
      uploadedByName: uploadedByName,
      uploadedAt: DateTime.now(),
    );
  }

  Future<void> deleteUpload(String uploadId) async {
    final snap = await _db
        .collection('alumni_registry')
        .where('uploadBatchId', isEqualTo: uploadId)
        .get();

    const chunkSize = 400;
    for (var i = 0;
        i < snap.docs.length;
        i += chunkSize) {
      final end = (i + chunkSize) > snap.docs.length
          ? snap.docs.length
          : i + chunkSize;
      final chunk = snap.docs.sublist(i, end);
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _db
        .collection('registry_uploads')
        .doc(uploadId)
        .delete();
  }

  // ══════════════════════════════════════════
  //  STREAMS — no orderBy to avoid index issues
  // ══════════════════════════════════════════

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

  Stream<List<AlumniRecord>> recordsStream(
      String uploadId) {
    // ─── No orderBy — avoids needing a composite index ───
    return _db
        .collection('alumni_registry')
        .where('uploadBatchId', isEqualTo: uploadId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) =>
              AlumniRecord.fromMap(doc.id, doc.data()))
          .toList();
      // Sort client-side
      list.sort((a, b) =>
          a.fullName.compareTo(b.fullName));
      return list;
    });
  }

  Stream<List<AlumniRecord>> allRecordsStream(
      {String? search}) {
    // ─── No orderBy on a filtered query ───
    return _db
        .collection('alumni_registry')
        .snapshots()
        .map((snap) {
      final records = snap.docs
          .map((doc) =>
              AlumniRecord.fromMap(doc.id, doc.data()))
          .toList();
      // Sort client-side
      records.sort((a, b) =>
          a.fullName.compareTo(b.fullName));
      if (search == null || search.isEmpty) {
        return records;
      }
      final q = search.toLowerCase();
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