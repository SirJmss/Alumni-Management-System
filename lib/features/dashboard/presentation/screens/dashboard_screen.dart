import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni/features/profile/presentation/screens/profile_screen.dart';
import 'package:alumni/features/event/presentation/screens/event_list_screen.dart';
import 'package:alumni/features/gallery/presentation/screens/gallery_screen.dart';
import 'package:alumni/features/announcements/presentation/screens/announcements_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // User profile data
  String userRole = 'alumni';
  String userName = 'Member';
  String? userPhotoUrl;
  bool isLoadingProfile = true;

  // Dashboard stats & lists
  int totalAlumni = 0;
  int upcomingEventsCount = 0;
  int announcementsCount = 0;
  int coursesCount = 0;

  List<Map<String, dynamic>> recentAnnouncements = [];
  List<Map<String, dynamic>> upcomingEvents = [];

  bool isLoadingData = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDashboardData();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoadingProfile = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            userRole = data['role'] as String? ?? 'alumni';
            userName = data['fullName'] as String? ??
                data['name'] as String? ??
                user.displayName ??
                'Member';
            userPhotoUrl = data['photoUrl'] as String? ?? user.photoURL;
          });
        }
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      // silent fallback - keep defaults
    }

    if (mounted) setState(() => isLoadingProfile = false);
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      isLoadingData = true;
      errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final now = Timestamp.now();

      // Parallel fetches for better performance
      final results = await Future.wait([
        // 0: total alumni
        firestore.collection('users').count().get(),
        // 1: upcoming events
        firestore
            .collection('events')
            .where('startDate', isGreaterThan: now)
            .orderBy('startDate')
            .limit(5)
            .get(),
        // 2: announcements count
        firestore.collection('announcements').count().get(),
        // 3: recent announcements
        firestore
            .collection('announcements')
            .orderBy('publishedAt', descending: true)
            .limit(3)
            .get(),
        // 4: courses count
        firestore.collection('courses').count().get(),
      ]);

      if (!mounted) return;

      setState(() {
        totalAlumni = (results[0] as AggregateQuerySnapshot).count ?? 0;

        final eventsSnap = results[1] as QuerySnapshot;
        upcomingEventsCount = eventsSnap.size;
        upcomingEvents = eventsSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['title'] as String? ?? 'Untitled Event',
            'startDate': data['startDate'] as Timestamp?,
            'description': data['description'] as String?,
            'location': data['location'] as String?,
          };
        }).toList();

        announcementsCount = (results[2] as AggregateQuerySnapshot).count ?? 0;

        final annSnap = results[3] as QuerySnapshot;
        recentAnnouncements = annSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['title'] as String? ?? 'Announcement',
            'content': data['content'] as String? ?? '',
            'publishedAt': data['publishedAt'] as Timestamp?,
          };
        }).toList();

        coursesCount = (results[4] as AggregateQuerySnapshot).count ?? 0;

        isLoadingData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load dashboard data. Please try again.';
          isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: const Color(0xFFE64646),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFE64646)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6D3AE),
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFE64646),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFFE64646),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFE64646)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
                    child: userPhotoUrl == null
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              fontSize: 36,
                              color: Color(0xFFE64646),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hi, $userName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userRole == 'admin'
                              ? 'Administrator'
                              : userRole == 'registrar'
                                  ? 'Registrar'
                                  : 'Alumni',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        if (isLoadingProfile)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildDrawerItem(Icons.person_outline, 'Profile', false, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            }),

            _buildDrawerItem(Icons.home_outlined, 'Dashboard', true, null),

            if (userRole == 'registrar' || userRole == 'admin') ...[
              _buildDrawerItem(Icons.people_outline, 'Alumni Management', false, null),
              _buildDrawerItem(Icons.school_outlined, 'Courses', false, null),
              _buildDrawerItem(Icons.work_outline, 'Job Postings', false, null),
              _buildDrawerItem(Icons.account_circle_outlined, 'User Accounts', false, null),
            ],

            _buildDrawerItem(
              Icons.event_outlined,
              'Events',
              false,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventListScreen()),
                );
              },
            ),

            _buildDrawerItem(
              Icons.campaign_outlined,
              'Announcements',
              false,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                );
              },
            ),

            _buildDrawerItem(
              Icons.photo_library_outlined,
              'Gallery',
              false,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                );
              },
            ),

            _buildDrawerItem(Icons.star_outline, 'Success Stories', false, null),
            _buildDrawerItem(Icons.format_quote_outlined, 'Testimonials', false, null),
            _buildDrawerItem(Icons.forum_outlined, 'Forum Topics', false, null),

            const Divider(color: Colors.white30, indent: 16, endIndent: 16),

            _buildDrawerItem(Icons.logout_outlined, 'Logout', false, _logout),
          ],
        ),
      ),

      body: isLoadingProfile || isLoadingData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE64646)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFFE64646),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personalized greeting
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Welcome back, ${userName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ),

                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE64646),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard('TOTAL ALUMNI', totalAlumni.toString(), Icons.people, Colors.blue),
                        _buildStatCard('UPCOMING EVENTS', upcomingEventsCount.toString(), Icons.event, Colors.green),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard('ANNOUNCEMENTS', announcementsCount.toString(), Icons.campaign, Colors.purple),
                        _buildStatCard('COURSES', coursesCount.toString(), Icons.school, Colors.orange),
                      ],
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Recent Announcements',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                    ),
                    const SizedBox(height: 12),

                    if (recentAnnouncements.isEmpty)
                      const Center(
                        child: Text(
                          'No recent announcements yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...recentAnnouncements.map(
                        (ann) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildAnnouncementCard(
                            ann['title'] as String? ?? 'No title',
                            ann['content'] as String? ?? 'No content',
                            ann['publishedAt'] is Timestamp
                                ? DateFormat('MMM dd, yyyy • hh:mm a')
                                    .format((ann['publishedAt'] as Timestamp).toDate())
                                : 'N/A',
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    const Text(
                      'Upcoming Events',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                    ),
                    const SizedBox(height: 12),

                    if (upcomingEvents.isEmpty)
                      const Center(
                        child: Text(
                          'No upcoming events found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...upcomingEvents.map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              // TODO: Navigate to event detail screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Opening: ${event['title']}')),
                              );
                            },
                            child: _buildEventCard(
                              event['title'] as String? ?? 'No title',
                              event['startDate'] is Timestamp
                                  ? DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format((event['startDate'] as Timestamp).toDate())
                                  : 'N/A',
                              Icons.event,
                              Colors.green,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    bool isSelected, [
    VoidCallback? onTap,
  ]) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white70,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFFF06A6A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                count,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(String title, String content, String date) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              date,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(String title, String date, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF2D2D2D),
          ),
        ),
        subtitle: Text(
          date,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFFE64646),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}