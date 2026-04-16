// ─────────────────────────────────────────────────────────────────────────────
// JobScorer
// FILE: lib/features/jobs/data/job_scorer.dart
//
// Single source of truth for relevance scoring.
// Used by DashboardScreen and JobOpportunitiesScreen so both rank
// jobs identically.
//
// SCORE BREAKDOWN (higher = more relevant):
//   requiredCourse exact/contains match  → +60
//   course keyword in title              → +25 each
//   course keyword in category           → +20 each
//   course keyword in description        → +10 each
//   occupation keyword in title          → +30 each
//   occupation keyword in category       → +15 each
//   occupation keyword in description    → +8  each
//   company keyword match                → +10 each
//   broad category synonym in title      → +15 each
//   broad category synonym in description→ +5  each
// ─────────────────────────────────────────────────────────────────────────────

class JobScorer {
  // ── Stop words removed before keyword extraction ─────────────────────────
  static const _stopWords = {
    'of', 'in', 'the', 'a', 'an', 'and', 'or', 'for',
    'to', 'at', 'by', 'with', 'bs', 'ab', 'bachelor',
    'science', 'arts', 'degree',
  };

  // ── Course → synonym map for broad category matching ─────────────────────
  static const Map<String, List<String>> _broadMap = {
    'nursing':                ['nurse', 'health', 'medical', 'hospital', 'clinical', 'care'],
    'computer science':       ['software', 'developer', 'engineer', 'tech', 'it', 'coding', 'programmer', 'data'],
    'information technology': ['it', 'tech', 'support', 'network', 'system', 'software', 'developer'],
    'business administration':['business', 'management', 'admin', 'operations', 'executive', 'analyst'],
    'accountancy':            ['accounting', 'finance', 'audit', 'tax', 'bookkeeping', 'financial'],
    'education':              ['teacher', 'tutor', 'instructor', 'academic', 'training', 'educator'],
    'engineering':            ['engineer', 'technical', 'construction', 'design', 'manufacturing'],
    'hospitality management': ['hotel', 'hospitality', 'restaurant', 'tourism', 'food', 'events'],
    'tourism management':     ['travel', 'tourism', 'tour', 'hospitality', 'airline'],
    'medical technology':     ['lab', 'laboratory', 'medical', 'diagnostic', 'pathology'],
    'pharmacy':               ['pharma', 'drug', 'medicine', 'dispensary', 'clinical'],
    'marketing':              ['marketing', 'brand', 'sales', 'advertising', 'digital', 'social media', 'campaigns', 'seo', 'content'],
    'psychology':             ['counseling', 'therapy', 'mental health', 'hr', 'human resources', 'behavioral'],
    'architecture':           ['architect', 'design', 'drafting', 'cad', 'construction', 'urban'],
    'midwifery':              ['midwife', 'maternal', 'obstetric', 'delivery', 'nursing', 'health'],
    'nutrition dietetics':    ['nutrition', 'dietitian', 'food', 'health', 'wellness', 'clinical'],
  };

  /// Extract meaningful keywords from a user profile field.
  static List<String> extractKeywords(String text) {
    if (text.isEmpty) return [];
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();
  }

  /// Score a single job document against a user's profile.
  /// [jobData] is the raw Firestore map.
  /// Returns an integer score ≥ 0. Higher = more relevant.
  static int scoreJob({
    required Map<String, dynamic> jobData,
    required String userCourse,
    required String userOccupation,
    required String userCompany,
  }) {
    final jobTitle     = (jobData['title']        ?? '').toString().toLowerCase();
    final jobDesc      = (jobData['description']  ?? '').toString().toLowerCase();
    final jobCategory  = (jobData['category']     ?? '').toString().toLowerCase();
    final jobReqCourse = (jobData['requiredCourse']?? '').toString().toLowerCase();
    final jobCompany   = (jobData['company']      ?? '').toString().toLowerCase();

    final course     = userCourse.toLowerCase().trim();
    final occupation = userOccupation.toLowerCase().trim();
    final company    = userCompany.toLowerCase().trim();

    final courseKws     = extractKeywords(course);
    final occupationKws = extractKeywords(occupation);
    final companyKws    = extractKeywords(company);

    int score = 0;

    // ── requiredCourse exact / contains ──────────────────────────────────
    if (jobReqCourse.isNotEmpty && course.isNotEmpty) {
      if (jobReqCourse.contains(course) || course.contains(jobReqCourse)) {
        score += 60;
      }
    }

    // ── Course keywords ───────────────────────────────────────────────────
    for (final kw in courseKws) {
      if (kw.length < 3) continue;
      if (jobTitle.contains(kw))    score += 25;
      if (jobCategory.contains(kw)) score += 20;
      if (jobDesc.contains(kw))     score += 10;
    }

    // ── Occupation keywords ───────────────────────────────────────────────
    for (final kw in occupationKws) {
      if (kw.length < 3) continue;
      if (jobTitle.contains(kw))    score += 30;
      if (jobCategory.contains(kw)) score += 15;
      if (jobDesc.contains(kw))     score +=  8;
    }

    // ── Company keywords ──────────────────────────────────────────────────
    for (final kw in companyKws) {
      if (kw.length < 3) continue;
      if (jobCompany.contains(kw))  score += 10;
    }

    // ── Broad category synonyms ───────────────────────────────────────────
    for (final entry in _broadMap.entries) {
      if (course.contains(entry.key) || entry.key.contains(course)) {
        for (final syn in entry.value) {
          if (jobTitle.contains(syn)) score += 15;
          if (jobDesc.contains(syn))  score +=  5;
        }
      }
    }

    return score;
  }

  /// Score and sort a list of raw job maps.
  /// Adds 'score' and 'isRelevant' keys to each map.
  /// Returns the sorted list (highest score first).
  static List<Map<String, dynamic>> scoreAndSort({
    required List<Map<String, dynamic>> jobs,
    required String userCourse,
    required String userOccupation,
    required String userCompany,
  }) {
    for (final job in jobs) {
      final s = scoreJob(
        jobData:        job,
        userCourse:     userCourse,
        userOccupation: userOccupation,
        userCompany:    userCompany,
      );
      job['score']      = s;
      job['isRelevant'] = s > 0;
    }

    jobs.sort((a, b) =>
        (b['score'] as int).compareTo(a['score'] as int));

    return jobs;
  }

  /// Human-readable label for a relevance score.
  static String relevanceLabel(int score) {
    if (score >= 60) return 'Matches your course';
    if (score >= 30) return 'Matches your experience';
    if (score > 0)   return 'Recommended for you';
    return '';
  }
}