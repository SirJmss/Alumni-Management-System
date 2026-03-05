import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Load profile after first frame (prevents UI lag)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        userData = doc.data();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Profile load error: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _safeList(String key) {
    final list = userData?[key];

    if (list == null || list is! List) return [];

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _safe(String key, {String fallback = '—'}) {
    final val = userData?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  String _safeMap(Map<String, dynamic>? map, String key,
      {String fallback = '—'}) {
    final val = map?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    return date != null ? DateFormat('MMMM yyyy').format(date) : '—';
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    return end == null ? '$startStr – Present' : '$startStr – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        body: const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.brandRed,
            ),
          ),
        ),
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

    final bool hasCover = coverUrl != '—';
    final bool hasAvatar = avatarUrl != '—';

    final experiences = _safeList('experience');
    final education = _safeList('education');

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  hasCover
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultCover(),
                        )
                      : _defaultCover(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 80),

                /// PROFILE HEADER
                Center(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.cardWhite, width: 5),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 16,
                                offset: Offset(0, 8))
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: AppColors.borderSubtle,
                          backgroundImage:
                              hasAvatar ? NetworkImage(avatarUrl) : null,
                          child: !hasAvatar
                              ? Icon(Icons.person,
                                  size: 110,
                                  color: AppColors.brandRed.withOpacity(0.65))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _safe('name'),
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 36, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _safe('headline', fallback: _safe('role')),
                        style: GoogleFonts.inter(
                            fontSize: 19, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _safe('location'),
                        style: GoogleFonts.inter(
                            fontSize: 15, color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '• ${_safe('connectionsCount', fallback: '0')} connections • ${_safe('followersCount', fallback: '0')} followers',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                _sectionTitle('About'),
                const SizedBox(height: 10),
                Text(
                  _safe('about',
                      fallback: 'No professional summary added yet.'),
                  style: GoogleFonts.inter(fontSize: 15, height: 1.55),
                ),

                const SizedBox(height: 50),

                /// EXPERIENCE
                _sectionTitle('Experience'),
                const SizedBox(height: 16),

                if (experiences.isNotEmpty)
                  ...experiences.map((e) => _experienceCard(e))
                else
                  _emptyCard('No experience added yet'),

                const SizedBox(height: 50),

                /// EDUCATION
                _sectionTitle('Education'),
                const SizedBox(height: 16),

                if (education.isNotEmpty)
                  ...education.map((e) => _educationCard(e))
                else
                  _emptyCard('No education added yet'),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.brandRed.withOpacity(0.3), AppColors.softWhite],
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_safeMap(exp, 'title'), style: _titleStyle),
            const SizedBox(height: 4),
            Text(_safeMap(exp, 'company'), style: _companyStyle),
            Text(_formatPeriod(exp['start'], exp['end']), style: _dateStyle),
            if (_safeMap(exp, 'description') != '—') ...[
              const SizedBox(height: 10),
              Text(_safeMap(exp, 'description'), style: _bodyStyle)
            ]
          ]),
        ),
      );

  Widget _educationCard(Map<String, dynamic> edu) => Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_safeMap(edu, 'degree'), style: _titleStyle),
            const SizedBox(height: 4),
            Text(_safeMap(edu, 'school'), style: _companyStyle),
            Text(_formatPeriod(edu['start'], edu['end']), style: _dateStyle),
          ]),
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
          child: Text(msg,
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.mutedText)),
        ),
      );

  TextStyle get _titleStyle =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700);

  TextStyle get _companyStyle => GoogleFonts.inter(
      fontSize: 16, color: AppColors.brandRed, fontWeight: FontWeight.w600);

  TextStyle get _dateStyle =>
      GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText);

  TextStyle get _bodyStyle =>
      GoogleFonts.inter(fontSize: 14.5, height: 1.5);
}