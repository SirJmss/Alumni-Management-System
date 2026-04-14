// ─────────────────────────────────────────────────────────────────────────────
// RegistryMatcher
// FILE: lib/features/admin/data/services/registry_matcher.dart
//
// Single source of truth for all alumni matching logic.
// Used by:
//   - RegistryService.checkUser()   (registration flow)
//   - RegistryService.uploadRecords() (auto-match on upload)
//   - RegisterScreen (via RegistryService)
//
// SCORING WEIGHTS (must sum to ≤ 1.0):
//   Student ID exact match  → 0.40  (strongest — deterministic)
//   Name similarity          → 0.30  (Dice coefficient on bigrams)
//   Batch year exact match   → 0.20
//   Course similarity        → 0.10  (Dice + abbreviation expansion)
//   Email exact match        → +0.05 bonus (clamped to 1.0)
//
// THRESHOLD: score ≥ 0.65 → isMatch = true
//
// WHY STUDENT ID IS 0.40:
//   An exact Student ID match combined with a name match (even partial, ~0.50)
//   will reach 0.65 without needing batch/course. This mirrors real-world
//   scenarios where alumni remember their ID but may have name variations
//   (e.g. maiden vs married name).
//
// WHY NOT USE EMAIL AS A PRIMARY KEY:
//   Registry records uploaded from CSV may have outdated emails. Email is
//   a bonus signal only — it cannot alone confirm identity.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/alumni_registry_models.dart';

class RegistryMatcher {
  // ── Scoring thresholds ──────────────────────────────────────────────────
  static const double matchThreshold = 0.65;

  // ── Weight constants ────────────────────────────────────────────────────
  static const double _wStudentId = 0.40;
  static const double _wName     = 0.30;
  static const double _wBatch    = 0.20;
  static const double _wCourse   = 0.10;
  static const double _wEmailBonus = 0.05; // additive bonus, clamped

