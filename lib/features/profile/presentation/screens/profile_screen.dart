// lib/features/profile/presentation/screens/alumni_profile_screen.dart

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
  // FIX: Use a SliverPersistentHeader approach instead of Transform.translate.
  // The avatar sits in its own dedicated row BELOW the cover with negative
  // top margin inside a Stack — this is the correct Flutter pattern that
  // doesn't cause cover-over-avatar clipping.
  static const double _coverHeight  = 200.0;
  static const double _avatarRadius = 50.0;
  static const double _avatarBorder = 3.5;
  // How far the avatar row overlaps INTO the cover from the bottom
  static const double _overlap      = 38.0;

  void _goToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  // ─── Data helpers ─────────────────────────────────────
  String _safe(Map<String, dynamic> d, String k, {String fb = '—'}) {
    final v = d[k]?.toString().trim();
    return (v != null && v.isNotEmpty) ? v : fb;
  }

  String _safeOr(Map<String, dynamic> d, String k1, String k2,
      {String fb = '—'}) {
    final v = d[k1]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
    final v2 = d[k2]?.toString().trim();
    return (v2 != null && v2.isNotEmpty) ? v2 : fb;
  }

  int _safeInt(Map<String, dynamic> d, String k) {
    final v = d[k];
    if (v == null) return 0;
    if (v is int)  return v;
    if (v is num)  return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _safeList(Map<String, dynamic> d, String k) {
    final l = d[k];
    if (l == null || l is! List) return [];
    return l.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> _safeStrList(Map<String, dynamic> d, String k) {
    final l = d[k];
    if (l == null || l is! List) return [];
    return l.map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty).toList();
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    final dt = v is Timestamp ? v.toDate() : DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('MMM yyyy').format(dt) : '';
  }

  String _fmtPeriod(dynamic s, dynamic e) {
    final ss = _fmtDate(s);
    final ee = _fmtDate(e);
    if (ee.isEmpty) return ss.isNotEmpty ? '$ss – Present' : 'Present';
    return ss.isNotEmpty ? '$ss – $ee' : ee;
  }

  String _mm(Map<String, dynamic>? m, String k, {String fb = '—'}) {
    final v = m?[k]?.toString().trim();
    return (v != null && v.isNotEmpty) ? v : fb;
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _uid.isEmpty) {
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
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.mutedText)),
          ],
        )),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(_uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F4F6),
            body: Center(child: CircularProgressIndicator(
                color: AppColors.brandRed, strokeWidth: 2.5)),
          );
        }
        if (snap.hasError) {
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
                Text(snap.error.toString(),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.mutedText),
                    textAlign: TextAlign.center),
              ]),
            )),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F4F6),
            body: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Profile not found',
                    style: GoogleFonts.inter(
                        fontSize: 16, color: AppColors.mutedText)),
              ],
            )),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>;
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

    final experiences    = _safeList(data, 'experience');
    final education      = _safeList(data, 'education');
    final skills         = _safeStrList(data, 'skills');
    final certifications = _safeList(data, 'certifications');
    final bio            = _safeOr(data, 'about', 'bio');

    final email = data['email']?.toString().trim().isNotEmpty == true
        ? data['email'].toString().trim()
        : FirebaseAuth.instance.currentUser?.email ?? '—';

    final connectionsCount = _safeInt(data, 'connectionsCount');
    final followersCount   = _safeInt(data, 'followersCount');
    final followingCount   = _safeInt(data, 'followingCount');

    final isVerified =
        _safe(data, 'status', fb: '') == 'active' ||
        _safe(data, 'verificationStatus', fb: '') == 'verified';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Pinned AppBar ────────────────────────────
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

          // ════════════════════════════════════════════
          // COVER + AVATAR HEADER CARD
          //
          // FIX: Instead of Transform.translate (which causes clipping
          // because the widget's layout box doesn't change), we use a
          // white card Container that contains both the cover image and
          // the avatar row. The avatar overlaps the cover internally
          // via a Stack + Positioned, which is fully within the same
          // layout context — no clipping occurs.
          //
          // Structure:
          //   Container (white card)
          //     ├─ Stack
          //     │    ├─ Cover image (height: _coverHeight)
          //     │    └─ Positioned(bottom: -_overlap) → avatar row
          //     └─ SizedBox(height: _overlap + avatarRadius + padding)
          //          ← compensates for the avatar poking below the Stack
          // ════════════════════════════════════════════

          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Cover + avatar (overlapping internally) ──
                  Stack(
                    clipBehavior: Clip.none,  // allow avatar to render outside Stack bounds
                    children: [
                      // Cover photo
                      SizedBox(
                        height: _coverHeight,
                        width: double.infinity,
                        child: hasCover
                            ? Stack(fit: StackFit.expand, children: [
                                CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: AppColors.softWhite),
                                  errorWidget: (_, __, ___) =>
                                      _defaultCover(),
                                ),
                                // Bottom gradient so avatar is readable
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.25),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ])
                            : _defaultCover(),
                      ),

                      // Avatar row — positioned so avatar bottom is
                      // _overlap px below the cover bottom.
                      // Clip.none on the Stack above lets it render freely.
                      Positioned(
                        bottom: -_overlap,
                        left: 20,
                        right: 20,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ── Avatar ──────────────────────────
                            GestureDetector(
                              onTap: _goToEdit,
                              child: Stack(children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: _avatarBorder,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
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
                                              placeholder: (_, __) => Container(
                                                  color: Colors.grey.shade100),
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(Icons.person,
                                                      size: 46,
                                                      color: AppColors.brandRed),
                                            ),
                                          )
                                        : const Icon(Icons.person,
                                              size: 46,
                                              color: AppColors.brandRed),
                                  ),
                                ),
                                // Camera badge
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandRed,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        size: 11, color: Colors.white),
                                  ),
                                ),
                              ]),
                            ),

                            const Spacer(),

                            // ── Edit button ──────────────────────
                            ElevatedButton.icon(
                              onPressed: _goToEdit,
                              icon: const Icon(Icons.edit_outlined, size: 13),
                              label: Text('Edit Profile',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandRed,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Spacer that compensates for the avatar overlap
                  SizedBox(height: _overlap + _avatarRadius + 14),

                  // ── Name / headline / meta ──────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + verified badge
                        Row(children: [
                          Flexible(
                            child: Text(_safe(data, 'name'),
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
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
                                Text('Verified',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green)),
                              ]),
                            ),
                          ],
                        ]),

                        const SizedBox(height: 4),

                        // Headline / role
                        if (_safeOr(data, 'headline', 'role') != '—')
                          Text(_safeOr(data, 'headline', 'role'),
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.darkText.withOpacity(0.75))),

                        // Company
                        if (_safe(data, 'company') != '—') ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.business_outlined,
                                size: 12, color: AppColors.mutedText),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(_safe(data, 'company'),
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.mutedText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ],

                        const SizedBox(height: 10),

                        // Meta chips
                        Wrap(spacing: 14, runSpacing: 6, children: [
                          if (_safe(data, 'location') != '—')
                            _MetaBit(icon: Icons.location_on_outlined,
                                text: _safe(data, 'location')),
                          if (_safeOr(data, 'batch', 'batchYear') != '—')
                            _MetaBit(icon: Icons.school_outlined,
                                text: 'Batch ${_safeOr(data, "batch", "batchYear")}'),
                          if (_safeOr(data, 'course', 'program') != '—')
                            _MetaBit(icon: Icons.auto_stories_outlined,
                                text: _safeOr(data, 'course', 'program')),
                          if (_safe(data, 'phone_number') != '—')
                            _MetaBit(icon: Icons.phone_outlined,
                                text: _safe(data, 'phone_number')),
                          _MetaBit(icon: Icons.email_outlined, text: email),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Stats row ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(children: [
                      _statBadge(connectionsCount, 'connections'),
                      _statDot(),
                      _statBadge(followersCount, 'followers'),
                      _statDot(),
                      _statBadge(followingCount, 'following'),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Personal Details ──────────────────────────
          SliverToBoxAdapter(child: _gap()),
          SliverToBoxAdapter(
            child: _buildPersonalDetailsCard(data, email)),

          // ── About ─────────────────────────────────────
          SliverToBoxAdapter(child: _gap()),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'About',
              icon: Icons.person_outline_rounded,
              onEdit: _goToEdit,
              child: bio != '—'
                  ? Text(bio,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.65,
                          color: AppColors.darkText))
                  : _emptyState(
                      'No summary added yet.', Icons.info_outline),
            ),
          ),

          // ── Activity / Posts (LinkedIn-style) ─────────
          SliverToBoxAdapter(child: _gap()),
          SliverToBoxAdapter(
            child: _ActivitySection(uid: _uid!),
          ),

          // ── Skills ────────────────────────────────────
          if (skills.isNotEmpty) ...[
            SliverToBoxAdapter(child: _gap()),
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Skills',
                icon: Icons.star_outline_rounded,
                onEdit: _goToEdit,
                child: _buildSkillsWrap(skills),
              ),
            ),
          ],

          // ── Experience ────────────────────────────────
          SliverToBoxAdapter(child: _gap()),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Experience',
              icon: Icons.work_outline_rounded,
              onEdit: _goToEdit,
              child: experiences.isNotEmpty
                  ? Column(
                      children: experiences
                          .asMap()
                          .entries
                          .map((e) => Column(children: [
                                if (e.key > 0)
                                  Divider(height: 20,
                                      color: AppColors.borderSubtle
                                          .withOpacity(0.6)),
                                _experienceCard(e.value),
                              ]))
                          .toList())
                  : _emptyState(
                      'No experience added yet.', Icons.work_outline),
            ),
          ),

          // ── Education ─────────────────────────────────
          SliverToBoxAdapter(child: _gap()),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Education',
              icon: Icons.school_outlined,
              onEdit: _goToEdit,
              child: education.isNotEmpty
                  ? Column(
                      children: education
                          .asMap()
                          .entries
                          .map((e) => Column(children: [
                                if (e.key > 0)
                                  Divider(height: 20,
                                      color: AppColors.borderSubtle
                                          .withOpacity(0.6)),
                                _educationCard(e.value),
                              ]))
                          .toList())
                  : _emptyState(
                      'No education added yet.', Icons.school_outlined),
            ),
          ),

          // ── Certifications ────────────────────────────
          if (certifications.isNotEmpty) ...[
            SliverToBoxAdapter(child: _gap()),
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Certifications',
                icon: Icons.verified_outlined,
                onEdit: _goToEdit,
                child: Column(
                    children: certifications
                        .map(_certificationCard)
                        .toList()),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // ── Personal Details card ──────────────────────────
  Widget _buildPersonalDetailsCard(
      Map<String, dynamic> data, String email) {
    final batchVal  = _safeOr(data, 'batch', 'graduationYear');
    final courseVal = _safeOr(data, 'course', 'program');
    final studentId = _safeOr(data, 'student_id', 'studentId');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Text('Personal Details',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
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
            const SizedBox(height: 14),
            _detailRow(Icons.person_outline,  'Full Name',          _safe(data, 'name')),
            _detailRow(Icons.email_outlined,  'Email',              email),
            if (_safe(data, 'phone_number') != '—')
              _detailRow(Icons.phone_outlined, 'Phone',             _safe(data, 'phone_number')),
            if (_safe(data, 'location') != '—')
              _detailRow(Icons.location_on_outlined, 'Location',    _safe(data, 'location')),
            if (_safeOr(data, 'role', 'userType') != '—')
              _detailRow(Icons.badge_outlined, 'Role',              _safeOr(data, 'role', 'userType')),
            if (batchVal != '—')
              _detailRow(Icons.calendar_today_outlined,
                  'Batch / Graduation Year', batchVal),
            if (courseVal != '—')
              _detailRow(Icons.menu_book_outlined, 'Course / Program', courseVal),
            if (studentId != '—')
              _detailRow(Icons.tag_outlined, 'Student ID', studentId,
                  isLast: true),
          ],
        ),
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────

  Widget _gap() => const SizedBox(height: 12);

  Widget _detailRow(IconData icon, String label, String value,
      {bool isLast = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: AppColors.brandRed),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText)),
            ],
          )),
        ]),
      ),
      if (!isLast)
        const Divider(height: 1, thickness: 0.4, color: AppColors.borderSubtle),
    ]);
  }

  Widget _buildSkillsWrap(List<String> skills) {
    return Wrap(spacing: 8, runSpacing: 8,
      children: skills.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.brandRed.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brandRed.withOpacity(0.25)),
        ),
        child: Text(s,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brandRed)),
      )).toList(),
    );
  }

  Widget _experienceCard(Map<String, dynamic> exp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.work_outline,
              color: AppColors.brandRed, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_mm(exp, 'title'),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(_mm(exp, 'company'),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_fmtPeriod(exp['start'], exp['end']),
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText)),
            if (_mm(exp, 'location') != '—') ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 11, color: AppColors.mutedText),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(_mm(exp, 'location'),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.mutedText)),
                ),
              ]),
            ],
            if (_mm(exp, 'description') != '—') ...[
              const SizedBox(height: 6),
              Text(_mm(exp, 'description'),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.darkText.withOpacity(0.8),
                      height: 1.5)),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _educationCard(Map<String, dynamic> edu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.school_outlined,
              color: AppColors.brandRed, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_mm(edu, 'degree'),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(_mm(edu, 'school'),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_fmtPeriod(edu['start'], edu['end']),
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText)),
            if (_mm(edu, 'fieldOfStudy') != '—') ...[
              const SizedBox(height: 2),
              Text(_mm(edu, 'fieldOfStudy'),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.mutedText)),
            ],
            if (_mm(edu, 'grade') != '—') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.military_tech_outlined,
                      size: 12, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(_mm(edu, 'grade'),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.verified_outlined,
              color: AppColors.brandRed, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_mm(cert, 'name'),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            if (_mm(cert, 'issuer') != '—') ...[
              const SizedBox(height: 2),
              Text(_mm(cert, 'issuer'),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w500)),
            ],
            if (_mm(cert, 'year') != '—' || cert['date'] != null) ...[
              const SizedBox(height: 2),
              Text(_mm(cert, 'year',
                      fb: _fmtDate(cert['date'])),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.mutedText)),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _emptyState(String msg, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(children: [
      Icon(icon, size: 20, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Flexible(child: Text(msg,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.mutedText))),
    ]),
  );

  Widget _defaultCover() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF5C0000),
          Color(0xFFB22222),
          Color(0xFFCC4444),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );

  Widget _statBadge(int count, String label) {
    final display = count >= 1000
        ? '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k'
        : count.toString();
    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: display,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        TextSpan(
            text: ' $label',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
      ]),
    );
  }

  Widget _statDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(
        width: 3, height: 3,
        decoration: BoxDecoration(
            color: AppColors.mutedText.withOpacity(0.4),
            shape: BoxShape.circle)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY SECTION
// Shows the user's approved achievement posts — LinkedIn "Activity" style.
// ─────────────────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  final String uid;
  const _ActivitySection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('achievement_posts')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snap) {
        // Hide section if no posts at all
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snap.data!.docs;
        final approved = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'];
          return s == 'approved';
        }).toList();
        final pending = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'];
          return s == 'pending';
        }).length;
        final rejected = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'];
          return s == 'rejected';
        }).length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section header ──────────────────────
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.brandRed.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.emoji_events_outlined,
                        size: 17, color: AppColors.brandRed),
                  ),
                  const SizedBox(width: 10),
                  Text('Activity',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText)),
                  const Spacer(),
                  // Status summary badges
                  if (pending > 0)
                    _StatusPill(label: '$pending pending',
                        color: Colors.orange),
                  if (rejected > 0) ...[
                    const SizedBox(width: 6),
                    _StatusPill(label: '$rejected rejected',
                        color: Colors.red),
                  ],
                ]),

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 14),

                if (approved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 18, color: Colors.orange.shade400),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          pending > 0
                              ? 'Your $pending post${pending > 1 ? "s are" : " is"} waiting for admin approval.'
                              : 'No approved posts yet.',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.mutedText,
                              height: 1.4),
                        ),
                      ),
                    ]),
                  )
                else
                  // Horizontal scrollable grid of approved posts
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: approved.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final d = approved[i].data()
                            as Map<String, dynamic>;
                        return _PostThumbnail(data: d);
                      },
                    ),
                  ),

                // "All posts" link
                if (approved.length >= 3) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/gallery'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('See all posts in gallery',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandRed)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          size: 13, color: AppColors.brandRed),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Post thumbnail card (activity grid item) ─────────────────────────────

class _PostThumbnail extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostThumbnail({required this.data});

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final title    = data['title']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final ts       = data['approvedAt'] ?? data['createdAt'];
    final dt       = ts is Timestamp ? ts.toDate() : null;
    final dateStr  = dt != null
        ? DateFormat('MMM d, yyyy').format(dt)
        : '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/gallery'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9)),
              child: SizedBox(
                height: 100,
                width: 160,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _imgPlaceholder(),
                      )
                    : _imgPlaceholder(),
              ),
            ),

            // Text
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(category.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandRed,
                              letterSpacing: 0.5)),
                    ),
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(dateStr,
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColors.mutedText)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: AppColors.borderSubtle,
    child: const Center(
      child: Icon(Icons.emoji_events_outlined,
          color: AppColors.mutedText, size: 28),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3), width: 0.5),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color)),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onEdit;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                Text(title,
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
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
                    child: const Icon(Icons.add,
                        color: AppColors.brandRed, size: 16),
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
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
      ]);
}