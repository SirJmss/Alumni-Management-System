import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni/features/profile/presentation/screens/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userRole = 'alumni';
  bool isLoadingRole = true;

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
    _loadUserRole();
    _loadDashboardData();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoadingRole = false);
      return;
    }

    setState(() => isLoadingRole = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          userRole = (doc.data()?['role'] as String?) ?? 'alumni';
        });
      }
    } catch (e) {
      // Silent fail - default role is fine
    }

    if (mounted) setState(() => isLoadingRole = false);
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoadingData = true;
      errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Total Alumni
      final usersSnap = await firestore.collection('users').get();
      totalAlumni = usersSnap.size;

      // 2. Upcoming Events
      final now = Timestamp.now();
      final eventsSnap = await firestore
          .collection('events')
          .where('startDate', isGreaterThan: now)
          .orderBy('startDate')
          .limit(5)
          .get();

      upcomingEventsCount = eventsSnap.size;
      upcomingEvents = eventsSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] as String? ?? 'No title',
          'startDate': data['startDate'] as Timestamp?,
        };
      }).toList();

      // 3. Total Announcements
      final annSnap = await firestore.collection('announcements').get();
      announcementsCount = annSnap.size;

      // 4. Recent Announcements
      final recentAnnSnap = await firestore
          .collection('announcements')
          .orderBy('publishedAt', descending: true)
          .limit(3)
          .get();

      recentAnnouncements = recentAnnSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] as String? ?? 'No title',
          'content': data['content'] as String? ?? 'No content',
          'publishedAt': data['publishedAt'] as Timestamp?,
        };
      }).toList();

      // 5. Courses (optional)
      final coursesSnap = await firestore.collection('courses').get();
      coursesCount = coursesSnap.size;
    } catch (e) {
      errorMessage = 'Failed to load dashboard: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) setState(() => isLoadingData = false);
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
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: Colors.red,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.red),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userRole == 'admin'
                        ? 'Admin / Owner'
                        : userRole == 'registrar'
                            ? 'Registrar'
                            : 'Alumni',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (isLoadingRole)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),

            _buildDrawerItem(
              Icons.person,
              'Profile',
              false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),

            _buildDrawerItem(Icons.home, 'Dashboard', true),

            if (userRole == 'registrar' || userRole == 'admin') ...[
              _buildDrawerItem(Icons.people, 'Alumni Management', false),
              _buildDrawerItem(Icons.school, 'Courses', false),
              _buildDrawerItem(Icons.work, 'Job Postings', false),
              _buildDrawerItem(Icons.account_circle, 'User Accounts', false),
            ],

            _buildDrawerItem(Icons.event, 'Events', false),
            _buildDrawerItem(Icons.campaign, 'Announcements', false),
            _buildDrawerItem(Icons.photo_library, 'Gallery', false),
            _buildDrawerItem(Icons.star, 'Success Stories', false),
            _buildDrawerItem(Icons.format_quote, 'Testimonials', false),
            _buildDrawerItem(Icons.forum, 'Forum Topics', false),

            const Divider(color: Colors.white30),

            _buildDrawerItem(Icons.logout, 'Logout', false, onTap: _logout),
          ],
        ),
      ),

      body: isLoadingRole || isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (recentAnnouncements.isEmpty)
                      const Center(child: Text('No recent announcements yet', style: TextStyle(color: Colors.grey)))
                    else
                      ...recentAnnouncements.map((ann) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAnnouncementCard(
                              ann['title'] as String? ?? 'No title',
                              ann['content'] as String? ?? 'No content',
                              ann['publishedAt'] is Timestamp
                                  ? DateFormat('MMM dd, yyyy • hh:mm a').format((ann['publishedAt'] as Timestamp).toDate())
                                  : 'N/A',
                            ),
                          )),

                    const SizedBox(height: 32),

                    const Text(
                      'Upcoming Events',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (upcomingEvents.isEmpty)
                      const Center(child: Text('No upcoming events found', style: TextStyle(color: Colors.grey)))
                    else
                      ...upcomingEvents.map((event) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildEventCard(
                              event['title'] as String? ?? 'No title',
                              event['startDate'] is Timestamp
                                  ? DateFormat('MMM dd, yyyy • hh:mm a').format((event['startDate'] as Timestamp).toDate())
                                  : 'N/A',
                              Icons.event,
                              Colors.green,
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.red.shade700,
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(String title, String date, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date, style: TextStyle(color: Colors.grey.shade600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}