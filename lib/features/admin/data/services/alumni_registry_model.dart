// lib/features/admin/data/models/alumni_registry_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════
//  ALUMNI RECORD
//  One row from a CSV/Excel upload — represents a single
//  verified graduate from the school's official records.
// ══════════════════════════════════════════════════════════

class AlumniRecord {
  final String id;           // Firestore doc ID
  final String firstName;
  final String lastName;
  final String fullName;     // computed: "$firstName $lastName"
  final String batch;        // e.g. "2019" or "2019-2020"
  final String course;       // e.g. "BS Computer Science"
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

  // ─── From Firestore doc ──────────────────────────────
  factory AlumniRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final firstName = _s(d['firstName']);
    final lastName  = _s(d['lastName']);
    // Support both stored fullName or computed from parts
    final fullName = _s(d['fullName']).isNotEmpty
        ? _s(d['fullName'])
        : '$firstName $lastName'.trim();

    return AlumniRecord(
      id:            doc.id,
      firstName:     firstName,
      lastName:      lastName,
      fullName:      fullName,
      batch:         _s(d['batch']),
      course:        _s(d['course']),
      email:         _s(d['email']).toLowerCase(),
      studentId:     _s(d['studentId']),
      uploadBatchId: _s(d['uploadBatchId']),
      isMatched:     d['isMatched'] as bool? ?? false,
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
    'matchedUserId': matchedUserId,
    'createdAt':     createdAt != null
                       ? Timestamp.fromDate(createdAt!)
                       : FieldValue.serverTimestamp(),
  };

  // ─── Copy with overrides ─────────────────────────────
  AlumniRecord copyWith({
    bool?   isMatched,
    String? matchedUserId,
  }) => AlumniRecord(
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

  static String _s(dynamic v) =>
      v?.toString().trim() ?? '';
}

// ══════════════════════════════════════════════════════════
//  REGISTRY UPLOAD
//  Metadata for one CSV/Excel upload batch.
// ══════════════════════════════════════════════════════════

class RegistryUpload {
  final String   id;
  final String   fileName;
  final int      totalRecords;
  final int      matchedCount;
  final String   status;       // 'completed' | 'processing' | 'error'
  final String   uploadedByName;
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
    return RegistryUpload(
      id:             doc.id,
      fileName:       _s(d['fileName']),
      totalRecords:   _i(d['totalRecords']),
      matchedCount:   _i(d['matchedCount']),
      status:         _s(d['status'], 'completed'),
      uploadedByName: _s(d['uploadedByName']),
      uploadedAt:     (d['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }

  static String _s(dynamic v, [String fb = '']) =>
      v?.toString().trim().isNotEmpty == true ? v.toString().trim() : fb;
  static int _i(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
}

// ══════════════════════════════════════════════════════════
//  MATCH RESULT
//  Returned by RegistryService.checkUser() — tells the
//  register screen whether the signing-up user is found in
//  the official alumni registry and how confident that is.
// ══════════════════════════════════════════════════════════

class MatchResult {
  /// Whether ANY match was found above the threshold
  final bool isMatch;

  /// 0.0 – 1.0
  final double confidence;

  /// The matching registry record (null if no match)
  final AlumniRecord? record;

  /// Human-readable breakdown for debugging / UI
  final Map<String, double> scoreBreakdown;

  const MatchResult({
    required this.isMatch,
    required this.confidence,
    this.record,
    this.scoreBreakdown = const {},
  });

  /// Convenience: whether this qualifies for strict auto-verification
  bool get meetsStrictCriteria {
    if (record == null) return false;
    return record!.studentId.isNotEmpty &&
           record!.batch.isNotEmpty &&
           record!.course.isNotEmpty;
  }

  static const MatchResult noMatch = MatchResult(
    isMatch:    false,
    confidence: 0,
  );
}