import '../models/alumni_registry_models.dart';

class RegistryMatcher {
  /// Compares a registering user against the registry.
  /// Returns the best match with a confidence score.
  static MatchResult findMatch({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    required List<AlumniRecord> registry,
  }) {
    AlumniRecord? best;
    double bestScore = 0.0;

    final normalizedName =
        _normalize(fullName);
    final normalizedBatch = batch.trim();
    final normalizedCourse =
        _normalize(course);
    final normalizedEmail =
        email.trim().toLowerCase();

    for (final record in registry) {
      double score = 0.0;

      // ─── Email match (strongest signal) ───
      if (normalizedEmail.isNotEmpty &&
          record.email.isNotEmpty &&
          normalizedEmail ==
              record.email.toLowerCase()) {
        score += 0.5;
      }

      // ─── Student ID match ───
      // (can be added when user provides student ID)

      // ─── Name similarity ───
      final nameSim = _similarity(
          normalizedName,
          _normalize(record.fullName));
      score += nameSim * 0.3;

      // ─── Batch match ───
      if (normalizedBatch.isNotEmpty &&
          record.batch.isNotEmpty &&
          normalizedBatch == record.batch) {
        score += 0.1;
      }

      // ─── Course similarity ───
      if (normalizedCourse.isNotEmpty &&
          record.course.isNotEmpty) {
        final courseSim = _similarity(
            normalizedCourse,
            _normalize(record.course));
        score += courseSim * 0.1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = record;
      }
    }

    // ─── Threshold: 0.65 = match ───
    return MatchResult(
      isMatch: bestScore >= 0.65,
      record: bestScore >= 0.65 ? best : null,
      confidence: bestScore,
    );
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Dice coefficient string similarity (0.0–1.0)
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final aSet = _bigrams(a);
    final bSet = _bigrams(b);

    if (aSet.isEmpty || bSet.isEmpty) {
      return a.contains(b) || b.contains(a)
          ? 0.5
          : 0.0;
    }

    int intersection = 0;
    final bCopy = List<String>.from(bSet);
    for (final bigram in aSet) {
      final idx = bCopy.indexOf(bigram);
      if (idx != -1) {
        intersection++;
        bCopy.removeAt(idx);
      }
    }

    return (2 * intersection) /
        (aSet.length + bSet.length);
  }

  static List<String> _bigrams(String s) {
    final result = <String>[];
    for (int i = 0; i < s.length - 1; i++) {
      result.add(s.substring(i, i + 2));
    }
    return result;
  }
}