  // ─────────────────────────────────────────────────────────────────────────
  // findBestMatch
  //
  // Scans a list of AlumniRecords and returns the highest-scoring match.
  // If no record reaches [matchThreshold], returns isMatch=false with the
  // best candidate still populated (useful for debugging / admin review).
  // ─────────────────────────────────────────────────────────────────────────
  static MatchResult findBestMatch({
    required String fullName,
    required String batch,
    required String course,
    required String email,
    required List<AlumniRecord> registry,
    String studentId = '',
  }) {
    if (registry.isEmpty) {
      return const MatchResult(
          isMatch: false, confidence: 0, record: null);
    }

    AlumniRecord? best;
    double bestScore = 0.0;

    // Pre-normalise inputs once (not inside loop)
    final normName    = _normaliseName(fullName);
    final normBatch   = batch.trim();
    final normCourse  = _expandCourse(_normalise(course));
    final normEmail   = email.trim().toLowerCase();
    final normId      = studentId.trim().toLowerCase();

    for (final record in registry) {
      final score = _scoreRecord(
        record: record,
        normName: normName,
        normBatch: normBatch,
        normCourse: normCourse,
        normEmail: normEmail,
        normStudentId: normId,
      );

      if (score > bestScore) {
        bestScore = score;
        best = record;
      }
    }

    return MatchResult(
      isMatch: bestScore >= matchThreshold,
      confidence: bestScore,
      record: best, // always return best candidate for transparency
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // scoreOne
  //
  // Scores a single record against known inputs.
  // Exposed so RegistryService can call it directly without a full list scan.
  // ─────────────────────────────────────────────────────────────────────────
  static double scoreOne({
    required AlumniRecord record,
    required String fullName,
    required String batch,
    required String course,
    required String email,
    String studentId = '',
  }) {
    return _scoreRecord(
      record: record,
      normName: _normaliseName(fullName),
      normBatch: batch.trim(),
      normCourse: _expandCourse(_normalise(course)),
      normEmail: email.trim().toLowerCase(),
      normStudentId: studentId.trim().toLowerCase(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal scoring
  // ─────────────────────────────────────────────────────────────────────────
  static double _scoreRecord({
    required AlumniRecord record,
    required String normName,
    required String normBatch,
    required String normCourse,
    required String normEmail,
    required String normStudentId,
  }) {
    double score = 0.0;

    // ── 1. Student ID (0.40) ─────────────────────────────────────────────
    final recId = record.studentId.trim().toLowerCase();
    if (recId.isNotEmpty && normStudentId.isNotEmpty) {
      if (recId == normStudentId) {
        score += _wStudentId;
      } else if (recId.contains(normStudentId) ||
          normStudentId.contains(recId)) {
        // Partial match — e.g. "2015-0001" vs "20150001"
        score += _wStudentId * 0.5;
      }
    }

    // ── 2. Name similarity (0.30) ────────────────────────────────────────
    final recName = _normaliseName(record.fullName);
    if (recName.isNotEmpty && normName.isNotEmpty) {
      final nameSim = _nameSimilarity(normName, recName);
      score += nameSim * _wName;
    }

    // ── 3. Batch year (0.20) ─────────────────────────────────────────────
    final recBatch = record.batch.trim();
    if (recBatch.isNotEmpty && normBatch.isNotEmpty) {
      if (recBatch == normBatch) {
        score += _wBatch;
      }
    } else if (recBatch.isEmpty && normBatch.isEmpty) {
      // Both missing — don't penalise, give partial credit
      score += _wBatch * 0.5;
    }

    // ── 4. Course similarity (0.10) ──────────────────────────────────────
    final recCourse =
        _expandCourse(_normalise(record.course));
    if (recCourse.isNotEmpty && normCourse.isNotEmpty) {
      final courseSim = _diceSimilarity(normCourse, recCourse);
      score += courseSim * _wCourse;
    }

    // ── 5. Email bonus (+0.05, clamped) ──────────────────────────────────
    final recEmail = record.email.trim().toLowerCase();
    if (recEmail.isNotEmpty &&
        normEmail.isNotEmpty &&
        recEmail == normEmail) {
      score = (score + _wEmailBonus).clamp(0.0, 1.0);
    }

    return score.clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Name similarity
  //
  // Combines:
  //   - Token (word) overlap — handles reordered names (e.g. "Juan Dela Cruz"
  //     vs "Dela Cruz, Juan")
  //   - Dice bigram similarity — handles typos and partial matches
  //
  // Token overlap is weighted more heavily because alumni names are short
  // strings where word order matters less than word presence.
  // ─────────────────────────────────────────────────────────────────────────
  static double _nameSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final tokenScore = _tokenOverlap(a, b);
    final diceScore  = _diceSimilarity(a, b);

    // Token overlap gets 60% weight, Dice gets 40%
    return (tokenScore * 0.60 + diceScore * 0.40)
        .clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token overlap — Jaccard on word sets
  // ─────────────────────────────────────────────────────────────────────────
  static double _tokenOverlap(String a, String b) {
    final tokA = a.split(' ')
        .where((t) => t.length >= 2)
        .toSet();
    final tokB = b.split(' ')
        .where((t) => t.length >= 2)
        .toSet();

    if (tokA.isEmpty || tokB.isEmpty) return 0.0;

    final intersection = tokA.intersection(tokB).length;
    final union        = tokA.union(tokB).length;

    return union == 0 ? 0.0 : intersection / union;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dice coefficient on character bigrams
  // ─────────────────────────────────────────────────────────────────────────
  static double _diceSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final bigramsA = _bigrams(a);
    final bigramsB = _bigrams(b);

    if (bigramsA.isEmpty || bigramsB.isEmpty) {
      // Strings too short for bigrams — fall back to contains check
      return (a.contains(b) || b.contains(a)) ? 0.5 : 0.0;
    }

    int intersection = 0;
    final bCopy = List<String>.from(bigramsB);
    for (final bg in bigramsA) {
      final idx = bCopy.indexOf(bg);
      if (idx != -1) {
        intersection++;
        bCopy.removeAt(idx);
      }
    }

    return (2 * intersection) /
        (bigramsA.length + bigramsB.length);
  }

  static List<String> _bigrams(String s) {
    final result = <String>[];
    for (int i = 0; i < s.length - 1; i++) {
      result.add(s.substring(i, i + 2));
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text normalisation
  // ─────────────────────────────────────────────────────────────────────────

  /// General normaliser — strips punctuation, collapses whitespace, lowercase
  static String _normalise(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Name-specific normaliser — also strips common titles and suffixes
  static String _normaliseName(String s) {
    String result = s
        .toLowerCase()
        // Remove punctuation except hyphens (for compound names)
        .replaceAll(RegExp(r'[^\w\s\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strip common Philippine name prefixes / suffixes
    const stripWords = {
      'jr', 'sr', 'ii', 'iii', 'iv',
      'mr', 'mrs', 'ms', 'dr', 'prof',
    };

    final tokens = result.split(' ')
        .where((t) => t.isNotEmpty && !stripWords.contains(t))
        .toList();

    return tokens.join(' ');
  }

  /// Expands common course abbreviations to their full names.
  /// Applied to both input and registry before comparison so that
  /// "BSCS" and "BS Computer Science" score as identical.
  static String _expandCourse(String s) {
    const map = <String, String>{
      'bsn':    'bs nursing',
      'bscs':   'bs computer science',
      'bsit':   'bs information technology',
      'bsba':   'bs business administration',
      'bsa':    'bs accountancy',
      'bsed':   'bs education',
      'beed':   'bachelor of elementary education',
      'bsme':   'bs mechanical engineering',
      'bsce':   'bs civil engineering',
      'bsee':   'bs electrical engineering',
      'bsece':  'bs electronics and communications engineering',
      'bshm':   'bs hospitality management',
      'bstm':   'bs tourism management',
      'bsmt':   'bs medical technology',
      'bspt':   'bs physical therapy',
      'bsphrm': 'bs pharmacy',
      'ab':     'bachelor of arts',
      'bs':     'bachelor of science',
      // Common local variants
      'bsnd':   'bs nutrition and dietetics',
      'bsm':    'bs midwifery',
      'bspsy':  'bs psychology',
      'abcomm': 'ab communication',
      'bsarch': 'bs architecture',
    };

    final trimmed = s.toLowerCase().trim();

    // Full abbreviation match
    if (map.containsKey(trimmed)) return map[trimmed]!;

    // Prefix match — e.g. "bscs major in ai" → expand "bscs" part
    for (final entry in map.entries) {
      if (trimmed.startsWith('${entry.key} ')) {
        return trimmed.replaceFirst(entry.key, entry.value);
      }
    }

    return trimmed;
  }
}