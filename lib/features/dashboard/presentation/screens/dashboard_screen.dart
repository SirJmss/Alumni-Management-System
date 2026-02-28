import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Real analytics from Firestore
  int totalAlumni = 0;
  int upcomingEventsCount = 0;
  int announcementsCount = 0;
  int coursesCount = 0;

  List<Map<String, dynamic>> recentAnnouncements = [];
  List<Map<String, dynamic>> upcomingEvents = [];
  List<Map<String, dynamic>> recentAcquisitions = [];
  Map<String, dynamic>? conciergeData;

  bool isLoadingData = true;
  String? errorMessage;

  // Colors
  final brandRed = const Color(0xFF991B1B);
  final softWhite = const Color(0xFFFAFAFA);
  final darkText = const Color(0xFF1A1A1A);
  final mutedText = const Color(0xFF6B7280);

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
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          userRole = data['role'] as String? ?? 'alumni';
          userName = (data['fullName'] as String? ??
                  data['name'] as String? ??
                  user.displayName ??
                  user.email?.split('@').first ??
                  'Member')
              .trim();
          userPhotoUrl = data['photoUrl'] as String? ?? user.photoURL;
        });
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) setState(() => isLoadingProfile = false);
    }
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

      // Parallel queries for performance
      final results = await Future.wait([
        // 1. Total Alumni count
        firestore.collection('users').count().get(),
        // 2. Upcoming Events (count + last 5)
        firestore
            .collection('events')
            .where('startDate', isGreaterThan: now)
            .orderBy('startDate')
            .limit(5)
            .get(),
        // 3. Total Announcements
        firestore.collection('announcements').count().get(),
        // 4. Recent Announcements (last 3)
        firestore
            .collection('announcements')
            .orderBy('publishedAt', descending: true)
            .limit(3)
            .get(),
        // 5. Courses count
        firestore.collection('courses').count().get(),
        // 6. Recent Acquisitions (last 3)
        firestore
            .collection('acquisitions')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
        // 7. Active Concierge request (latest one)
        firestore
            .collection('concierge_requests')
            .where('status', isEqualTo: 'ACTIVE')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(),
      ]);

      if (!mounted) return;

      setState(() {
        // Stats
        totalAlumni = (results[0] as AggregateQuerySnapshot).count ?? 0;
        announcementsCount = (results[2] as AggregateQuerySnapshot).count ?? 0;
        coursesCount = (results[4] as AggregateQuerySnapshot).count ?? 0;

        // Upcoming Events
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

        // Recent Announcements
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

        // Recent Acquisitions
        final acqSnap = results[5] as QuerySnapshot;
        recentAcquisitions = acqSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'title': data['title'] as String? ?? 'Untitled Acquisition',
            'description': data['description'] as String? ?? '',
            'date': data['date'] as String? ?? '',
            'status': data['status'] as String? ?? 'PENDING',
          };
        }).toList();

        // Private Concierge (latest active)
        final concSnap = results[6] as QuerySnapshot;
        if (concSnap.docs.isNotEmpty) {
          final data = concSnap.docs.first.data() as Map<String, dynamic>;
          conciergeData = {
            'assistant': data['assistant'] as String? ?? 'ELENA',
            'message': data['message'] as String? ?? 'No active request.',
            'status': data['status'] as String? ?? 'ACTIVE',
            'actionText': data['actionText'] as String? ?? 'CONFIRM DETAILS',
          };
        } else {
          conciergeData = {
            'assistant': 'None',
            'message': 'No active concierge requests at this time.',
            'status': 'INACTIVE',
            'actionText': 'REQUEST ASSISTANCE',
          };
        }

        isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Dashboard data load error: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load dashboard data. Please try again later.';
          isLoadingData = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Text(
              'LOGOUT',
              style: GoogleFonts.inter(letterSpacing: 4, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to exit the sanctuary?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('CANCEL', style: TextStyle(color: mutedText, fontSize: 14)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'LOGOUT',
                  style: TextStyle(color: brandRed, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
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
      backgroundColor: softWhite,
      appBar: AppBar(
        title: Text(
          'DASHBOARD',
          style: GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.w400,
            fontSize: 26,
            letterSpacing: 6,
            color: brandRed,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.15), height: 1),
        ),
      ),
      drawer: _buildMaisonDrawer(),
      body: isLoadingProfile || isLoadingData
          ? Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: brandRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Evening, ${userName.split(' ').first}.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 36,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'YOUR PRIVATE SANCTUARY DASHBOARD',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w500,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (errorMessage != null) _buildErrorMessage(),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.05,
                      children: [
                        _buildMaisonStatCard('TOTAL ALUMNI', totalAlumni.toString(), null),
                        _buildMaisonStatCard('UPCOMING EVENTS', upcomingEventsCount.toString(), null),
                        _buildMaisonStatCard('ANNOUNCEMENTS', announcementsCount.toString(), null),
                        _buildMaisonStatCard('COURSES', coursesCount.toString(), null),
                      ],
                    ),

                    const SizedBox(height: 48),

                    _buildSectionHeader('Recent Acquisitions', '/gallery'),
                    const SizedBox(height: 20),
                    if (recentAcquisitions.isEmpty)
                      _buildEmptyState('No recent acquisitions in the vault.')
                    else
                      ...recentAcquisitions.map((acq) => _buildMaisonAcquisitionCard(acq)),

                    const SizedBox(height: 48),

                    _buildSectionHeader('Private Concierge', '/concierge'),
                    const SizedBox(height: 20),
                    _buildConciergeCard(),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, String route) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: darkText,
          ),
        ),
        TextButton(
          onPressed: () {
            // TODO: Add real navigation based on route
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigating to $title')),
            );
          },
          child: Text(
            'VIEW ALL',
            style: GoogleFonts.inter(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: brandRed,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildMaisonStatCard(String title, String count, String? subValue) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      // center content so value sits roughly mid-card when there's no subtext
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // title should never overflow; shrink if needed
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: mutedText,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                count,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 38,
                  fontWeight: FontWeight.w400,
                  color: darkText,
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subValue,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: brandRed,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaisonAcquisitionCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data['title'] ?? 'Acquisition',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: darkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data['status'] ?? 'PENDING',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: data['status'] == 'SECURED' ? Colors.green : brandRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['description'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: mutedText,
              height: 1.6,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Text(
            data['date'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: mutedText,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConciergeCard() {
    final assistant = conciergeData?['assistant'] ?? 'None';
    final message = conciergeData?['message'] ?? 'No active request.';
    final status = conciergeData?['status'] ?? 'INACTIVE';
    final actionText = conciergeData?['actionText'] ?? 'REQUEST ASSISTANCE';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Private Concierge',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: brandRed.withOpacity(0.1),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: status == 'ACTIVE' ? brandRed : mutedText,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ASSISTANT $assistant',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: darkText,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: brandRed,
            ),
            child: Text(
              actionText,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaisonDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALUMNI',
                  style: GoogleFonts.cormorantGaramond(
                    letterSpacing: 8,
                    fontSize: 28,
                    color: brandRed,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: brandRed,
                      backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
                      child: userPhotoUrl == null
                          ? Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.white, fontSize: 28),
                            )
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: darkText,
                          ),
                        ),
                        Text(
                          userRole.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            color: mutedText,
                          ),
                        ),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _drawerTile(Icons.grid_view, 'OVERVIEW', true, null),
                _drawerTile(Icons.person_outline, 'PROFILE', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }),
                _drawerTile(Icons.event_note_outlined, 'EVENTS', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EventListScreen()));
                }),
                _drawerTile(Icons.campaign_outlined, 'ANNOUNCEMENTS', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
                }),
                _drawerTile(Icons.photo_album_outlined, 'GALLERY', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GalleryScreen()));
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  child: Divider(thickness: 0.5),
                ),
                _drawerTile(Icons.logout, 'LOGOUT', false, _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, bool active, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, size: 22, color: active ? brandRed : darkText),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          letterSpacing: 1.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? brandRed : darkText,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(border: Border.all(color: brandRed.withOpacity(0.3))),
      child: Text(
        errorMessage!,
        style: GoogleFonts.inter(color: brandRed, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(
          message,
          style: GoogleFonts.cormorantGaramond(
            fontStyle: FontStyle.italic,
            color: mutedText,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}