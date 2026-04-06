import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/notification/notification_screen.dart';
import 'package:alumni/features/notification/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  // ─── User profile ─────────────────────────────
  String userName = 'Guest';
  String userRole = 'Alumni';
  String userBatch = '';
  String userCourse = '';
  String userLocation = '';
  String userOccupation = '';
  String userCompany = '';
  String userAbout = '';
  String userPhone = '';
  String? userPhotoUrl;
  String userStatus = 'pending';
  String userVerificationStatus = 'pending';
  bool isLoadingProfile = true;

  // ─── Metrics ──────────────────────────────────
  int totalAlumni = 0;
  int upcomingEvents = 0;
  int activeCourses = 0;

  // ─── Content ──────────────────────────────────
  List<Map<String, dynamic>> recentOpportunities = [];
  List<Map<String, dynamic>> upcomingCalendar = [];
  List<Map<String, dynamic>> nearbyAlumni = [];
  List<Map<String, dynamic>> recentAnnouncements = [];

  bool isLoadingData = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      isLoadingProfile = true;
      isLoadingData = true;
      errorMessage = null;
    });
    try {
      await Future.wait([
        _loadUserProfile(),
        _loadDashboardAggregates(),
        _loadRecentOpportunities(),
        _loadUpcomingCalendar(),
        _loadNearbyAlumni(),
        _loadRecentAnnouncements(),
      ]);
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingProfile = false;
        isLoadingData = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        userName = 'Guest';
        userRole = 'Visitor';
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() {
          userName =
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : 'Member';
          userRole = 'Alumni';
          userPhotoUrl = user.photoURL;
        });
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};
      String getStr(String key, {String fallback = ''}) {
        final val = data[key]?.toString().trim();
        return (val != null && val.isNotEmpty)
            ? val
            : fallback;
      }

      setState(() {
        userName = getStr('fullName',
            fallback: getStr('name',
                fallback: user.displayName ?? 'Member'));
        userRole = getStr('role', fallback: 'Alumni');
        final photo = getStr('profilePictureUrl',
            fallback: user.photoURL ?? '');
        userPhotoUrl = photo.isNotEmpty ? photo : null;
        userBatch = getStr('batch',
            fallback: getStr('batchYear'));
        userCourse = getStr('course',
            fallback: getStr('program'));
        userLocation = getStr('location');
        userOccupation = getStr('occupation');
        userCompany = getStr('company');
        userAbout = getStr('about');
        userPhone = getStr('phone');
        userStatus = getStr('status',
            fallback: 'pending');
        userVerificationStatus =
            getStr('verificationStatus',
                fallback: 'pending');
      });
    } catch (e) {
      debugPrint('Profile error: $e');
      if (!mounted) return;
      setState(() {
        errorMessage ??=
            'Could not load your profile. Pull to refresh.';
      });
    }
  }

  Future<void> _loadDashboardAggregates() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = Timestamp.now();
      final results = await Future.wait([
        firestore.collection('users').count().get(),
        firestore
            .collection('events')
            .where('startDate', isGreaterThan: now)
            .count()
            .get(),
        firestore.collection('courses').count().get(),
      ]);
      if (!mounted) return;
      setState(() {
        totalAlumni = results[0].count ?? 0;
        upcomingEvents = results[1].count ?? 0;
        activeCourses = results[2].count ?? 0;
      });
    } catch (e) {
      debugPrint('Aggregates error: $e');
    }
  }

  Future<void> _loadRecentOpportunities() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('opportunities')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      if (!mounted) return;
      setState(() {
        recentOpportunities = snap.docs.map((doc) {
          final data = doc.data();
          String get(String key, String fallback) {
            final v = data[key]?.toString().trim();
            return (v != null && v.isNotEmpty)
                ? v
                : fallback;
          }

          return {
            'id': doc.id,
            'title': get('title', 'Opportunity'),
            'type': get('type', 'Full-time'),
            'location': get('location', 'Remote'),
            'company': get('company', 'Confidential'),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Opportunities error: $e');
    }
  }

  Future<void> _loadUpcomingCalendar() async {
    try {
      final now = Timestamp.now();
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('startDate', isGreaterThan: now)
          .orderBy('startDate')
          .limit(5)
          .get();
      if (!mounted) return;
      setState(() {
        upcomingCalendar = snap.docs.map((doc) {
          final data = doc.data();
          final ts = data['startDate'];
          DateTime? date;
          if (ts is Timestamp) date = ts.toDate();
          final title =
              (data['title']?.toString().trim().isNotEmpty ??
                      false)
                  ? data['title'].toString().trim()
                  : 'Upcoming event';
          return {
            'id': doc.id,
            'title': title,
            'date': date != null
                ? DateFormat('MMM dd').format(date)
                : 'TBD',
            'day': date != null
                ? DateFormat('dd').format(date)
                : '––',
            'month': date != null
                ? DateFormat('MMM').format(date)
                : '',
            'type': data['type']?.toString() ??
                'Campus event',
            'location':
                data['location']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Calendar error: $e');
    }
  }

  Future<void> _loadNearbyAlumni() async {
    try {
      final currentUid =
          FirebaseAuth.instance.currentUser?.uid ?? '';
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'alumni')
          .where('status', isEqualTo: 'active')
          .limit(20)
          .get();
      if (!mounted) return;
      final filtered = snap.docs
          .where((d) => d.id != currentUid)
          .take(8)
          .map((d) {
        final data = d.data();
        String get(String key) =>
            data[key]?.toString().trim() ?? '';
        return {
          'uid': d.id,
          'name': get('name').isNotEmpty
              ? get('name')
              : 'Alumni',
          'headline': get('headline').isNotEmpty
              ? get('headline')
              : (get('course').isNotEmpty
                  ? get('course')
                  : 'Alumni'),
          'batch': get('batch'),
          'course': get('course'),
          'avatarUrl': get('profilePictureUrl'),
          'location': get('location'),
        };
      }).toList();
      setState(() => nearbyAlumni = filtered);
    } catch (e) {
      debugPrint('Nearby alumni error: $e');
    }
  }

  Future<void> _loadRecentAnnouncements() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      if (!mounted) return;
      setState(() {
        recentAnnouncements = snap.docs.map((doc) {
          final data = doc.data();
          final ts = data['createdAt'];
          DateTime? date;
          if (ts is Timestamp) date = ts.toDate();
          return {
            'id': doc.id,
            'title': data['title']?.toString() ??
                'Announcement',
            'body': data['body']?.toString() ??
                data['content']?.toString() ??
                '',
            'category':
                data['category']?.toString() ?? '',
            'date': date != null
                ? DateFormat('MMM dd, yyyy')
                    .format(date)
                : '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Announcements error: $e');
    }
  }

  // ─── Connection actions ────────────────────────

  Future<void> _sendConnectionRequest(
      String toUid, String toName) async {
    final fromUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    if (fromUid.isEmpty) return;

    // ─── Validation: check not already connected ───
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .doc(fromUid)
        .collection('connections')
        .doc(toUid)
        .get();
    if (existing.exists) {
      if (mounted) {
        _showSnackBar('Already connected with $toName',
            isError: false);
      }
      return;
    }

    // ─── Validation: check no pending request ───
    final pendingReq = await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc('${fromUid}_$toUid')
        .get();
    if (pendingReq.exists) {
      if (mounted) {
        _showSnackBar(
            'Request already sent to $toName',
            isError: false);
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${fromUid}_$toUid')
          .set({
        'fromUid': fromUid,
        'toUid': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final fromDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .get();
      final fromName =
          fromDoc.data()?['name']?.toString() ??
              'Someone';

      await NotificationService.sendFriendRequestNotification(
        toUid: toUid,
        fromName: fromName,
        fromUid: fromUid,
      );

      if (mounted) {
        _showSnackBar('Request sent to $toName!',
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _followAlumni(
      String toUid, String toName) async {
    final fromUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    if (fromUid.isEmpty) return;

    // ─── Validation: already following? ───
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .doc(fromUid)
        .collection('following')
        .doc(toUid)
        .get();
    if (existing.exists) {
      if (mounted) {
        _showSnackBar('Already following $toName',
            isError: false);
      }
      return;
    }

    try {
      final now = FieldValue.serverTimestamp();
      final batch =
          FirebaseFirestore.instance.batch();

      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(fromUid)
            .collection('following')
            .doc(toUid),
        {'followedAt': now},
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(toUid)
            .collection('followers')
            .doc(fromUid),
        {'followedAt': now},
      );
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(toUid),
        {'followersCount': FieldValue.increment(1)},
      );
      await batch.commit();

      if (mounted) {
        _showSnackBar('Now following $toName!',
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String msg,
      {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text('Log Out',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    }
  }

  // ─── Profile completeness ──────────────────────

  int get _profileCompletion {
    int score = 0;
    if (userName.isNotEmpty) score += 15;
    if (userPhotoUrl != null) score += 20;
    if (userBatch.isNotEmpty) score += 15;
    if (userCourse.isNotEmpty) score += 15;
    if (userLocation.isNotEmpty) score += 10;
    if (userOccupation.isNotEmpty) score += 10;
    if (userAbout.isNotEmpty) score += 10;
    if (userPhone.isNotEmpty) score += 5;
    return score;
  }

  List<String> get _missingFields {
    final missing = <String>[];
    if (userPhotoUrl == null) missing.add('profile photo');
    if (userLocation.isEmpty) missing.add('location');
    if (userOccupation.isEmpty) missing.add('occupation');
    if (userAbout.isEmpty) missing.add('about section');
    if (userPhone.isEmpty) missing.add('phone number');
    return missing;
  }

  bool get isAdmin =>
      userRole.toLowerCase() == 'admin' ||
      userRole.toLowerCase() == 'staff' ||
      userRole.toLowerCase() == 'moderator' ||
      userRole.toLowerCase() == 'registrar';

  bool get isVerified =>
      userStatus == 'active' &&
      userVerificationStatus == 'verified';

  bool get isPending =>
      userStatus == 'pending' ||
      userVerificationStatus == 'pending';

  bool get isRejected =>
      userStatus == 'rejected' ||
      userStatus == 'denied' ||
      userVerificationStatus == 'rejected';

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isLoading = isLoadingProfile || isLoadingData;
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    String firstName() {
      if (userName.trim().isEmpty) return 'there';
      return userName.trim().split(' ').first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
        title: Text(
          'Alumni',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppColors.brandRed,
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: NotificationService.unreadCountStream(
                currentUid),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Notifications',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.darkText,
                      size: 24,
                    ),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding:
                              const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.brandRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99
                                ? '99+'
                                : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const NotificationsScreen(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: AppColors.brandRed,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandRed,
                  strokeWidth: 2.5,
                ),
              )
            : CustomScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Hero ───
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child:
                          _buildHeroSection(firstName()),
                    ),
                  ),

                  // ─── Verification / Rejection banner ───
                  if (isPending || isRejected)
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                              20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child:
                            _buildVerificationBanner(),
                      ),
                    ),

                  // ─── Profile completion (only for verified) ───
                  if (isVerified &&
                      _profileCompletion < 80)
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                              20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child:
                            _buildProfileCompletionBanner(),
                      ),
                    ),

                  // ─── Quick actions ───
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildQuickActionsRow(
                          currentUid),
                    ),
                  ),

                  // ─── Metrics ───
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildMetricsRow(),
                    ),
                  ),

                  // ─── Friend requests ───
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _FriendRequestsBanner(
                          currentUid: currentUid),
                    ),
                  ),

                  // ─── Upcoming Events ───
                  if (upcomingCalendar.isNotEmpty)
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                              20, 8, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child:
                            _buildUpcomingEventsSection(),
                      ),
                    ),

                  // ─── Announcements ───
                  if (recentAnnouncements.isNotEmpty)
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                              20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child:
                            _buildAnnouncementsSection(),
                      ),
                    ),

                  // ─── Opportunities ───
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child:
                          _buildOpportunitiesSection(),
                    ),
                  ),

                  // ─── Alumni Network ───
                  if (nearbyAlumni.isNotEmpty)
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                              20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child:
                            _buildAlumniNetworkSection(
                                currentUid),
                      ),
                    ),

                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 40),
                    sliver: SliverToBoxAdapter(
                        child: SizedBox()),
                  ),
                ],
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  SECTION BUILDERS
  // ══════════════════════════════════════════════

  Widget _buildHeroSection(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back,',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText)),
        const SizedBox(height: 4),
        Text(firstName,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 36,
              height: 1.0,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            )),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (userBatch.isNotEmpty)
              _buildBadge(Icons.school_outlined,
                  'Class of $userBatch'),
            if (userCourse.isNotEmpty)
              _buildBadge(Icons.auto_stories_outlined,
                  userCourse),
            if (userLocation.isNotEmpty)
              _buildBadge(Icons.location_on_outlined,
                  userLocation),
            _buildBadge(
                Icons.verified_user_outlined, userRole),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amber.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size: 16,
                  color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(errorMessage!,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.amber.shade900)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ─── Verification Status Banner ───────────────
  Widget _buildVerificationBanner() {
    if (isRejected) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.red.shade200),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_outlined,
                color: Colors.red.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text('Application Rejected',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700)),
                const SizedBox(height: 2),
                Text(
                    'Your application was not approved. Contact support for more information.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.red.shade600,
                        height: 1.4)),
              ],
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.pending_outlined,
              color: Colors.orange.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text('Verification Pending',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade700)),
              const SizedBox(height: 2),
              Text(
                  'Your account is under review. You\'ll be notified once approved.',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                      height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.access_time,
            color: Colors.orange.shade400, size: 18),
      ]),
    );
  }

  // ─── Profile Completion Banner ─────────────────
  Widget _buildProfileCompletionBanner() {
    final pct = _profileCompletion;
    final missing = _missingFields;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text('Complete your profile',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
              Text('$pct%',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandRed)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor:
                  AppColors.borderSubtle,
              valueColor:
                  const AlwaysStoppedAnimation(
                      AppColors.brandRed),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          if (missing.isNotEmpty)
            Text(
                'Add your ${missing.take(2).join(', ')}${missing.length > 2 ? ' and more' : ''} to be more visible to the alumni network.',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedText,
                    height: 1.4)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, '/edit_profile'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('COMPLETE PROFILE',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.brandRed)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward,
                    size: 12,
                    color: AppColors.brandRed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────
  Widget _buildQuickActionsRow(String currentUid) {
    return StreamBuilder<int>(
      stream: NotificationService.unreadCountStream(
          currentUid),
      builder: (context, snapshot) {
        final notifCount = snapshot.data ?? 0;
        return SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActionCircle(
                  'Network',
                  Icons.people_outline,
                  () => Navigator.pushNamed(
                      context, '/friends')),
              _buildActionCircle(
                  'Messages',
                  Icons.mail_outline,
                  () => Navigator.pushNamed(
                      context, '/messages')),
              _buildActionCircle(
                'Alerts',
                Icons.notifications_none_rounded,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const NotificationsScreen()),
                ),
                badge: notifCount,
              ),
              _buildActionCircle(
                  'Events',
                  Icons.event_outlined,
                  () => Navigator.pushNamed(
                      context, '/events')),
              _buildActionCircle(
                  'Discuss',
                  Icons.forum_outlined,
                  () => Navigator.pushNamed(
                      context, '/discussions')),
              _buildActionCircle(
                  'Profile',
                  Icons.person_outline,
                  () => Navigator.pushNamed(
                      context, '/profile')),
            ],
          ),
        );
      },
    );
  }

  // ─── Metrics Row ───────────────────────────────
  Widget _buildMetricsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(totalAlumni, 'Members'),
          Container(
              width: 0.7,
              height: 32,
              color: AppColors.borderSubtle),
          _buildStatItem(upcomingEvents, 'Events'),
          Container(
              width: 0.7,
              height: 32,
              color: AppColors.borderSubtle),
          _buildStatItem(activeCourses, 'Courses'),
        ],
      ),
    );
  }

  // ─── Upcoming Events ───────────────────────────
  Widget _buildUpcomingEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Upcoming Events',
          'VIEW ALL',
          onTap: () =>
              Navigator.pushNamed(context, '/events'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcomingCalendar.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final event = upcomingCalendar[i];
              return _eventCard(event);
            },
          ),
        ),
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/events'),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      AppColors.brandRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(children: [
                  Text(
                    event['day'].toString(),
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandRed,
                        height: 1.0),
                  ),
                  Text(
                    event['month'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandRed,
                        letterSpacing: 0.5),
                  ),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (event['type'] ?? '')
                      .toString()
                      .toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedText,
                      letterSpacing: 0.5),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              event['title'].toString(),
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((event['location'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 10, color: AppColors.mutedText),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    event['location'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.mutedText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Announcements ─────────────────────────────
  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Announcements',
          'VIEW ALL',
          onTap: () => Navigator.pushNamed(
              context, '/announcements'),
        ),
        const SizedBox(height: 16),
        ...recentAnnouncements
            .map(_announcementCard),
      ],
    );
  }

  Widget _announcementCard(
      Map<String, dynamic> ann) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
          context, '/announcements'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
                Icons.campaign_outlined,
                color: AppColors.brandRed,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  ann['title'].toString(),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((ann['body'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ann['body'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedText,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if ((ann['date'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ann['date'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.mutedText, size: 18),
        ]),
      ),
    );
  }

  // ─── Opportunities ─────────────────────────────
  Widget _buildOpportunitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Recommended for you',
          'VIEW ALL',
          onTap: () => Navigator.pushNamed(
              context, '/events'),
        ),
        const SizedBox(height: 16),
        if (recentOpportunities.isEmpty)
          _buildEmptyState('No opportunities listed')
        else
          ...recentOpportunities
              .map(_opportunityCard),
      ],
    );
  }

  // ─── Alumni Network ────────────────────────────
  Widget _buildAlumniNetworkSection(
      String currentUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Alumni You May Know',
          'SEE ALL',
          onTap: () => Navigator.pushNamed(
              context, '/friends'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: nearbyAlumni.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final alumni = nearbyAlumni[i];
              return _alumniNetworkCard(
                  alumni, currentUid);
            },
          ),
        ),
      ],
    );
  }

  Widget _alumniNetworkCard(
      Map<String, dynamic> alumni,
      String currentUid) {
    final toUid = alumni['uid'].toString();
    final name = alumni['name'].toString();
    final avatarUrl = alumni['avatarUrl'].toString();
    final headline = alumni['headline'].toString();
    final batch = alumni['batch'].toString();

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // ─── Avatar ───
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.borderSubtle,
            child: avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person,
                              color: AppColors.brandRed,
                              size: 28),
                    ),
                  )
                : Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 10),

          // ─── Name ───
          Text(
            name,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // ─── Headline / Course ───
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              headline,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.mutedText),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ─── Batch ───
          if (batch.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Batch $batch',
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandRed),
              ),
            ),
          ],

          const Spacer(),

          // ─── Connect button ───
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  _sendConnectionRequest(toUid, name),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8)),
              ),
              child: Text('Connect',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 6),

          // ─── Follow button ───
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  _followAlumni(toUid, name),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedText,
                side: const BorderSide(
                    color: AppColors.borderSubtle),
                padding: const EdgeInsets.symmetric(
                    vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8)),
              ),
              child: Text('Follow',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  DRAWER
  // ══════════════════════════════════════════════

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 0.5)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.borderSubtle,
                backgroundImage:
                    userPhotoUrl != null &&
                            userPhotoUrl!.isNotEmpty
                        ? NetworkImage(userPhotoUrl!)
                        : null,
                child: userPhotoUrl == null ||
                        userPhotoUrl!.isEmpty
                    ? Text(
                        userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : '?',
                        style:
                            GoogleFonts.cormorantGaramond(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandRed,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandRed
                              .withOpacity(0.08),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                          userRole.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandRed,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ─── Verification dot ───
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isVerified
                              ? Colors.green
                              : isRejected
                                  ? Colors.red
                                  : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified
                            ? 'Verified'
                            : isRejected
                                ? 'Rejected'
                                : 'Pending',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: isVerified
                                ? Colors.green
                                : isRejected
                                    ? Colors.red
                                    : Colors.orange,
                            fontWeight:
                                FontWeight.w600),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _drawerTile(Icons.dashboard_outlined,
                    'Dashboard',
                    active: true),
                _drawerTile(Icons.person_outline,
                    'My Profile',
                    route: '/profile'),
                _drawerTile(Icons.forum_outlined,
                    'Discussions',
                    route: '/discussions'),
                _drawerTile(
                    Icons.event_available_outlined,
                    'Events',
                    route: '/events'),
                _drawerTile(Icons.campaign_outlined,
                    'Announcements',
                    route: '/announcements'),
                _drawerTile(Icons.photo_library_outlined,
                    'Gallery',
                    route: '/gallery'),
                _drawerTile(Icons.message_outlined,
                    'Messages',
                    route: '/messages'),
                _drawerTile(Icons.people_outline,
                    'Friends & Network',
                    route: '/friends'),
                _drawerTile(
                  Icons.notifications_outlined,
                  'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const NotificationsScreen()),
                  ),
                  trailing: StreamBuilder<int>(
                    stream: NotificationService
                        .unreadCountStream(
                            FirebaseAuth.instance
                                    .currentUser?.uid ??
                                ''),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      if (count == 0)
                        return const SizedBox();
                      return Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandRed,
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 99
                              ? '99+'
                              : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                if (isAdmin) ...[
                  const Divider(
                      height: 24,
                      indent: 24,
                      endIndent: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        24, 4, 24, 8),
                    child: Text('ADMIN',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.mutedText,
                        )),
                  ),
                  _drawerTile(Icons.work_outline,
                      'Job Board Management',
                      route: '/job_board_management'),
                  _drawerTile(
                      Icons.bar_chart_outlined,
                      'Growth Metrics',
                      route: '/growth_metrics'),
                  _drawerTile(
                      Icons.verified_user_outlined,
                      'User Verification',
                      route:
                          '/user_verification_moderation'),
                  _drawerTile(
                      Icons.event_note_outlined,
                      'Event Planning',
                      route: '/event_planning'),
                  _drawerTile(Icons.campaign_outlined,
                      'Announcements',
                      route: '/announcement_management'),
                ],
              ],
            ),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          _drawerTile(Icons.settings_outlined,
              'Settings',
              route: '/settings'),
          _drawerTile(Icons.logout, 'Logout',
              isDestructive: true, onTap: _logout),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title, {
    String? route,
    bool active = false,
    bool isDestructive = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final color = active
        ? AppColors.brandRed
        : (isDestructive
            ? Colors.redAccent
            : AppColors.darkText);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandRed.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: color
                .withOpacity(active ? 1.0 : 0.7)),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: active
                ? FontWeight.w700
                : FontWeight.w500,
            color: color,
          )),
      trailing: trailing,
      selected: active,
      selectedTileColor:
          AppColors.brandRed.withOpacity(0.05),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }

  // ══════════════════════════════════════════════
  //  UI HELPERS
  // ══════════════════════════════════════════════

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.mutedText),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText)),
      ]),
    );
  }

  Widget _buildActionCircle(
    String label,
    IconData icon,
    VoidCallback onTap, {
    int badge = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon,
                  color: AppColors.darkText, size: 22),
            ),
            if (badge > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                      color: AppColors.brandRed,
                      shape: BoxShape.circle),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildStatItem(int value, String label) {
    return Column(children: [
      Text('$value',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600)),
      Text(label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.mutedText,
          )),
    ]);
  }

  Widget _sectionHeader(String title, String action,
      {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            )),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(action,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppColors.brandRed,
                )),
          ),
      ],
    );
  }

  Widget _opportunityCard(
      Map<String, dynamic> op) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (op['type'] ?? '').toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandRed,
                    letterSpacing: 1),
              ),
              Text(op['location'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.mutedText)),
            ],
          ),
          const SizedBox(height: 12),
          Text(op['title'] ?? '',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(op['company'] ?? '',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.mutedText)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('APPLY NOW',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.brandRed)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.brandRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 20),
        child: Text(message,
            style: GoogleFonts.inter(
                color: AppColors.mutedText,
                fontSize: 12,
                fontStyle: FontStyle.italic)),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Friend Requests Banner
