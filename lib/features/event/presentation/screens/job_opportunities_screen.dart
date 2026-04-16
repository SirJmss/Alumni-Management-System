// FILE: lib/features/jobs/presentation/screens/job_opportunities_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/presentation/screens/job_scorer.dart';
// ─────────────────────────────────────────────────────────────────────────────
// JobOpportunitiesScreen
//
// Accepts optional profile params from DashboardScreen so scoring is instant
// (no second Firestore read). Falls back to loading its own profile if opened
// directly (e.g. from drawer or deep-link).
//
// DATA SOURCE: job_posting collection, status == 'approved'
// SCORING:     JobScorer (shared with DashboardScreen)
// ORDER:       course-aligned first → occupation-aligned → generic
// ─────────────────────────────────────────────────────────────────────────────
class JobOpportunitiesScreen extends StatefulWidget {
  final String userCourse;
  final String userOccupation;
  final String userCompany;

  const JobOpportunitiesScreen({
    super.key,
    this.userCourse    = '',
    this.userOccupation = '',
    this.userCompany   = '',
  });

  @override
  State<JobOpportunitiesScreen> createState() =>
      _JobOpportunitiesScreenState();
}

class _JobOpportunitiesScreenState
    extends State<JobOpportunitiesScreen> {
  // ── Profile ──────────────────────────────────────────────────────────────
  late String _userCourse;
  late String _userOccupation;
  late String _userCompany;
  bool _profileLoaded = false;

  // ── Jobs data ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allJobs  = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _isLoading       = true;
  String _searchQuery     = '';
  String? _typeFilter;
  bool   _showRelevantOnly = false;
  String? _loadError;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use profile data passed from dashboard if available
    _userCourse     = widget.userCourse;
    _userOccupation = widget.userOccupation;
    _userCompany    = widget.userCompany;
    _profileLoaded  = widget.userCourse.isNotEmpty;

    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Load profile (only if not passed from dashboard) ───────────────────
  Future<void> _loadProfileIfNeeded() async {
    if (_profileLoaded) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? {};
      String g(String k) => data[k]?.toString().trim() ?? '';
      setState(() {
        _userCourse     = g('course').isNotEmpty ? g('course') : g('program');
        _userOccupation = g('occupation');
        _userCompany    = g('company');
        _profileLoaded  = true;
      });
    } catch (e) {
      debugPrint('JobOpps: profile load error: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading  = true;
      _loadError  = null;
    });

    await _loadProfileIfNeeded();
    await _fetchAndScoreJobs();
  }

  // ─── Fetch approved jobs and score them ──────────────────────────────────
  Future<void> _fetchAndScoreJobs() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('job_posting')
          .where('status', isEqualTo: 'approved')
          .orderBy('postedAt', descending: true)
          .limit(200)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        setState(() {
          _allJobs  = [];
          _filtered = [];
          _isLoading = false;
        });
        return;
      }

      // Build raw list with doc id attached
      final rawJobs = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();

      // Score via shared JobScorer
      final scored = JobScorer.scoreAndSort(
        jobs:           rawJobs,
        userCourse:     _userCourse,
        userOccupation: _userOccupation,
        userCompany:    _userCompany,
      );

      // Normalise display fields
      final display = scored.map((data) {
        String g(String k, String fb) {
          final v = data[k]?.toString().trim();
          return (v != null && v.isNotEmpty) ? v : fb;
        }
        return {
          'id':            data['id']?.toString()  ?? '',
          'title':         g('title',       'Untitled'),
          'company':       g('company',     'Confidential'),
          'location':      g('location',    'Not specified'),
          'type':          g('type',        'Full-time'),
          'salary':        g('salary',      ''),
          'description':   g('description', ''),
          'category':      g('category',    ''),
          'contactEmail':  g('contactEmail', ''),
          'contactPhone':  g('contactPhone', ''),
          'applyLink':     g('applyLink',   ''),
          'postedAt':      data['postedAt'],
          'postedBy':      g('postedBy',    ''),
          'score':         data['score']      as int?  ?? 0,
          'isRelevant':    data['isRelevant'] as bool? ?? false,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _allJobs   = display;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('JobOpps: fetch error: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load jobs. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  // ─── Filter helpers ───────────────────────────────────────────────────────
  void _applyFilters() {
    var list = List<Map<String, dynamic>>.from(_allJobs);

    if (_showRelevantOnly) {
      list = list.where((j) => (j['score'] as int? ?? 0) > 0).toList();
    }

    if (_typeFilter != null) {
      list = list.where((j) =>
          j['type'].toString().toLowerCase()
              .contains(_typeFilter!.toLowerCase())).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((j) {
        return j['title'].toString().toLowerCase().contains(q)    ||
               j['company'].toString().toLowerCase().contains(q)  ||
               j['location'].toString().toLowerCase().contains(q) ||
               j['description'].toString().toLowerCase().contains(q) ||
               j['category'].toString().toLowerCase().contains(q);
      }).toList();
    }

    setState(() => _filtered = list);
  }

  List<String> get _availableTypes {
    final types = _allJobs
        .map((j) => j['type'].toString())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return types;
  }

  int get _relevantCount =>
      _allJobs.where((j) => (j['score'] as int? ?? 0) > 0).length;

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        title: Text(
          'Job Opportunities',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText),
        ),
        actions: [
          if (_relevantCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.brandRed.withOpacity(0.3)),
                  ),
                  child: Text(
                    '$_relevantCount for you',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandRed),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2.5))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.brandRed,
              child: Column(children: [
                _buildSearchAndFilters(),
                if (_profileLoaded && _userCourse.isNotEmpty && _relevantCount > 0)
                  _buildMatchBanner(),
                _buildResultsHeader(),
                Expanded(child: _buildJobList()),
              ]),
            ),
    );
  }

  // ─── Search + filter bar ──────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(children: [
        // Search field
        TextField(
          controller: _searchCtrl,
          style: GoogleFonts.inter(fontSize: 14),
          onChanged: (v) {
            setState(() => _searchQuery = v);
            _applyFilters();
          },
          decoration: InputDecoration(
            hintText: 'Search jobs, companies, locations...',
            hintStyle: GoogleFonts.inter(
                color: AppColors.mutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                color: AppColors.mutedText, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        size: 18, color: AppColors.mutedText),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      _applyFilters();
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip(
              'All (${_allJobs.length})',
              isSelected: _typeFilter == null && !_showRelevantOnly,
              onTap: () {
                setState(() {
                  _typeFilter       = null;
                  _showRelevantOnly = false;
                });
                _applyFilters();
              },
            ),
            if (_relevantCount > 0) ...[
              const SizedBox(width: 8),
              _filterChip(
                '⭐ For You ($_relevantCount)',
                isSelected: _showRelevantOnly,
                color: AppColors.brandRed,
                onTap: () {
                  setState(() {
                    _showRelevantOnly = !_showRelevantOnly;
                    _typeFilter       = null;
                  });
                  _applyFilters();
                },
              ),
            ],
            ..._availableTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _filterChip(
                    type,
                    isSelected: _typeFilter == type,
                    onTap: () {
                      setState(() {
                        _typeFilter       = _typeFilter == type ? null : type;
                        _showRelevantOnly = false;
                      });
                      _applyFilters();
                    },
                  ),
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMatchBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandRed.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandRed.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, size: 14, color: AppColors.brandRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Showing jobs matched to your course ($_userCourse)'
            '${_userOccupation.isNotEmpty ? ' and experience as $_userOccupation' : ''}.',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.brandRed, height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filtered.length} ${_filtered.length == 1 ? 'job' : 'jobs'} found',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w500),
          ),
          if (_showRelevantOnly || _typeFilter != null || _searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery      = '';
                  _typeFilter       = null;
                  _showRelevantOnly = false;
                });
                _applyFilters();
              },
              child: Text('Clear filters',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildJobList() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_outlined,
                  size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedText,
                      height: 1.5)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Retry',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_off_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No jobs found',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty ||
                        _typeFilter != null ||
                        _showRelevantOnly
                    ? 'Try adjusting your filters or search.'
                    : 'No approved job opportunities yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.5),
              ),
              if (_searchQuery.isNotEmpty ||
                  _typeFilter != null ||
                  _showRelevantOnly) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery      = '';
                      _typeFilter       = null;
                      _showRelevantOnly = false;
                    });
                    _applyFilters();
                  },
                  child: Text('Clear all filters',
                      style: GoogleFonts.inter(
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _jobCard(_filtered[i]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  JOB CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _jobCard(Map<String, dynamic> job) {
    final score      = job['score'] as int? ?? 0;
    final isRelevant = score > 0;
    final label      = JobScorer.relevanceLabel(score);
    final salary     = job['salary']?.toString() ?? '';
    final category   = job['category']?.toString() ?? '';
    final postedAt   = job['postedAt'] as Timestamp?;

    return GestureDetector(
      onTap: () => _showJobDetail(job),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRelevant
                ? AppColors.brandRed.withOpacity(0.3)
                : AppColors.borderSubtle,
            width: isRelevant ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Relevance banner
          if (isRelevant)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome,
                    size: 12, color: AppColors.brandRed),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandRed)),
              ]),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Type badge + location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    _typeBadge(job['type'].toString()),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _categoryBadge(category),
                    ],
                  ]),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 11, color: AppColors.mutedText),
                    const SizedBox(width: 2),
                    Text(job['location'].toString(),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedText)),
                  ]),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(job['title'].toString(),
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
              const SizedBox(height: 4),

              // Company
              Row(children: [
                const Icon(Icons.business_outlined,
                    size: 13, color: AppColors.mutedText),
                const SizedBox(width: 4),
                Text(job['company'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w500)),
              ]),

              // Description preview
              if (job['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(job['description'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText,
                        height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],

              const SizedBox(height: 12),

              // Footer: salary + date + Apply button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (salary.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.payments_outlined,
                              size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(salary,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      if (postedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Posted ${DateFormat('MMM dd, yyyy').format(postedAt.toDate())}',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.mutedText),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showJobDetail(job),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isRelevant
                            ? AppColors.brandRed
                            : AppColors.darkText,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Text('APPLY NOW',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: Colors.white)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Colors.white),
                      ]),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  JOB DETAIL BOTTOM SHEET — with working Apply section
  // ─────────────────────────────────────────────────────────────────────────
  void _showJobDetail(Map<String, dynamic> job) {
    final score      = job['score'] as int? ?? 0;
    final isRelevant = score > 0;
    final label      = JobScorer.relevanceLabel(score);
    final salary     = job['salary']?.toString() ?? '';
    final category   = job['category']?.toString() ?? '';
    final postedAt   = job['postedAt'] as Timestamp?;
    final contactEmail = job['contactEmail']?.toString() ?? '';
    final contactPhone = job['contactPhone']?.toString() ?? '';
    final applyLink    = job['applyLink']?.toString()    ?? '';

    // Determine if there's any contact info
    final hasContact = contactEmail.isNotEmpty ||
        contactPhone.isNotEmpty ||
        applyLink.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: [
                  // Relevance banner inside sheet
                  if (isRelevant)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.brandRed.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.brandRed
                                .withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.auto_awesome,
                            size: 13, color: AppColors.brandRed),
                        const SizedBox(width: 8),
                        Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandRed)),
                      ]),
                    ),

                  // Title
                  Text(job['title'].toString(),
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                          height: 1.1)),
                  const SizedBox(height: 6),

                  // Company
                  Row(children: [
                    const Icon(Icons.business_outlined,
                        size: 14, color: AppColors.mutedText),
                    const SizedBox(width: 6),
                    Text(job['company'].toString(),
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w500)),
                  ]),

                  const SizedBox(height: 16),

                  // Tags
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _detailChip(Icons.work_outline,
                        job['type'].toString()),
                    _detailChip(Icons.location_on_outlined,
                        job['location'].toString()),
                    if (category.isNotEmpty)
                      _detailChip(
                          Icons.category_outlined, category),
                    if (salary.isNotEmpty)
                      _detailChip(
                          Icons.payments_outlined, salary,
                          color: Colors.green),
                    if (postedAt != null)
                      _detailChip(
                          Icons.calendar_today_outlined,
                          'Posted ${DateFormat('MMM dd, yyyy').format(postedAt.toDate())}'),
                  ]),

                  // Description
                  if (job['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('About This Role',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 8),
                    Text(job['description'].toString(),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.mutedText,
                            height: 1.6)),
                  ],

                  // ── How to Apply ────────────────────────────────────────
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.borderSubtle),
                    ),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.brandRed
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: const Icon(
                              Icons.send_outlined,
                              color: AppColors.brandRed,
                              size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text('How to Apply',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText)),
                      ]),
                      const SizedBox(height: 14),

                      if (!hasContact)
                        Text(
                          'Contact the posting organization directly or visit their website for application instructions.',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.mutedText,
                              height: 1.5),
                        ),

                      // Apply link
                      if (applyLink.isNotEmpty) ...[
                        _applyOptionTile(
                          icon: Icons.open_in_new_rounded,
                          label: 'Apply Online',
                          value: applyLink,
                          color: AppColors.brandRed,
                          onTap: () => _launchUrl(applyLink),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Email
                      if (contactEmail.isNotEmpty) ...[
                        _applyOptionTile(
                          icon: Icons.email_outlined,
                          label: 'Send Email',
                          value: contactEmail,
                          color: Colors.blue.shade700,
                          onTap: () => _launchUrl(
                              'mailto:$contactEmail?subject=Application for ${Uri.encodeComponent(job['title'].toString())}'),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Phone
                      if (contactPhone.isNotEmpty)
                        _applyOptionTile(
                          icon: Icons.phone_outlined,
                          label: 'Call',
                          value: contactPhone,
                          color: Colors.green.shade700,
                          onTap: () =>
                              _launchUrl('tel:$contactPhone'),
                        ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Main CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (applyLink.isNotEmpty) {
                          _launchUrl(applyLink);
                        } else if (contactEmail.isNotEmpty) {
                          _launchUrl(
                              'mailto:$contactEmail?subject=Application for ${Uri.encodeComponent(job['title'].toString())}');
                        } else if (contactPhone.isNotEmpty) {
                          _launchUrl('tel:$contactPhone');
                        } else {
                          // No contact info — show snackbar
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: Text(
                                'Contact info not provided. Reach out to the company directly.',
                                style: GoogleFonts.inter(),
                              ),
                              backgroundColor:
                                  Colors.orange.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(12),
                            ));
                        }
                      },
                      icon: Icon(
                        applyLink.isNotEmpty
                            ? Icons.open_in_new
                            : contactEmail.isNotEmpty
                                ? Icons.email_outlined
                                : Icons.work_outline,
                        size: 16,
                      ),
                      label: Text(
                        applyLink.isNotEmpty
                            ? 'APPLY ONLINE'
                            : contactEmail.isNotEmpty
                                ? 'SEND APPLICATION EMAIL'
                                : 'APPLY FOR THIS JOB',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── URL launcher helper ──────────────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: Text('Could not open: $url',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(12),
            ));
        }
      }
    } catch (e) {
      debugPrint('URL launch error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _applyOptionTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.chevron_right, color: color, size: 18),
        ]),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label,
      {Color color = AppColors.mutedText}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: AppColors.brandRed,
            letterSpacing: 0.8),
      ),
    );
  }

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(category,
          style: GoogleFonts.inter(
              fontSize: 8,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _filterChip(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
    Color color = AppColors.mutedText,
  }) {
    final activeColor =
        color == AppColors.mutedText ? AppColors.darkText : color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.softWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderSubtle,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppColors.mutedText)),
      ),
    );
  }
}