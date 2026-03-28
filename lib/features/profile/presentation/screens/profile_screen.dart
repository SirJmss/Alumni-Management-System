// ─────────────────────────────────────────────────────────────────────────────
// AlumniProfileScreen — own-profile view
//
// PLACE THIS FILE AT:
//   lib/features/profile/presentation/screens/alumni_profile_screen.dart
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'edit_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlumniProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class AlumniProfileScreen extends StatefulWidget {
  const AlumniProfileScreen({super.key});

  @override
  State<AlumniProfileScreen> createState() => _AlumniProfileScreenState();
}

class _AlumniProfileScreenState extends State<AlumniProfileScreen> {
  // ✅ FIX #1 — currentUser?.uid accessed once; guard null here so the rest
  //             of the screen never needs to null-check it.
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // ─── Navigation ──────────────────────────────────────────────────────────
  void _goToEdit() {
    // ✅ FIX #6 — StreamBuilder already watches Firestore live, so we no
    //             longer need .then((_) => _loadUserProfile()) here.
    //             Navigation is clean; the stream updates automatically.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  // ─── Data helpers ─────────────────────────────────────────────────────────

  /// Returns a trimmed string for [key], or [fallback] if absent/empty.
  String _safe(Map<String, dynamic> data, String key,
      {String fallback = '—'}) {
    final val = data[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  /// Tries [key], falls back to [altKey], then [fallback].
  String _safeOr(Map<String, dynamic> data, String key, String altKey,
      {String fallback = '—'}) {
    final val = data[key]?.toString().trim();
    if (val != null && val.isNotEmpty) return val;
    final alt = data[altKey]?.toString().trim();
    return (alt != null && alt.isNotEmpty) ? alt : fallback;
  }

  /// ✅ FIX #7 — Dedicated int accessor; _safe() returns String which is
  ///             wrong for numeric counter fields (connectionsCount, etc.).
  int _safeInt(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  /// Extracts a typed list of maps from a Firestore field.
  List<Map<String, dynamic>> _safeList(Map<String, dynamic> data,
      String key) {
    final list = data[key];
    if (list == null || list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Extracts a typed list of strings (e.g. skills, certifications).
  List<String> _safeStringList(Map<String, dynamic> data, String key) {
    final list = data[key];
    if (list == null || list is! List) return [];
    return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    DateTime? date = value is Timestamp
        ? value.toDate()
        : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('MMM yyyy').format(date) : '';
  }

  /// ✅ FIX #10 — end could be null OR an empty string; check both.
  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    // end is "present" if null OR empty string after formatting
    if (e.isEmpty) return s.isNotEmpty ? '$s – Present' : 'Present';
    return s.isNotEmpty ? '$s – $e' : e;
  }

  String _safeMap(Map<String, dynamic>? map, String key,
      {String fallback = '—'}) {
    final val = map?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  // ─── Layout constants ─────────────────────────────────────────────────────
  // Avatar slightly smaller & less overlap so it doesn't visually fight
  // with the cover image. We also compute total height below.
  static const double _avatarRadius = 52.0;
  static const double _avatarBorder = 4.0;
  static const double _coverHeight = 210.0;

  double get _avatarTotal => _avatarRadius + _avatarBorder;

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ✅ Guard: unauthenticated user should never reach this screen but
    //          handle gracefully rather than crash.
    if (_uid == null || _uid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Not signed in',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 24, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text('Please sign in to view your profile.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText)),
            ],
          ),
        ),
      );
    }