// ══════════════════════════════════════════════

class _FriendRequestsBanner extends StatelessWidget {
  final String currentUid;
  const _FriendRequestsBanner(
      {required this.currentUid});

  Future<void> _accept(BuildContext context,
      String fromUid, String requestId) async {
    try {
      final now = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(fromUid)
          .set({'connectedAt': now});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .collection('connections')
          .doc(currentUid)
          .set({'connectedAt': now});

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .set(
              {'connectionsCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .set(
              {'connectionsCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      final currentUserDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .get();
      final acceptorName =
          currentUserDoc.data()?['name']?.toString() ??
              'Someone';

      await NotificationService
          .sendFriendAcceptedNotification(
        toUid: fromUid,
        acceptorName: acceptorName,
        acceptorUid: currentUid,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Connection accepted!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decline(BuildContext context,
      String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUid', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs;

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Friend Requests',
                  style:
                      GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  '${requests.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ...requests.map((doc) {
              final data =
                  doc.data() as Map<String, dynamic>;
              final fromUid =
                  data['fromUid']?.toString() ?? '';
              final requestId = doc.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(fromUid)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 8),
                      child: LinearProgressIndicator(
                          color: AppColors.brandRed),
                    );
                  }

                  final user =
                      userSnap.data!.data()
                              as Map<String, dynamic>? ??
                          {};
                  final name =
                      user['name']?.toString() ??
                          'Unknown';
                  final avatarUrl =
                      user['profilePictureUrl']
                              ?.toString() ??
                          '';
                  final headline =
                      user['headline']
                                  ?.toString()
                                  .isNotEmpty ==
                              true
                          ? user['headline'].toString()
                          : user['role']
                                  ?.toString() ??
                              '';

                  return Container(
                    margin: const EdgeInsets.only(
                        bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.borderSubtle),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppColors.borderSubtle,
                        backgroundImage:
                            avatarUrl.isNotEmpty
                                ? NetworkImage(
                                    avatarUrl)
                                : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(Icons.person,
                                color:
                                    AppColors.brandRed)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700)),
                            if (headline.isNotEmpty)
                              Text(headline,
                                  style:
                                      GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors
                                              .mutedText),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _accept(
                            context,
                            fromUid,
                            requestId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize
                                  .shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                        ),
                        child: Text('Accept',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => _decline(
                            context, requestId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              AppColors.mutedText,
                          side: const BorderSide(
                              color:
                                  AppColors.borderSubtle),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize
                                  .shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                        ),
                        child: Text('Decline',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600)),
                      ),
                    ]),
                  );
                },
              );
            }),
            const SizedBox(height: 48),
          ],
        );
      },
    );
  }
}