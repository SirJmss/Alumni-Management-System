import 'package:excel/excel.dart';
import '../models/alumni_registry_models.dart';

class ExcelParser {
  static List<AlumniRecord> parse(
      List<int> bytes, String uploadBatchId) {
    final excel = Excel.decodeBytes(bytes);
    final records = <AlumniRecord>[];

    // ─── Use first sheet ───
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) return [];

    // ─── Detect headers from row 0 ───
    final headers = sheet.rows.first
        .map((cell) =>
            cell?.value?.toString().trim().toLowerCase() ??
            '')
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

    String get(List<Data?> row, int idx) =>
        idx != -1 && idx < row.length
            ? row[idx]?.value?.toString().trim() ?? ''
            : '';

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) =>
          cell?.value?.toString().trim().isEmpty ??
          true)) {
        continue;
      }

      final firstName = get(row, firstNameIdx);
      final lastName = get(row, lastNameIdx);
      String fullName = get(row, fullNameIdx);

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
        batch: get(row, batchIdx),
        course: get(row, courseIdx),
        email: get(row, emailIdx),
        studentId: get(row, studentIdIdx),
        uploadBatchId: uploadBatchId,
      ));
    }

    return records;
  }
}