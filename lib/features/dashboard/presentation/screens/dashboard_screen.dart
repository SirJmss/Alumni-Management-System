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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userName = 'Guest';
  String userRole = 'Alumni';
  String userBatch = '';
  String userCourse = '';
  String userLocation = '';
  String? userPhotoUrl;
  bool isLoadingProfile = true;

  int totalAlumni = 0;
  int upcomingEvents = 0;
  int activeCourses = 0;
  int unreadMessages = 0;

  List<Map<String, dynamic>> recentOpportunities = [];
  List<Map<String, dynamic>> upcomingCalendar = [];
  List<Map<String, dynamic>> nearbyAlumni = [];

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

    await Future.wait([
      _loadUserProfile(),
      _loadDashboardAggregates(),
      _loadRecentOpportunities(),
      _loadUpcomingCalendar(),
      _loadNearbyAlumni(),
    ]);

    if (mounted) {
      setState(() {
        isLoadingProfile = false;
        isLoadingData = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          userName = data['fullName'] ??
              data['name'] ??
              user.displayName ??
              'Guest';
          userRole = data['role'] ?? 'Alumni';
          userPhotoUrl =
              data['profilePictureUrl'] ?? user.photoURL;
          userBatch = data['batch']?.toString() ??
              data['batchYear']?.toString() ??
              '';
          userCourse = data['course']?.toString() ??
              data['program']?.toString() ??
              '';
          userLocation = data['location']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Profile error: $e');
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
      setState(() {
        totalAlumni = results[0].count ?? 0;
        upcomingEvents = results[1].count ?? 0;
        activeCourses = results[2].count ?? 0;
      });
    } catch (e) {
      setState(
          () => errorMessage = 'Failed to load dashboard data');
    }
  }

  Future<void> _loadRecentOpportunities() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('opportunities')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      setState(() {
        recentOpportunities = snap.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Opportunity',
            'type': data['type'] ?? 'Full-Time',
            'location': data['location'] ?? 'Remote',
            'company': data['company'] ?? 'Unknown',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Opportunities error: $e');
    }
  }

  Future<void> _loadUpcomingCalendar() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('startDate', isGreaterThan: Timestamp.now())
          .orderBy('startDate')
          .limit(3)
          .get();
      setState(() {
        upcomingCalendar = snap.docs.map((doc) {
          final data = doc.data();
          final date =
              (data['startDate'] as Timestamp?)?.toDate();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Event',
            'date': date != null
                ? DateFormat('MMM dd').format(date)
                : 'TBD',
            'day': date != null
                ? DateFormat('dd').format(date)
                : '??',
            'month': date != null
                ? DateFormat('MMM').format(date)
                : '',
            'type': data['type'] ?? 'Campus Event',
            'event': {...data, 'id': doc.id},
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Calendar error: $e');
    }
  }

  Future<void> _loadNearbyAlumni() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'alumni')
          .limit(10)
          .get();

      final currentUid =
          FirebaseAuth.instance.currentUser?.uid;
      final filtered = snap.docs
          .where((d) => d.id != currentUid)
          .take(5)
          .map((d) => {
                'uid': d.id,
                'name': d.data()['name']?.toString() ??
                    'Alumni',
                'role': d.data()['headline']?.toString() ??
                    d.data()['course']?.toString() ??
                    'Alumni',
                'year':
                    d.data()['batch']?.toString() ?? '',
                'avatarUrl': d
                        .data()['profilePictureUrl']
                        ?.toString() ??
                    '',
              })
          .toList();

      setState(() => nearbyAlumni = filtered);
    } catch (e) {
      debugPrint('Nearby alumni error: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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

  bool get isAdmin =>
      userRole.toLowerCase() == 'admin' ||
      userRole.toLowerCase() == 'staff' ||
      userRole.toLowerCase() == 'moderator' ||
      userRole.toLowerCase() == 'registrar';

  @override
  Widget build(BuildContext context) {
    final isLoading = isLoadingProfile || isLoadingData;
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALUMNI',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.0,
                fontStyle: FontStyle.italic,
                color: AppColors.brandRed,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream:
                NotificationService.unreadCountStream(currentUid),
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
                        size: 24),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: AppColors.brandRed,
                              shape: BoxShape.circle),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const NotificationsScreen()),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadAllData,
              color: AppColors.brandRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Welcome ───
                    Text(
                      'Welcome home,\n${userName.split(' ').first}.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 42,
                        height: 1.1,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Real badges from Firestore ───
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (userBatch.isNotEmpty)
                          _buildBadge(Icons.school_outlined,
                              'Class of $userBatch'),
                        if (userCourse.isNotEmpty)
                          _buildBadge(
                              Icons.auto_stories_outlined,
                              userCourse),
                        if (userLocation.isNotEmpty)
                          _buildBadge(
                              Icons.location_on_outlined,
                              userLocation),
                        _buildBadge(
                            Icons.verified_user_outlined,
                            userRole),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ─── Quick actions ───
                    StreamBuilder<int>(
                      stream:
                          NotificationService.unreadCountStream(
                              currentUid),
                      builder: (context, snapshot) {
                        final notifCount =
                            snapshot.data ?? 0;
                        return SizedBox(
                          height: 90,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildActionCircle(
                                'Network',
                                Icons.people_outline,
                                () => Navigator.pushNamed(
                                    context, '/friends'),
                              ),
                              _buildActionCircle(
                                'Messages',
                                Icons.mail_outline,
                                () => Navigator.pushNamed(
                                    context, '/messages'),
                                badge: unreadMessages,
                              ),
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
                                    context, '/events'),
                              ),
                              _buildActionCircle(
                                'Profile',
                                Icons.edit_outlined,
                                () => Navigator.pushNamed(
                                    context, '/profile'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // ─── Stats ───
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: AppColors.borderSubtle,
                              width: 0.5),
                          bottom: BorderSide(
                              color: AppColors.borderSubtle,
                              width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                              totalAlumni, 'Members'),
                          Container(
                              width: 0.5,
                              height: 30,
                              color: AppColors.borderSubtle),
                          _buildStatItem(
                              upcomingEvents, 'Events'),
                          Container(
                              width: 0.5,
                              height: 30,
                              color: AppColors.borderSubtle),
                          _buildStatItem(
                              activeCourses, 'Courses'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ─── Friend requests banner ───
                    _FriendRequestsBanner(
                        currentUid: currentUid),

                    // ─── Curated Opportunities ───
                    _sectionHeader(
                        'Curated Opportunities', 'VIEW ALL',
                        onTap: () => Navigator.pushNamed(
                            context, '/job_board')),
                    const SizedBox(height: 20),
                    if (recentOpportunities.isEmpty)
                      _buildEmptyState(
                          'No opportunities currently listed')
                    else
                      ...recentOpportunities
                          .map(_opportunityCard),

                    const SizedBox(height: 48),

                    // ─── Calendar ───
                    _sectionHeader('Your Calendar', 'ALL EVENTS',
                        onTap: () => Navigator.pushNamed(
                            context, '/events')),
                    const SizedBox(height: 20),
                    if (upcomingCalendar.isEmpty)
                      _buildEmptyState('No upcoming events')
                    else
                      ...upcomingCalendar
                          .map(_calendarCard),

                    const SizedBox(height: 48),

                    // ─── Nearby Alumni ───
                    _sectionHeader(
                        'Alumni Near You', 'DISCOVER',
                        onTap: () => Navigator.pushNamed(
                            context, '/friends')),
                    const SizedBox(height: 24),
                    if (nearbyAlumni.isEmpty)
                      _buildEmptyState('No alumni found')
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: nearbyAlumni.length,
                          itemBuilder: (context, index) =>
                              _nearbyAlumniCard(
                                  nearbyAlumni[index]),
                        ),
                      ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  // ────────────────────────────────────────────────
  // Drawer
  // ────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: Column(
        children: [
          // ─── Header with avatar ───
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Color(0xFFE5E7EB), width: 0.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.borderSubtle,
                  backgroundImage: userPhotoUrl != null &&
                          userPhotoUrl!.isNotEmpty
                      ? NetworkImage(userPhotoUrl!)
                      : null,
                  child: userPhotoUrl == null ||
                          userPhotoUrl!.isEmpty
                      ? Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.cormorantGaramond(
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
                      Text(
                        userName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _drawerTile(Icons.dashboard_outlined,
                    'Dashboard',
                    active: true),
                _drawerTile(
                    Icons.person_outline, 'My Profile',
                    route: '/profile'),
                _drawerTile(
                    Icons.forum_outlined, 'Discussions',
                    route: '/discussions'),
                _drawerTile(
                    Icons.event_available_outlined, 'Events',
                    route: '/events'),
                _drawerTile(Icons.campaign_outlined,
                    'Announcements',
                    route: '/announcements'),
                _drawerTile(Icons.photo_library_outlined,
                    'Gallery',
                    route: '/gallery'),
                _drawerTile(
                    Icons.message_outlined, 'Messages',
                    route: '/messages'),
                _drawerTile(
                    Icons.people_outline, 'Friends & Network',
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
                    stream: NotificationService.unreadCountStream(
                        FirebaseAuth.instance.currentUser?.uid ??
                            ''),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      if (count == 0) return const SizedBox();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),

                if (isAdmin) ...[
                  const Divider(
                      height: 24, indent: 24, endIndent: 24),
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
                  _drawerTile(Icons.bar_chart_outlined,
                      'Growth Metrics',
                      route: '/growth_metrics'),
                  _drawerTile(Icons.verified_user_outlined,
                      'User Verification',
                      route: '/user_verification_moderation'),
                  _drawerTile(Icons.event_note_outlined,
                      'Event Planning',
                      route: '/event_planning'),
                  _drawerTile(Icons.campaign_outlined,
                      'Announcements',
                      route: '/announcement_management'),
                ],
              ],
            ),
          ),

          // ─── Bottom ───
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          _drawerTile(Icons.settings_outlined, 'Settings',
              route: '/settings'),
          _drawerTile(
            Icons.logout,
            'Logout',
            isDestructive: true,
            onTap: _logout,
          ),
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
            color: color.withOpacity(active ? 1.0 : 0.7)),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight:
              active ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
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

  // ────────────────────────────────────────────────
  // UI helpers
  // ────────────────────────────────────────────────
  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mutedText),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
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
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
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
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(int value, String label) {
    return Column(
      children: [
        Text(
          '$value',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 28, fontWeight: FontWeight.w600),
        ),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String action,
      {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.brandRed,
              ),
            ),
          ),
      ],
    );
  }

  Widget _opportunityCard(Map<String, dynamic> op) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (op['type'] ?? '').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandRed,
                  letterSpacing: 1,
                ),
              ),
              Text(
                op['location'] ?? '',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            op['title'] ?? '',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            op['company'] ?? '',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.mutedText),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'APPLY NOW',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.brandRed,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.brandRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarCard(Map<String, dynamic> event) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/events'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: AppColors.borderSubtle, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event['day'] ?? '??',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandRed),
                  ),
                  Text(
                    event['month'] ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    event['type']?.toUpperCase() ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.mutedText, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _nearbyAlumniCard(Map<String, dynamic> alum) {
    final avatarUrl = alum['avatarUrl']?.toString() ?? '';
    final name = alum['name']?.toString() ?? 'Alumni';
    final year = alum['year']?.toString() ?? '';
    final uid = alum['uid']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (uid.isNotEmpty) {
          Navigator.pushNamed(context, '/friends');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        width: 80,
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.borderSubtle,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      name.isNotEmpty
                          ? name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        color: AppColors.brandRed,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              name.split(' ').first,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (year.isNotEmpty)
              Text(
                year,
                style: GoogleFonts.inter(
                    fontSize: 9, color: AppColors.mutedText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.mutedText,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Friend Requests Banner
// ─────────────────────────────────────────────
class _FriendRequestsBanner extends StatelessWidget {
  final String currentUid;

  const _FriendRequestsBanner({required this.currentUid});

  Future<void> _accept(BuildContext context, String fromUid,
      String requestId) async {
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
          .set({'connectionsCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .set({'connectionsCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final acceptorName =
          currentUserDoc.data()?['name']?.toString() ??
              'Someone';

      await NotificationService.sendFriendAcceptedNotification(
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

  Future<void> _decline(
      BuildContext context, String requestId) async {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Friend Requests',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
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
                      padding:
                          EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(
                          color: AppColors.brandRed),
                    );
                  }

                  final user = userSnap.data!.data()
                          as Map<String, dynamic>? ??
                      {};
                  final name =
                      user['name']?.toString() ?? 'Unknown';
                  final avatarUrl =
                      user['profilePictureUrl']
                              ?.toString() ??
                          '';
                  final headline =
                      user['headline']?.toString().isNotEmpty ==
                              true
                          ? user['headline'].toString()
                          : user['role']?.toString() ?? '';

                  return Container(
                    margin:
                        const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.borderSubtle,
                          backgroundImage:
                              avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(Icons.person,
                                  color: AppColors.brandRed)
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
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors
                                            .mutedText),
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _accept(
                              context, fromUid, requestId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandRed,
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
                                    BorderRadius.circular(8)),
                          ),
                          child: Text('Accept',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () =>
                              _decline(context, requestId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedText,
                            side: const BorderSide(
                                color: AppColors.borderSubtle),
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
                                    BorderRadius.circular(8)),
                          ),
                          child: Text('Decline',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                      ],
                    ),
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