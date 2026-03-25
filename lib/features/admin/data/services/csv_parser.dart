import 'package:csv/csv.dart';
import '../models/alumni_registry_models.dart';

class CsvParser {
  /// Parses CSV bytes into a list of AlumniRecords.
  /// Expected columns (case-insensitive):
  /// firstName/first_name, lastName/last_name,
  /// batch/batchYear, course/program,
  /// email (optional), studentId (optional)
  static List<AlumniRecord> parse(
      String csvContent, String uploadBatchId) {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent);

    if (rows.isEmpty) return [];

    // ─── Detect headers ───
    final headers = rows.first
        .map((h) => h.toString().trim().toLowerCase())
        .toList();

    int col(List<String> candidates) {
      for (final c in candidates) {
        final idx = headers.indexOf(c);
        if (idx != -1) return idx;
      }
      return -1;
    }

    final firstNameIdx =
        col(['firstname', 'first_name', 'first name']);
    final lastNameIdx =
        col(['lastname', 'last_name', 'last name']);
    final fullNameIdx =
        col(['fullname', 'full_name', 'full name', 'name']);
    final batchIdx = col([
      'batch',
      'batchyear',
      'batch_year',
      'year',
      'graduation_year'
    ]);
    final courseIdx =
        col(['course', 'program', 'degree', 'major']);
    final emailIdx = col(['email', 'email_address']);
    final studentIdIdx =
        col(['studentid', 'student_id', 'id', 'school_id']);

    final records = <AlumniRecord>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) =>
          cell.toString().trim().isEmpty)) continue;

      String get(int idx) =>
          idx != -1 && idx < row.length
              ? row[idx].toString().trim()
              : '';

      final firstName = firstNameIdx != -1
          ? get(firstNameIdx)
          : '';
      final lastName = lastNameIdx != -1
          ? get(lastNameIdx)
          : '';
      String fullName = fullNameIdx != -1
          ? get(fullNameIdx)
          : '';

      if (fullName.isEmpty &&
          (firstName.isNotEmpty || lastName.isNotEmpty)) {
        fullName = '$firstName $lastName'.trim();
      }

      if (fullName.isEmpty) continue;

      records.add(AlumniRecord(
        id: '',
        firstName: firstName.isNotEmpty
            ? firstName
            : fullName.split(' ').first,
        lastName: lastName.isNotEmpty
            ? lastName
            : fullName.split(' ').length > 1
                ? fullName.split(' ').last
                : '',
        fullName: fullName,
        batch: get(batchIdx),
        course: get(courseIdx),
        email: get(emailIdx),
        studentId: get(studentIdIdx),
        uploadBatchId: uploadBatchId,
      ));
    }

    return records;
  }
}