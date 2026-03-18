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
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    DateTime? date =
        value is Timestamp ? value.toDate() : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('MMMM yyyy').format(date) : '—';
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    return end == null ? '$s – Present' : '$s – $e';
  }

  String _safeMap(Map<String, dynamic>? map, String key, {String fallback = '—'}) {
    final val = map?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Profile not found',
            style: GoogleFonts.inter(fontSize: 16, color: AppColors.mutedText),
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

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // ─── Cover Photo + AppBar ───
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            title: Text(
              'My Profile',
              style: GoogleFonts.cormorantGaramond(fontSize: 24),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ).then((_) => _loadUserProfile());
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover photo
                  hasCover
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.softWhite),
                          errorWidget: (context, url, error) => _defaultCover(),
                        )
                      : _defaultCover(),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Profile Content ───
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ─── Avatar overlapping cover ───
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardWhite, width: 5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: AppColors.borderSubtle,
                          child: hasAvatar
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    width: 130,
                                    height: 130,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(strokeWidth: 2),
                                    errorWidget: (context, url, error) => const Icon(
                                      Icons.person,
                                      size: 70,
                                      color: AppColors.brandRed,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 70,
                                  color: AppColors.brandRed,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ─── Name & Headline ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              _safe('name'),
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 34,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _safe('headline', fallback: _safe('role')),
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            if (_safe('location') != '—')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 15, color: AppColors.mutedText),
                                  const SizedBox(width: 4),
                                  Text(
                                    _safe('location'),
                                    style: GoogleFonts.inter(
                                        fontSize: 14, color: AppColors.mutedText),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Text(
                              '${_safe('connectionsCount', fallback: '0')} connections  •  ${_safe('followersCount', fallback: '0')} followers',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.mutedText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Sections ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // About
                      _sectionTitle('About'),
                      const SizedBox(height: 10),
                      Text(
                        _safe('about', fallback: 'No professional summary added yet.'),
                        style: GoogleFonts.inter(fontSize: 15, height: 1.6),
                      ),

                      const SizedBox(height: 48),

                      // Experience
                      _sectionTitle('Experience'),
                      const SizedBox(height: 16),
                      if (experiences.isNotEmpty)
                        ...experiences.map(_experienceCard)
                      else
                        _emptyCard('No experience added yet'),

                      const SizedBox(height: 48),

                      // Education
                      _sectionTitle('Education'),
                      const SizedBox(height: 16),
                      if (education.isNotEmpty)
                        ...education.map(_educationCard)
                      else
                        _emptyCard('No education added yet'),
                    ],
                  ),
                ),
              ],
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
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: AppColors.darkText,
        ),
      );

  Widget _experienceCard(Map<String, dynamic> exp) => Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_safeMap(exp, 'title'), style: _titleStyle),
              const SizedBox(height: 4),
              Text(_safeMap(exp, 'company'), style: _companyStyle),
              Text(_formatPeriod(exp['start'], exp['end']), style: _dateStyle),
              if (_safeMap(exp, 'location') != '—') ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.mutedText),
                    const SizedBox(width: 4),
                    Text(_safeMap(exp, 'location'), style: _dateStyle),
                  ],
                ),
              ],
              if (_safeMap(exp, 'description') != '—') ...[
                const SizedBox(height: 10),
                Text(_safeMap(exp, 'description'), style: _bodyStyle),
              ],
            ],
          ),
        ),
      );

  Widget _educationCard(Map<String, dynamic> edu) => Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_safeMap(edu, 'degree'), style: _titleStyle),
              const SizedBox(height: 4),
              Text(_safeMap(edu, 'school'), style: _companyStyle),
              Text(_formatPeriod(edu['start'], edu['end']), style: _dateStyle),
              if (_safeMap(edu, 'fieldOfStudy') != '—') ...[
                const SizedBox(height: 4),
                Text(_safeMap(edu, 'fieldOfStudy'), style: _bodyStyle),
              ],
              if (_safeMap(edu, 'grade') != '—') ...[
                const SizedBox(height: 4),
                Text('Grade: ${_safeMap(edu, 'grade')}', style: _dateStyle),
              ],
            ],
          ),
        ),
      );

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Center(
          child: Text(
            msg,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
          ),
        ),
      );

  TextStyle get _titleStyle =>
      GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700);

  TextStyle get _companyStyle => GoogleFonts.inter(
      fontSize: 15, color: AppColors.brandRed, fontWeight: FontWeight.w600);

  TextStyle get _dateStyle =>
      GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText);

  TextStyle get _bodyStyle =>
      GoogleFonts.inter(fontSize: 14.5, height: 1.6);
}