    // ✅ FIX #1 — StreamBuilder replaces manual FutureBuilder + isLoading
    //             pattern. Profile now updates in real-time: when EditProfile
    //             saves to Firestore, this screen reflects changes instantly
    //             without any manual _loadUserProfile() call.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        // ── Loading ──────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.softWhite,
            body: Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2.5),
            ),
          );
        }

        // ── Firestore error ──────────────────────────────────────────────
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.softWhite,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Could not load profile',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 22, color: AppColors.darkText)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.mutedText),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Document missing ─────────────────────────────────────────────
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: AppColors.softWhite,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Profile not found',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppColors.mutedText)),
                ],
              ),
            ),
          );
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>;
        return _buildProfile(data);
      },
    );
  }

  // ─── Main profile scaffold ────────────────────────────────────────────────
  Widget _buildProfile(Map<String, dynamic> data) {
    // ✅ Resolve image URLs from multiple possible keys
    String _resolveUrl(Map<String, dynamic> src, List<String> keys) {
      for (final k in keys) {
        final raw = src[k]?.toString().trim() ?? '';
        if (raw.isNotEmpty &&
            raw.toLowerCase() != 'null' &&
            raw.toLowerCase() != 'undefined') {
          return raw;
        }
      }
      return '';
    }

    final coverUrl = _resolveUrl(data, ['coverPictureUrl', 'coverPhotoUrl']);
    final avatarUrl =
        _resolveUrl(data, ['profilePictureUrl', 'photoURL', 'avatarUrl']);

    final hasCover = coverUrl.isNotEmpty;
    final hasAvatar = avatarUrl.isNotEmpty;

    final experiences = _safeList(data, 'experience');
    final education = _safeList(data, 'education');
    final skills = _safeStringList(data, 'skills');
    final certifications = _safeList(data, 'certifications');

    // ✅ FIX #3 — Check both 'bio' and 'about'; Firestore field name varies
    //    depending on which version of EditProfileScreen saved the data.
    final bio = _safeOr(data, 'bio', 'about');

    // ✅ Resolve email: prefer Firestore doc, fall back to Firebase Auth object
    final email =
        data['email']?.toString().trim().isNotEmpty == true
            ? data['email'].toString().trim()
            : FirebaseAuth.instance.currentUser?.email ?? '—';

    // ✅ FIX #7 — Use _safeInt, not _safe, for numeric counter fields
    final connectionsCount = _safeInt(data, 'connectionsCount');
    final followersCount = _safeInt(data, 'followersCount');
    final followingCount = _safeInt(data, 'followingCount');

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            elevation: 0,
            foregroundColor: AppColors.darkText,
            title: Text(
              'My Profile',
              style: GoogleFonts.cormorantGaramond(fontSize: 24),
            ),
            actions: [
              TextButton.icon(
                onPressed: _goToEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.brandRed),
                label: Text('Edit',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandRed)),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Cover + Avatar ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover
                SizedBox(
                  height: _coverHeight,
                  width: double.infinity,
                  child: hasCover
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.softWhite),
                              errorWidget: (_, __, ___) => _defaultCover(),
                            ),
                            // Dark gradient at bottom to separate avatar
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.35),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _defaultCover(),
                ),
                // Avatar (slightly overlapping the cover)
                Positioned(
                  bottom: -(_avatarTotal * 0.6),
                  left: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.softWhite,
                        width: _avatarBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      color: AppColors.cardWhite,
                    ),
                    child: Hero(
                      tag: 'alumni_avatar_${_uid ?? ''}',
                      child: CircleAvatar(
                        radius: _avatarRadius,
                        backgroundColor: AppColors.borderSubtle,
                        child: hasAvatar
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  width: _avatarRadius * 2,
                                  height: _avatarRadius * 2,
                                  placeholder: (_, __) => Container(
                                      color: Colors.grey.shade100),
                                  errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 52,
                                      color: AppColors.brandRed),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 52,
                                color: AppColors.brandRed,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Space for avatar overlap ─────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(height: _avatarTotal + 28),
          ),

          // ── Name, headline, info chips, stats ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Text(
                    _safe(data, 'name'),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Headline / role
                  if (_safeOr(data, 'headline', 'role') != '—') ...[
                    Text(
                      _safeOr(data, 'headline', 'role'),
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.darkText),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Company
                  if (_safe(data, 'company') != '—') ...[
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 14, color: AppColors.mutedText),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _safe(data, 'company'),
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.mutedText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  const SizedBox(height: 8),

                  // Info chips
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (_safe(data, 'location') != '—')
                        _infoChip(Icons.location_on_outlined,
                            _safe(data, 'location')),
                      if (_safe(data, 'phone_number') != '—')
                        _infoChip(Icons.phone_outlined,
                            _safe(data, 'phone_number')),
                      if (email != '—')
                        _infoChip(Icons.email_outlined, email),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stats row
                  Row(
                    children: [
                      _statBadge(connectionsCount, 'connections'),
                      const SizedBox(width: 16),
                      _statBadge(followersCount, 'followers'),
                      const SizedBox(width: 16),
                      _statBadge(followingCount, 'following'),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Personal Details Card ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildPersonalDetailsCard(data, email),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── About ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'About',
              child: bio != '—'
                  ? Text(bio,
                      style:
                          GoogleFonts.inter(fontSize: 15, height: 1.6,
                              color: AppColors.darkText))
                  : _emptyState(
                      'No professional summary added yet.',
                      Icons.info_outline),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Skills ───────────────────────────────────────────────────────
          if (skills.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _sectionCard(
                title: 'Skills',
                child: _buildSkillsWrap(skills),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // ── Experience ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'Experience',
              child: experiences.isNotEmpty
                  ? Column(
                      children:
                          experiences.map(_experienceCard).toList())
                  : _emptyState(
                      'No experience added yet.', Icons.work_outline),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Education ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'Education',
              child: education.isNotEmpty
                  ? Column(
                      children:
                          education.map(_educationCard).toList())
                  : _emptyState(
                      'No education added yet.', Icons.school_outlined),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Certifications ───────────────────────────────────────────────
          if (certifications.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _sectionCard(
                title: 'Certifications',
                child: Column(
                  children: certifications
                      .map(_certificationCard)
                      .toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─── Personal Details Card ────────────────────────────────────────────────
  Widget _buildPersonalDetailsCard(
      Map<String, dynamic> data, String email) {
    // ✅ FIX #5 — batch + graduationYear: check both field name variants
    final batchVal = _safeOr(data, 'batch', 'graduationYear');
    final courseVal = _safeOr(data, 'course', 'program');
    // ✅ FIX #9 — cover field key: check both variants
    final studentId = _safeOr(data, 'student_id', 'studentId');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personal Details',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.brandRed, size: 18),
                  tooltip: 'Edit details',
                  onPressed: _goToEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: _safe(data, 'name'),
            ),
            _detailDivider(),
            _detailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
            ),
            if (_safe(data, 'phone_number') != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _safe(data, 'phone_number'),
              ),
            ],
            if (_safe(data, 'location') != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: _safe(data, 'location'),
              ),
            ],
            if (_safeOr(data, 'role', 'userType') != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: _safeOr(data, 'role', 'userType'),
              ),
            ],
            if (batchVal != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Batch / Graduation Year',
                value: batchVal,
              ),
            ],
            if (courseVal != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.menu_book_outlined,
                label: 'Course / Program',
                value: courseVal,
              ),
            ],
            if (studentId != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.tag_outlined,
                label: 'Student ID',
                value: studentId,
              ),
            ],
            if (_safe(data, 'department') != '—') ...[
              _detailDivider(),
              _detailRow(
                icon: Icons.account_balance_outlined,
                label: 'Department',
                value: _safe(data, 'department'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Skills wrap ─────────────────────────────────────────────────────────
  Widget _buildSkillsWrap(List<String> skills) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map(
            (skill) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.brandRed.withOpacity(0.25)),
              ),
              child: Text(
                skill,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandRed,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ─── Certification card ──────────────────────────────────────────────────
  Widget _certificationCard(Map<String, dynamic> cert) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_outlined,
                  color: AppColors.brandRed, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_safeMap(cert, 'name'),
                      style: _titleStyle),
                  if (_safeMap(cert, 'issuer') != '—') ...[
                    const SizedBox(height: 2),
                    Text(_safeMap(cert, 'issuer'),
                        style: _companyStyle),
                  ],
                  if (_safeMap(cert, 'year') != '—' ||
                      cert['date'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _safeMap(cert, 'year',
                          fallback: _formatDate(cert['date'])),
                      style: _dateStyle,
                    ),
                  ],
                  if (_safeMap(cert, 'credentialId') != '—') ...[
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${_safeMap(cert, 'credentialId')}',
                      style: _dateStyle,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  // ─── Detail row ──────────────────────────────────────────────────────────
  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.brandRed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() => const Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.borderSubtle,
      );

  // ─── Section card ─────────────────────────────────────────────────────────
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.brandRed),
                  tooltip: 'Edit $title',
                  onPressed: _goToEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ─── Info chip ────────────────────────────────────────────────────────────
  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style:
                GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ✅ FIX #7 — Accepts int now, not String; formats large numbers correctly
  Widget _statBadge(int count, String label) {
    final display = count >= 1000
        ? '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k'
        : count.toString();
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: display,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brandRed,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFFB22222)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  // ─── Experience card ─────────────────────────────────────────────────────
  Widget _experienceCard(Map<String, dynamic> exp) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.work_outline,
                  color: AppColors.brandRed, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_safeMap(exp, 'title'), style: _titleStyle),
                  const SizedBox(height: 2),
                  Text(_safeMap(exp, 'company'), style: _companyStyle),
                  const SizedBox(height: 2),
                  Text(
                    _formatPeriod(exp['start'], exp['end']),
                    style: _dateStyle,
                  ),
                  if (_safeMap(exp, 'employmentType') != '—') ...[
                    const SizedBox(height: 2),
                    Text(_safeMap(exp, 'employmentType'),
                        style: _dateStyle),
                  ],
                  if (_safeMap(exp, 'location') != '—') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(_safeMap(exp, 'location'),
                              style: _dateStyle),
                        ),
                      ],
                    ),
                  ],
                  if (_safeMap(exp, 'description') != '—') ...[
                    const SizedBox(height: 8),
                    Text(_safeMap(exp, 'description'), style: _bodyStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  // ─── Education card ──────────────────────────────────────────────────────
  Widget _educationCard(Map<String, dynamic> edu) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_outlined,
                  color: AppColors.brandRed, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_safeMap(edu, 'degree'), style: _titleStyle),
                  const SizedBox(height: 2),
                  Text(_safeMap(edu, 'school'), style: _companyStyle),
                  const SizedBox(height: 2),
                  Text(
                    _formatPeriod(edu['start'], edu['end']),
                    style: _dateStyle,
                  ),
                  if (_safeMap(edu, 'fieldOfStudy') != '—') ...[
                    const SizedBox(height: 4),
                    Text(_safeMap(edu, 'fieldOfStudy'), style: _bodyStyle),
                  ],
                  if (_safeMap(edu, 'grade') != '—') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.military_tech_outlined,
                            size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 3),
                        Text('Grade: ${_safeMap(edu, 'grade')}',
                            style: _dateStyle),
                      ],
                    ),
                  ],
                  if (_safeMap(edu, 'activities') != '—') ...[
                    const SizedBox(height: 4),
                    Text(_safeMap(edu, 'activities'), style: _bodyStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  // ─── Empty state ─────────────────────────────────────────────────────────
  Widget _emptyState(String msg, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                msg,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.mutedText),
              ),
            ),
          ],
        ),
      );

  // ─── Text styles ─────────────────────────────────────────────────────────
  TextStyle get _titleStyle => GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.darkText);

  TextStyle get _companyStyle => GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.brandRed,
      fontWeight: FontWeight.w600);

  TextStyle get _dateStyle =>
      GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText);

  TextStyle get _bodyStyle => GoogleFonts.inter(
      fontSize: 13.5,
      height: 1.6,
      color: AppColors.darkText);
}
