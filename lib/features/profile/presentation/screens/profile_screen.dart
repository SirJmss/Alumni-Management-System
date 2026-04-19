// ─────────────────────────────────────────────────────────────────────────────
// AlumniProfileScreen — own-profile view
// FILE: lib/features/profile/presentation/screens/alumni_profile_screen.dart
//
// FIX: Cover/avatar overlap — replaced Stack+Positioned with
//      Transform.translate on both the avatar row and the content column,
//      matching the same technique as alumni_public_profile_screen.dart.
//      Both translate by -_avatarOverlap so the avatar sits precisely on
//      the cover edge and the content starts flush below the avatar.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'edit_profile_screen.dart';

class AlumniProfileScreen extends StatefulWidget {
  const AlumniProfileScreen({super.key});

  @override
  State<AlumniProfileScreen> createState() =>
      _AlumniProfileScreenState();
}

class _AlumniProfileScreenState
    extends State<AlumniProfileScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // ─── Layout constants ─────────────────────────────────
  static const double _coverHeight   = 220.0;
  static const double _avatarRadius  = 52.0;
  static const double _avatarBorder  = 4.0;
  static const double _avatarOverlap = _avatarRadius * 0.8;

  void _goToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  // ─── Data helpers ─────────────────────────────────────
  String _safe(Map<String, dynamic> data, String key, {String fallback = '—'}) {
    final val = data[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  String _safeOr(Map<String, dynamic> data, String key, String altKey,
      {String fallback = '—'}) {
    final val = data[key]?.toString().trim();
    if (val != null && val.isNotEmpty) return val;
    final alt = data[altKey]?.toString().trim();
    return (alt != null && alt.isNotEmpty) ? alt : fallback;
  }

  int _safeInt(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val == null) return 0;
    if (val is int)  return val;
    if (val is num)  return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _safeList(Map<String, dynamic> data, String key) {
    final list = data[key];
    if (list == null || list is! List) return [];
    return list.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> _safeStringList(Map<String, dynamic> data, String key) {
    final list = data[key];
    if (list == null || list is! List) return [];
    return list.map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    DateTime? date = value is Timestamp
        ? value.toDate() : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('MMM yyyy').format(date) : '';
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    if (e.isEmpty) return s.isNotEmpty ? '$s – Present' : 'Present';
    return s.isNotEmpty ? '$s – $e' : e;
  }

  String _safeMap(Map<String, dynamic>? map, String key,
      {String fallback = '—'}) {
    final val = map?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _uid
    .isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Not signed in',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 24, color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text('Please sign in to view your profile.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText)),
          ],
        )),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F4F6),
            body: Center(child: CircularProgressIndicator(
                color: AppColors.brandRed, strokeWidth: 2.5)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F4F6),
            body: Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Could not load profile',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 22, color: AppColors.darkText)),
                const SizedBox(height: 8),
                Text(snapshot.error.toString(),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                    textAlign: TextAlign.center),
              ]),
            )),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F4F6),
            body: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Profile not found',
                    style: GoogleFonts.inter(fontSize: 16, color: AppColors.mutedText)),
              ],
            )),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildProfile(data);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  MAIN PROFILE BODY
  // ═══════════════════════════════════════════════════════

  Widget _buildProfile(Map<String, dynamic> data) {
    String resolveUrl(List<String> keys) {
      for (final k in keys) {
        final raw = data[k]?.toString().trim() ?? '';
        if (raw.isNotEmpty && raw != 'null' && raw != 'undefined') return raw;
      }
      return '';
    }

    final coverUrl  = resolveUrl(['coverPictureUrl', 'coverPhotoUrl']);
    final avatarUrl = resolveUrl(['profilePictureUrl', 'photoURL', 'avatarUrl']);
    final hasCover  = coverUrl.isNotEmpty;
    final hasAvatar = avatarUrl.isNotEmpty;

    final experiences     = _safeList(data, 'experience');
    final education       = _safeList(data, 'education');
    final skills          = _safeStringList(data, 'skills');
    final certifications  = _safeList(data, 'certifications');
    final bio             = _safeOr(data, 'about', 'bio');

    final email = data['email']?.toString().trim().isNotEmpty == true
        ? data['email'].toString().trim()
        : FirebaseAuth.instance.currentUser?.email ?? '—';

    final connectionsCount = _safeInt(data, 'connectionsCount');
    final followersCount   = _safeInt(data, 'followersCount');
    final followingCount   = _safeInt(data, 'followingCount');

    final verificationStatus = _safe(data, 'verificationStatus', fallback: '');
    final isVerified = _safe(data,'status',fallback:'') == 'active' ||
                       verificationStatus == 'verified';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0.5,
            foregroundColor: AppColors.darkText,
            title: Text('My Profile',
                style: GoogleFonts.cormorantGaramond(fontSize: 22)),
            actions: [
              TextButton.icon(
                onPressed: _goToEdit,
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.brandRed),
                label: Text('Edit', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.brandRed)),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Cover ──────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: _coverHeight,
              width: double.infinity,
              child: hasCover
                  ? Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                        imageUrl: coverUrl, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.softWhite),
                        errorWidget: (_, __, ___) => _defaultCover(),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent,
                                       Colors.black.withOpacity(0.4)],
                            ),
                          ),
                        ),
                      ),
                    ])
                  : _defaultCover(),
            ),
          ),

          // ── Avatar + Edit shortcut (overlapping cover) ─
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -_avatarOverlap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _goToEdit,
                      child: Hero(
                        tag: 'alumni_avatar_${_uid ?? ''}',
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFF4F4F6),
                                    width: _avatarBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 16, offset: const Offset(0, 6),
                                  ),
                                ],
                                color: Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: _avatarRadius,
                                backgroundColor: AppColors.borderSubtle,
                                child: hasAvatar
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          width:  _avatarRadius * 2,
                                          height: _avatarRadius * 2,
                                          placeholder: (_, __) =>
                                              Container(color: Colors.grey.shade100),
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.person, size: 52,
                                                  color: AppColors.brandRed),
                                        ),
                                      )
                                    : const Icon(Icons.person, size: 52,
                                          color: AppColors.brandRed),
                              ),
                            ),
                            // Camera overlay badge
                            Positioned(
                              bottom: 4, right: 4,
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.brandRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFF4F4F6), width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Edit button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ElevatedButton.icon(
                        onPressed: _goToEdit,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text('Edit Profile',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── All content — compensates for the translate above ──
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -_avatarOverlap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ── Name / headline / meta ──────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + verified
                        Row(children: [
                          Flexible(
                            child: Text(_safe(data, 'name'),
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 30, fontWeight: FontWeight.w700,
                                    color: AppColors.darkText)),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.verified_rounded,
                                    size: 11, color: Colors.green),
                                const SizedBox(width: 3),
                                Text('Verified', style: GoogleFonts.inter(
                                    fontSize: 9, fontWeight: FontWeight.w700,
                                    color: Colors.green)),
                              ]),
                            ),
                          ],
                        ]),

                        // Role / headline
                        if (_safeOr(data, 'headline', 'role') != '—') ...[
                          const SizedBox(height: 4),
                          Text(_safeOr(data, 'headline', 'role'),
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: AppColors.darkText)),
                        ],

                        // Company
                        if (_safe(data, 'company') != '—') ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.business_outlined,
                                size: 12, color: AppColors.mutedText),
                            const SizedBox(width: 4),
                            Flexible(child: Text(_safe(data, 'company'),
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.mutedText),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ],

                        const SizedBox(height: 10),

                        // Meta chips
                        Wrap(spacing: 16, runSpacing: 8, children: [
                          if (_safe(data, 'location') != '—')
                            _MetaBit(icon: Icons.location_on_outlined,
                                text: _safe(data, 'location')),
                          if (_safeOr(data,'batch','batchYear') != '—')
                            _MetaBit(icon: Icons.school_outlined,
                                text: 'Batch ${_safeOr(data,"batch","batchYear")}'),
                          if (_safeOr(data,'course','program') != '—')
                            _MetaBit(icon: Icons.auto_stories_outlined,
                                text: _safeOr(data,'course','program')),
                          if (_safe(data, 'phone_number') != '—')
                            _MetaBit(icon: Icons.phone_outlined,
                                text: _safe(data, 'phone_number')),
                          _MetaBit(icon: Icons.email_outlined, text: email),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Stats ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(children: [
                        _StatCell(count: connectionsCount, label: 'Connections'),
                        _StatDivider(),
                        _StatCell(count: followersCount,   label: 'Followers'),
                        _StatDivider(),
                        _StatCell(count: followingCount,   label: 'Following'),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Personal Details ──────────────────────
                  _buildPersonalDetailsCard(data, email),
                  const SizedBox(height: 14),

                  // ── About ─────────────────────────────────
                  _SectionCard(
                    title: 'About',
                    icon: Icons.person_outline_rounded,
                    onEdit: _goToEdit,
                    child: bio != '—'
                        ? Text(bio, style: GoogleFonts.inter(
                              fontSize: 14, height: 1.65,
                              color: AppColors.darkText))
                        : _emptyState('No summary added yet.', Icons.info_outline),
                  ),
                  const SizedBox(height: 14),

                  // ── Skills ────────────────────────────────
                  if (skills.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Skills',
                      icon: Icons.star_outline_rounded,
                      onEdit: _goToEdit,
                      child: _buildSkillsWrap(skills),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Experience ────────────────────────────
                  _SectionCard(
                    title: 'Experience',
                    icon: Icons.work_outline_rounded,
                    onEdit: _goToEdit,
                    child: experiences.isNotEmpty
                        ? Column(children: experiences.map(_experienceCard).toList())
                        : _emptyState('No experience added yet.', Icons.work_outline),
                  ),
                  const SizedBox(height: 14),

                  // ── Education ─────────────────────────────
                  _SectionCard(
                    title: 'Education',
                    icon: Icons.school_outlined,
                    onEdit: _goToEdit,
                    child: education.isNotEmpty
                        ? Column(children: education.map(_educationCard).toList())
                        : _emptyState('No education added yet.', Icons.school_outlined),
                  ),
                  const SizedBox(height: 14),

                  // ── Certifications ────────────────────────
                  if (certifications.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Certifications',
                      icon: Icons.verified_outlined,
                      onEdit: _goToEdit,
                      child: Column(
                          children: certifications.map(_certificationCard).toList()),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Personal Details card ───────────────────────────
  Widget _buildPersonalDetailsCard(Map<String, dynamic> data, String email) {
    final batchVal    = _safeOr(data, 'batch', 'graduationYear');
    final courseVal   = _safeOr(data, 'course', 'program');
    final studentId   = _safeOr(data, 'student_id', 'studentId');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Personal Details',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20, fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
              GestureDetector(
                onTap: _goToEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: AppColors.brandRed, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _detailRow(Icons.person_outline, 'Full Name', _safe(data, 'name')),
            _detailRow(Icons.email_outlined, 'Email', email),
            if (_safe(data, 'phone_number') != '—')
              _detailRow(Icons.phone_outlined, 'Phone', _safe(data, 'phone_number')),
            if (_safe(data, 'location') != '—')
              _detailRow(Icons.location_on_outlined, 'Location', _safe(data, 'location')),
            if (_safeOr(data, 'role', 'userType') != '—')
              _detailRow(Icons.badge_outlined, 'Role', _safeOr(data, 'role', 'userType')),
            if (batchVal != '—')
              _detailRow(Icons.calendar_today_outlined, 'Batch / Graduation Year', batchVal),
            if (courseVal != '—')
              _detailRow(Icons.menu_book_outlined, 'Course / Program', courseVal),
            if (studentId != '—')
              _detailRow(Icons.tag_outlined, 'Student ID', studentId, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool isLast = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.brandRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: AppColors.brandRed),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.mutedText, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: AppColors.darkText)),
            ],
          )),
        ]),
      ),
      if (!isLast)
        const Divider(height: 1, thickness: 0.5, color: AppColors.borderSubtle),
    ]);
  }

  Widget _buildSkillsWrap(List<String> skills) {
    return Wrap(spacing: 8, runSpacing: 8,
      children: skills.map((skill) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.brandRed.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brandRed.withOpacity(0.25)),
        ),
        child: Text(skill, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.brandRed)),
      )).toList(),
    );
  }

  Widget _experienceCard(Map<String, dynamic> exp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.work_outline, color: AppColors.brandRed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_safeMap(exp, 'title'), style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(_safeMap(exp, 'company'), style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.brandRed, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_formatPeriod(exp['start'], exp['end']),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
            if (_safeMap(exp, 'location') != '—') ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 11, color: AppColors.mutedText),
                const SizedBox(width: 3),
                Flexible(child: Text(_safeMap(exp, 'location'),
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText))),
              ]),
            ],
            if (_safeMap(exp, 'description') != '—') ...[
              const SizedBox(height: 6),
              Text(_safeMap(exp, 'description'), style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.darkText.withOpacity(0.8),
                  height: 1.5)),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _educationCard(Map<String, dynamic> edu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.school_outlined, color: AppColors.brandRed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_safeMap(edu, 'degree'), style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(_safeMap(edu, 'school'), style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.brandRed, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_formatPeriod(edu['start'], edu['end']),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
            if (_safeMap(edu, 'fieldOfStudy') != '—') ...[
              const SizedBox(height: 2),
              Text(_safeMap(edu, 'fieldOfStudy'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
            ],
            if (_safeMap(edu, 'grade') != '—') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.military_tech_outlined, size: 12, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(_safeMap(edu, 'grade'), style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800)),
                ]),
              ),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _certificationCard(Map<String, dynamic> cert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.verified_outlined, color: AppColors.brandRed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_safeMap(cert, 'name'), style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            if (_safeMap(cert, 'issuer') != '—') ...[
              const SizedBox(height: 2),
              Text(_safeMap(cert, 'issuer'), style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.brandRed, fontWeight: FontWeight.w500)),
            ],
            if (_safeMap(cert, 'year') != '—' || cert['date'] != null) ...[
              const SizedBox(height: 2),
              Text(_safeMap(cert, 'year', fallback: _formatDate(cert['date'])),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _emptyState(String msg, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(children: [
      Icon(icon, size: 20, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Flexible(child: Text(msg, style: GoogleFonts.inter(
          fontSize: 14, color: AppColors.mutedText))),
    ]),
  );

  Widget _defaultCover() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6B0000), Color(0xFFB22222), Color(0xFFCC4444)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onEdit;
  const _SectionCard({
    required this.title, required this.icon,
    required this.child, this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: AppColors.brandRed),
                ),
                const SizedBox(width: 10),
                Text(title, style: GoogleFonts.cormorantGaramond(
                    fontSize: 19, fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
              ]),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.brandRed.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: AppColors.brandRed, size: 16),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetaBit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaBit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: AppColors.mutedText),
    const SizedBox(width: 4),
    Text(text, style: GoogleFonts.inter(
        fontSize: 12, color: AppColors.mutedText)),
  ]);
}

class _StatCell extends StatelessWidget {
  final int count;
  final String label;
  const _StatCell({required this.count, required this.label});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(children: [
        Text(_fmt(count), style: GoogleFonts.cormorantGaramond(
            fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.darkText)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(
            fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 32, width: 1, color: AppColors.borderSubtle);
}