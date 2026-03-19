import 'package:alumni/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:alumni/features/admin/presentation/screens/growth_metrics_screen.dart';
import 'package:alumni/features/auth/presentation/screens/login_screen.dart';
import 'package:alumni/features/auth/presentation/screens/register_screen.dart';
import 'package:alumni/features/gallery/presentation/screens/gallery_screen.dart';
import 'package:alumni/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:alumni/features/dashboard/presentation/screens/admin_dashboard_web.dart';
import 'package:alumni/features/admin/presentation/screens/user_verification_moderation_screen.dart';
import 'package:alumni/features/admin/presentation/screens/event_planning_screen.dart';
import 'package:alumni/features/admin/presentation/screens/job_board_management_screen.dart';
import 'package:alumni/features/admin/presentation/screens/chapter_management_screen.dart';
import 'package:alumni/features/admin/presentation/screens/reunion_planning_screen.dart';
import 'package:alumni/features/admin/presentation/screens/career_milestones_screen.dart';
import 'package:alumni/features/admin/presentation/screens/announcement_management_screen.dart';
import 'package:alumni/features/event/presentation/screens/discussions_screen.dart';
import 'package:alumni/features/communication/messages_screen.dart';
import 'package:alumni/features/network/friends_screen.dart';
import 'package:alumni/features/auth/presentation/screens/settings_screen.dart';
import 'package:alumni/features/profile/presentation/screens/profile_screen.dart';       // AlumniProfileScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALUMNI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B1D1D)),
      ),
      home: const LandingPage(), // Starts on welcome/landing page
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/admin': (context) => const AdminDashboardWeb(),
        '/growth_metrics': (context) => const GrowthMetricsScreen(),
        '/user_verification_moderation': (context) => const UserVerificationScreen(),
        '/event_planning': (context) => const EventPlanningScreen(),
        '/job_board_management': (context) => const JobBoardManagementScreen(),
        '/chapter_management': (context) => const ChapterManagementScreen(),
        '/reunions_events': (context) => const ReunionAndEventsScreen(),
        '/career_milestones': (context) => const CareerMilestonesScreen(),
        '/announcement_management': (context) => const AnnouncementManagementScreen(),
        '/admin_dashboard': (context) => const AdminDashboardWeb(),
        '/discussions': (context) => const DiscussionsScreen(),
        '/messages': (context) => const MessagesScreen(),
        '/friends': (context) => const FriendsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const AlumniProfileScreen(),
        '/edit_profile': (context) => const EditProfileScreen(),

      },
    );
  }
}



// LandingPage (unchanged from your version)
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF9B1D1D),
        title: const Text(
          'ALUMNI',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: false,
        actions: [
          Builder(
            builder: (BuildContext context) => IconButton(
              icon: const Icon(Icons.menu, size: 28, color: Color(0xFF1A1A1A)),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        width: 300,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          children: [
            const Text(
              'ALUMNI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 48),

            _buildMenuItem('Overview', () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            }),

            _buildMenuItem('Collection', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/gallery');
            }),

            _buildMenuItem('Help & Support', () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support – coming soon')),
              );
            }),

            const Divider(height: 48, color: Colors.black12),

            _buildMenuItem('Sign In', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            }),

            _buildMenuItem('Apply Now', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            }, isAccent: true),

            const Spacer(),
            const Text(
              'EST. 2026',
              style: TextStyle(fontSize: 13, color: Colors.grey, letterSpacing: 2),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Hero Section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 32,
                    vertical: isSmallScreen ? 80 : 140,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'EST. 2026',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 6,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'St. Cecilia’s Alumni',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 44 : 60,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111111),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'A world where the past and present converge,\nwhere the legacy of St. Cecilia’s lives on.',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 56),
                      SizedBox(
                        width: 300,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B1D1D),
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            elevation: 0,
                          ),
                          child: const Text(
                            'APPLY NOW',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'LEARN MORE',
                          style: TextStyle(
                            color: Color(0xFF9B1D1D),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quote + Image Section
                SizedBox(
                  height: isSmallScreen ? 420 : 520,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/gallery/building.jpg',
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.65),
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, color: Colors.red, size: 80),
                          );
                        },
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '"Exclusivity is not about excluding others;\nit’s about including the right moments."',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 28,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 36),
                              Text(
                                'St. Cecilia’s Alumni',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 15 : 16,
                                  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.88),
                                  height: 1.7,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Apply Section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 24 : 32,
                    vertical: isSmallScreen ? 80 : 120,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Access the\nInaccessible.',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 38 : 48,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111111),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'CONNECT WITH THE PAST, PRESENT, AND FUTURE OF ST. CECILIA’S THROUGH EXCLUSIVE ACCESS TO EVENTS, RESOURCES, AND A VIBRANT COMMUNITY OF ALUMNI.',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 300,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B1D1D),
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            elevation: 0,
                          ),
                          child: const Text(
                            'CONNECT WITH US',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
                  color: Colors.black,
                  child: Column(
                    children: [
                      const Text(
                        'ALUMNI',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CONNECTING THE PAST, PRESENT, AND FUTURE OF ST. CECILIA’S',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400, letterSpacing: 2),
                      ),
                      const SizedBox(height: 48),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 32,
                        runSpacing: 16,
                        children: [
                          Text('SOCIAL', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('INSTAGRAM', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('CONCIERGE', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('JOURNAL', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('PRIVACY', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('SUPPORT', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text(
                        '© ${DateTime.now().year} ALUMNI — All Rights Reserved',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap, {bool isAccent = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 16,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isAccent ? const Color(0xFF9B1D1D) : const Color(0xFF1A1A1A),
        ),
      ),
      onTap: onTap,
    );
  }
}