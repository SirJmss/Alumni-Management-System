// lib/features/admin/data/models/alumni_registry_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════
//  ALUMNI RECORD
// ══════════════════════════════════════════════════════════

class AlumniRecord {
  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String batch;
  final String course;
  final String email;
  final String studentId;
  final String uploadBatchId;
  final bool isMatched;
  final String? matchedUserId;
  final DateTime? createdAt;

  const AlumniRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.batch,
    required this.course,
    required this.email,
    required this.studentId,
    required this.uploadBatchId,
    this.isMatched = false,
    this.matchedUserId,
    this.createdAt,
  });

  // ─── From Firestore DocumentSnapshot ─────────────────
  factory AlumniRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AlumniRecord.fromMap(doc.id, d);
  }

  // ─── From raw map + id ────────────────────────────────
  // This is the primary constructor used by RegistryService.
  // fromDoc() delegates here — both are always in sync.
  factory AlumniRecord.fromMap(String id, Map<String, dynamic> d) {
    final firstName = _s(d['firstName']);
    final lastName  = _s(d['lastName']);
    // fullName may be stored directly, or computed from parts
    final fullName  = _s(d['fullName']).isNotEmpty
        ? _s(d['fullName'])
        : [firstName, lastName]
            .where((s) => s.isNotEmpty)
            .join(' ')
            .trim();

    return AlumniRecord(
      id:            id,
      firstName:     firstName,
      lastName:      lastName,
      fullName:      fullName,
      batch:         _s(d['batch']),
      course:        _s(d['course']),
      email:         _s(d['email']).toLowerCase(),
      studentId:     _s(d['studentId']),
      uploadBatchId: _s(d['uploadBatchId']),
      // Safe bool: field may be absent on old records — default false
      isMatched:     d['isMatched'] == true,
      matchedUserId: d['matchedUserId']?.toString(),
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ─── To Firestore map ────────────────────────────────
  Map<String, dynamic> toMap() => {
    'firstName':     firstName,
    'lastName':      lastName,
    'fullName':      fullName,
    'batch':         batch,
    'course':        course,
    'email':         email.toLowerCase(),
    'studentId':     studentId,
    'uploadBatchId': uploadBatchId,
    'isMatched':     isMatched,
    'matchedUserId': matchedUserId ?? '',
    'createdAt':     createdAt != null
                       ? Timestamp.fromDate(createdAt!)
                       : FieldValue.serverTimestamp(),
  };

  AlumniRecord copyWith({bool? isMatched, String? matchedUserId}) =>
      AlumniRecord(
        id:            id,
        firstName:     firstName,
        lastName:      lastName,
        fullName:      fullName,
        batch:         batch,
        course:        course,
        email:         email,
        studentId:     studentId,
        uploadBatchId: uploadBatchId,
        isMatched:     isMatched     ?? this.isMatched,
        matchedUserId: matchedUserId ?? this.matchedUserId,
        createdAt:     createdAt,
      );

  static String _s(dynamic v) => v?.toString().trim() ?? '';
}

// ══════════════════════════════════════════════════════════
//  REGISTRY UPLOAD
// ══════════════════════════════════════════════════════════

class RegistryUpload {
  final String   id;
  final String   fileName;
  final int      totalRecords;
  final int      matchedCount;
  final String   status;
  final String   uploadedByName;
  // Keep 'uploadedBy' alias so old callers don't break
  String get uploadedBy => uploadedByName;
  final DateTime? uploadedAt;

  const RegistryUpload({
    required this.id,
    required this.fileName,
    required this.totalRecords,
    required this.matchedCount,
    required this.status,
    required this.uploadedByName,
    this.uploadedAt,
  });

  factory RegistryUpload.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RegistryUpload.fromMap(doc.id, d);
  }

  factory RegistryUpload.fromMap(String id, Map<String, dynamic> d) {
    return RegistryUpload(
      id:             id,
      fileName:       _s(d['fileName']),
      totalRecords:   _i(d['totalRecords']),
      matchedCount:   _i(d['matchedCount']),
      status:         _s(d['status'], 'completed'),
      uploadedByName: _s(d['uploadedByName'],
          _s(d['uploadedBy'])),
      uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }

  static String _s(dynamic v, [String fb = '']) =>
      v?.toString().trim().isNotEmpty == true
          ? v.toString().trim()
          : fb;
  static int _i(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
}

// ══════════════════════════════════════════════════════════
//  MATCH RESULT
// ══════════════════════════════════════════════════════════

class MatchResult {
  final bool isMatch;
  final double confidence;
  final AlumniRecord? record;
  final Map<String, double> scoreBreakdown;

  const MatchResult({
    required this.isMatch,
    required this.confidence,
    this.record,
    this.scoreBreakdown = const {},
  });

  static const MatchResult noMatch =
      MatchResult(isMatch: false, confidence: 0);
}