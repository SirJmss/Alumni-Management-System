class AlumniRecord {
  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String batch;
  final String course;
  final String email;
  final String studentId;
  final bool isMatched;
  final String? matchedUserId;
  final String uploadBatchId;
  final DateTime? uploadedAt;

  const AlumniRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.batch,
    required this.course,
    this.email = '',
    this.studentId = '',
    this.isMatched = false,
    this.matchedUserId,
    required this.uploadBatchId,
    this.uploadedAt,
  });

  factory AlumniRecord.fromMap(
      String id, Map<String, dynamic> data) {
    return AlumniRecord(
      id: id,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      batch: data['batch']?.toString() ?? '',
      course: data['course']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      isMatched: data['isMatched'] as bool? ?? false,
      matchedUserId: data['matchedUserId']?.toString(),
      uploadBatchId:
          data['uploadBatchId']?.toString() ?? '',
      uploadedAt:
          (data['uploadedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'batch': batch,
        'course': course,
        'email': email,
        'studentId': studentId,
        'isMatched': isMatched,
        'matchedUserId': matchedUserId,
        'uploadBatchId': uploadBatchId,
        'uploadedAt': uploadedAt,
      };

  AlumniRecord copyWith({
    bool? isMatched,
    String? matchedUserId,
  }) {
    return AlumniRecord(
      id: id,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      batch: batch,
      course: course,
      email: email,
      studentId: studentId,
      isMatched: isMatched ?? this.isMatched,
      matchedUserId:
          matchedUserId ?? this.matchedUserId,
      uploadBatchId: uploadBatchId,
      uploadedAt: uploadedAt,
    );
  }
}

class RegistryUpload {
  final String id;
  final String fileName;
  final int totalRecords;
  final int matchedCount;
  final DateTime? uploadedAt;
  final String uploadedBy;
  final String uploadedByName;
  final String status;

  const RegistryUpload({
    required this.id,
    required this.fileName,
    required this.totalRecords,
    required this.matchedCount,
    this.uploadedAt,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.status,
  });

  factory RegistryUpload.fromMap(
      String id, Map<String, dynamic> data) {
    return RegistryUpload(
      id: id,
      fileName: data['fileName']?.toString() ?? '',
      totalRecords: data['totalRecords'] as int? ?? 0,
      matchedCount: data['matchedCount'] as int? ?? 0,
      uploadedAt:
          (data['uploadedAt'] as dynamic)?.toDate(),
      uploadedBy: data['uploadedBy']?.toString() ?? '',
      uploadedByName:
          data['uploadedByName']?.toString() ?? '',
      status: data['status']?.toString() ?? 'done',
    );
  }
}

class MatchResult {
  final bool isMatch;
  final AlumniRecord? record;
  final double confidence; // 0.0 - 1.0

  const MatchResult({
    required this.isMatch,
    this.record,
    required this.confidence,
  });
}