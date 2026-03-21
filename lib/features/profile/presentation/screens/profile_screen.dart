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
  State<AlumniProfileScreen> createState() => _AlumniProfileScreenState();
}

class _AlumniProfileScreenState extends State<AlumniProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _safe(String key, {String fallback = '—'}) {
    final val = userData?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  List<Map<String, dynamic>> _safeList(String key) {
    final list = userData?[key];
    if (list == null || list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    DateTime? date = value is Timestamp
        ? value.toDate()
        : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('MMMM yyyy').format(date) : '—';
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    return end == null ? '$s – Present' : '$s – $e';
  }

  String _safeMap(Map<String, dynamic>? map, String key,
      {String fallback = '—'}) {
    final val = map?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  void _goToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    ).then((_) => _loadUserProfile());
  }

  static const double _avatarRadius = 60.0;
  static const double _avatarBorder = 4.0;
  static const double _avatarTotal = _avatarRadius + _avatarBorder;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandRed),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Profile not found',
                style: GoogleFonts.inter(
                    fontSize: 16, color: AppColors.mutedText),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserProfile,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final coverUrl = _safe('coverPhotoUrl');
    final avatarUrl = _safe('profilePictureUrl');
    final hasCover = coverUrl != '—' && coverUrl.isNotEmpty;
    final hasAvatar = avatarUrl != '—' && avatarUrl.isNotEmpty;

    final experiences = _safeList('experience');
    final education = _safeList('education');

    // Resolve email from Firestore or Firebase Auth
    final email = userData?['email']?.toString().trim().isNotEmpty == true
        ? userData!['email'].toString().trim()
        : FirebaseAuth.instance.currentUser?.email ?? '—';

    const double coverHeight = 200.0;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // ─── AppBar ───
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            elevation: 0,
            title: Text(
              'My Profile',
              style: GoogleFonts.cormorantGaramond(fontSize: 24),
            ),
          ),

          // ─── Cover + Avatar ───
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: coverHeight,
                  width: double.infinity,
                  color: AppColors.softWhite,
                  child: hasCover
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.softWhite),
                          errorWidget: (context, url, error) =>
                              _defaultCover(),
                        )
                      : _defaultCover(),
                ),
                Positioned(
                  bottom: -_avatarTotal,
                  left: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.softWhite,
                        width: _avatarBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
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
                                width: _avatarRadius * 2,
                                height: _avatarRadius * 2,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(
                                        strokeWidth: 2),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person,
                                        size: 60,
                                        color: AppColors.brandRed),
                              ),
                            )
                          : const Icon(Icons.person,
                              size: 60, color: AppColors.brandRed),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Space for avatar overflow ───
          const SliverToBoxAdapter(
            child: SizedBox(height: _avatarTotal + 12),
          ),

          // ─── Name, headline, info + Edit button ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _safe('name'),
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _goToEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandRed,
                          side: const BorderSide(color: AppColors.brandRed),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (_safe('headline') != '—')
                    Text(
                      _safe('headline', fallback: _safe('role')),
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (_safe('location') != '—')
                        _infoChip(Icons.location_on_outlined,
                            _safe('location')),
                      if (_safe('phone_number') != '—')
                        _infoChip(
                            Icons.phone_outlined, _safe('phone_number')),
                      if (email != '—')
                        _infoChip(Icons.email_outlined, email),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _statBadge(
                          _safe('connectionsCount', fallback: '0'),
                          'connections'),
                      const SizedBox(width: 12),
                      _statBadge(
                          _safe('followersCount', fallback: '0'),
                          'followers'),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ─── Personal Details Card ───
          SliverToBoxAdapter(
            child: Container(
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
                      value: _safe('name'),
                    ),
                    _detailDivider(),
                    _detailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email,
                    ),
                    if (_safe('phone_number') != '—') ...[
                      _detailDivider(),
                      _detailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: _safe('phone_number'),
                      ),
                    ],
                    if (_safe('location') != '—') ...[
                      _detailDivider(),
                      _detailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: _safe('location'),
                      ),
                    ],
                    if (_safe('role') != '—') ...[
                      _detailDivider(),
                      _detailRow(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: _safe('role'),
                      ),
                    ],
                    if (_safe('batch') != '—' ||
                        _safe('graduationYear') != '—') ...[
                      _detailDivider(),
                      _detailRow(
                        icon: Icons.school_outlined,
                        label: 'Batch / Year',
                        value:
                            '${_safe('batch', fallback: '')} ${_safe('graduationYear', fallback: '')}'
                                .trim(),
                      ),
                    ],
                    if (_safe('course') != '—' ||
                        _safe('program') != '—') ...[
                      _detailDivider(),
                      _detailRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Course / Program',
                        value: _safe('course',
                            fallback: _safe('program')),
                      ),
                    ],
                    if (_safe('student_id') != '—' ||
                        _safe('studentId') != '—') ...[
                      _detailDivider(),
                      _detailRow(
                        icon: Icons.tag_outlined,
                        label: 'Student ID',
                        value: _safe('student_id',
                            fallback: _safe('studentId')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── About ───
          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'About',
              child: Text(
                _safe('about',
                    fallback: 'No professional summary added yet.'),
                style: GoogleFonts.inter(fontSize: 15, height: 1.6),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── Experience ───
          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'Experience',
              child: experiences.isNotEmpty
                  ? Column(
                      children: experiences.map(_experienceCard).toList(),
                    )
                  : _emptyState(
                      'No experience added yet', Icons.work_outline),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── Education ───
          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'Education',
              child: education.isNotEmpty
                  ? Column(
                      children: education.map(_educationCard).toList(),
                    )
                  : _emptyState(
                      'No education added yet', Icons.school_outlined),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─── Detail row ───
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

  Widget _detailDivider() => Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.borderSubtle,
      );

  // ─── Section card wrapper ───
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
                _sectionTitle(title),
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

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(
          label,
          style:
              GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
        ),
      ],
    );
  }

  Widget _statBadge(String count, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: count,
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandRed.withOpacity(0.4),
              AppColors.softWhite,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      );

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
                  Text(_formatPeriod(exp['start'], exp['end']),
                      style: _dateStyle),
                  if (_safeMap(exp, 'location') != '—') ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 3),
                        Text(_safeMap(exp, 'location'),
                            style: _dateStyle),
                      ],
                    ),
                  ],
                  if (_safeMap(exp, 'description') != '—') ...[
                    const SizedBox(height: 8),
                    Text(_safeMap(exp, 'description'),
                        style: _bodyStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

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
                  Text(_formatPeriod(edu['start'], edu['end']),
                      style: _dateStyle),
                  if (_safeMap(edu, 'fieldOfStudy') != '—') ...[
                    const SizedBox(height: 2),
                    Text(_safeMap(edu, 'fieldOfStudy'),
                        style: _bodyStyle),
                  ],
                  if (_safeMap(edu, 'grade') != '—') ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.military_tech_outlined,
                            size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 3),
                        Text('Grade: ${_safeMap(edu, 'grade')}',
                            style: _dateStyle),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _emptyState(String msg, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text(
              msg,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.mutedText),
            ),
          ],
        ),
      );

  TextStyle get _titleStyle =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700);

  TextStyle get _companyStyle => GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.brandRed,
      fontWeight: FontWeight.w600);

  TextStyle get _dateStyle =>
      GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText);

  TextStyle get _bodyStyle =>
      GoogleFonts.inter(fontSize: 13.5, height: 1.6);
}