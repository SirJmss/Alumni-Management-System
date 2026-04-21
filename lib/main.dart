import 'package:alumni/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/presentation/screens/growth_metrics_screen.dart';
import 'package:alumni/features/auth/presentation/screens/login_screen.dart';
import 'package:alumni/features/auth/presentation/screens/register_screen.dart';
import 'package:alumni/features/gallery/presentation/screens/gallery_screen.dart';
import 'package:alumni/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:alumni/features/dashboard/presentation/screens/admin_dashboard_web.dart';
import 'package:alumni/features/admin/presentation/screens/user_verification_moderation_screen.dart';
import 'package:alumni/features/admin/presentation/screens/event_planning_screen.dart';
import 'package:alumni/features/admin/presentation/screens/job_board_management_screen.dart';
import 'package:alumni/features/admin/presentation/screens/career_milestones_screen.dart';
import 'package:alumni/features/admin/presentation/screens/announcement_management_screen.dart';
import 'package:alumni/features/admin/presentation/screens/admin_post_approval.dart';
import 'package:alumni/features/event/presentation/screens/discussions_screen.dart';
import 'package:alumni/features/event/presentation/screens/event_list_screen.dart';
import 'package:alumni/features/communication/messages_screen.dart';
import 'package:alumni/features/network/friends_screen.dart';
import 'package:alumni/features/auth/presentation/screens/settings_screen.dart';
import 'package:alumni/features/profile/presentation/screens/profile_screen.dart';
import 'package:alumni/features/announcements/presentation/screens/announcements_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: false);
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
        colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brandRed),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const LandingPage(),
      routes: {
        '/login'                        : (context) => const LoginScreen(),
        '/register'                     : (context) => const RegisterScreen(),
        '/gallery'                      : (context) => const GalleryScreen(),
        '/dashboard'                    : (context) => const DashboardScreen(),
        '/admin'                        : (context) => const AdminDashboardWeb(),
        '/admin_dashboard'              : (context) => const AdminDashboardWeb(),
        '/growth_metrics'               : (context) => const GrowthMetricsScreen(),
        '/user_verification_moderation' : (context) => const UserVerificationScreen(),
        '/event_planning'               : (context) => const EventPlanningScreen(),
        '/job_board_management'         : (context) => const JobBoardManagementScreen(),
        '/career_milestones'            : (context) => const CareerMilestonesScreen(),
        '/announcement_management'      : (context) => const AnnouncementManagementScreen(),
        '/post_approval'                : (context) => const PostApprovalScreen(),
        '/discussions'                  : (context) => const DiscussionsScreen(),
        '/events'                       : (context) => const EventListScreen(),
        '/announcements'                : (context) => const AnnouncementsScreen(),
        '/messages'                     : (context) => const MessagesScreen(),
        '/friends'                      : (context) => const FriendsScreen(),
        '/settings'                     : (context) => const SettingsScreen(),
        '/profile'                      : (context) => const AlumniProfileScreen(),
        '/edit_profile'                 : (context) => const EditProfileScreen(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST APPROVAL STANDALONE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PostApprovalScreen extends StatefulWidget {
  const PostApprovalScreen({super.key});

  @override
  State<PostApprovalScreen> createState() => _PostApprovalScreenState();
}

class _PostApprovalScreenState extends State<PostApprovalScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Text('Post Approval',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          const SizedBox(width: 10),
          const CombinedPendingBadge(),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(children: [
              _tabBtn(0, Icons.feed_outlined, 'Feed Posts'),
              _tabBtn(1, Icons.emoji_events_outlined, 'Gallery Achievements'),
            ]),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _tab == 0
            ? _FeedPostsTab(key: const ValueKey('feed'))
            : _AchievementsTab(key: const ValueKey('achievements')),
      ),
    );
  }

  Widget _tabBtn(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.brandRed : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 14,
                color: active ? AppColors.brandRed : AppColors.mutedText),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? AppColors.brandRed : AppColors.mutedText)),
          ]),
        ),
      ),
    );
  }
}

class _FeedPostsTab extends StatelessWidget {
  const _FeedPostsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        padding: const EdgeInsets.all(20),
        child: const PostApprovalPanel(),
      ),
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Achievement Queue',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const SizedBox(height: 4),
            Text('Review gallery achievement submissions from alumni',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText)),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderSubtle),
            const SizedBox(height: 8),
            const CareerMilestonesScreen(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CORNER ACCENT PAINTER — decorative L-bracket
// ─────────────────────────────────────────────────────────────────────────────
class _CornerAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandRed.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    // Top horizontal
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    // Left vertical
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CornerAccentPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDING PAGE
// ─────────────────────────────────────────────────────────────────────────────

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 40;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 640;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isMobile),
      endDrawer: _buildDrawer(),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(children: [
          _buildHero(isMobile),
          _buildStatsBar(isMobile),
          _buildAboutSection(isMobile),
          _buildFeaturesSection(isMobile),
          _buildQuoteSection(isMobile),
          _buildCtaSection(isMobile),
          _buildFooter(isMobile),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _scrolled ? Colors.white : Colors.transparent,
          border: _scrolled
              ? const Border(
                  bottom: BorderSide(
                      color: AppColors.borderSubtle, width: 0.5))
              : null,
          boxShadow: _scrolled
              ? [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12)]
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ALUMNI',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 20, letterSpacing: 6,
                            fontWeight: FontWeight.w400,
                            color: AppColors.brandRed)),
                    Text('ST. CECILIA\'S',
                        style: GoogleFonts.inter(
                            fontSize: 7, letterSpacing: 3,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                if (!isMobile)
                  Row(children: [
                    _navLink('Home', () {}),
                    _navLink('Gallery',
                        () => Navigator.pushNamed(context, '/gallery')),
                    _navLink('Sign In',
                        () => Navigator.pushNamed(context, '/login')),
                    const SizedBox(width: 16),
                    _navCta('Apply Now',
                        () => Navigator.pushNamed(context, '/register')),
                  ])
                else
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => Scaffold.of(ctx).openEndDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.menu,
                            color: AppColors.darkText, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      );

  Widget _navCta(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandRed,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      width: 280,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ALUMNI',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 18, letterSpacing: 5,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w400)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: AppColors.mutedText, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('ST. CECILIA\'S',
                  style: GoogleFonts.inter(
                      fontSize: 8, letterSpacing: 3,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 24),
              _drawerItem('Home', Icons.home_outlined,
                  () => Navigator.pop(context)),
              _drawerItem('Gallery', Icons.photo_library_outlined, () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/gallery');
              }),
              _drawerItem('Help & Support', Icons.help_outline,
                  () => Navigator.pop(context)),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 24),
              _drawerItem('Sign In', Icons.login_outlined, () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/register');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text('Apply Now',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 32),
              Text('EST. 2026',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.mutedText,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.mutedText),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText)),
          ]),
        ),
      );

  // ── HERO — line removed, design enhanced ────────────────────────────────
  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      constraints:
          BoxConstraints(minHeight: MediaQuery.of(context).size.height),
      color: const Color(0xFF0C0C0C),
      child: Stack(children: [

        // Background image — slightly more visible
        Positioned.fill(
          child: Image.asset(
            'assets/images/gallery/building.jpg',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.10),
          ),
        ),

        // Radial warm glow top-left
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.4),
                radius: 1.2,
                colors: [
                  AppColors.brandRed.withOpacity(0.09),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom fade to black
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, const Color(0xFF0C0C0C)],
              ),
            ),
          ),
        ),

        // Decorative corner bracket — top-left (replaces the full-height line)
        Positioned(
          top: isMobile ? 86 : 70,
          left: isMobile ? 20 : 44,
          child: SizedBox(
            width: 44, height: 44,
            child: CustomPaint(painter: _CornerAccentPainter()),
          ),
        ),

        // Subtle bottom-right accent dot cluster
        if (!isMobile)
          Positioned(
            bottom: 80, right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (col) => Container(
                    width: 3, height: 3,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  )),
                ),
              )),
            ),
          ),

        // Rotated year stamp — right side
        if (!isMobile)
          Positioned(
            right: 44, top: 240,
            child: RotatedBox(
              quarterTurns: 1,
              child: Text('ALUMNI  ·  ST. CECILIA\'S  ·  2026',
                  style: GoogleFonts.inter(
                      fontSize: 9, letterSpacing: 4,
                      color: Colors.white.withOpacity(0.09),
                      fontWeight: FontWeight.w500)),
            ),
          ),

        // Main content
        Padding(
          padding: EdgeInsets.only(
            left: isMobile ? 28 : 80,
            right: isMobile ? 28 : 80,
            top: isMobile ? 148 : 168,
            bottom: isMobile ? 80 : 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Tag pill with live dot
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                      color: AppColors.brandRed.withOpacity(0.35),
                      width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                        color: AppColors.brandRed, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('EST. 2026  ·  ST. CECILIA\'S',
                      style: GoogleFonts.inter(
                          fontSize: 10, letterSpacing: 2.5,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600)),
                ]),
              ),

              const SizedBox(height: 44),

              // Headline with mixed weight for typographic rhythm
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: 'Where\n',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: isMobile ? 66 : 100,
                        height: 0.96,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -1),
                  ),
                  TextSpan(
                    text: 'Legacy\n',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: isMobile ? 66 : 100,
                        height: 0.96,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1),
                  ),
                  TextSpan(
                    text: 'Lives On.',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: isMobile ? 66 : 100,
                        height: 1.08,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -1),
                  ),
                ]),
              ),

              const SizedBox(height: 36),

              // Short rule + description
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 28, height: 1,
                      color: AppColors.brandRed.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      width: isMobile ? double.infinity : 440,
                      child: Text(
                        'A private network for St. Cecilia\'s graduates. Connect with fellow alumni, attend exclusive events, and carry your legacy forward.',
                        style: GoogleFonts.inter(
                            fontSize: isMobile ? 14 : 15,
                            color: Colors.white.withOpacity(0.48),
                            height: 1.8,
                            fontWeight: FontWeight.w300),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 56),

              // CTA buttons
              Wrap(spacing: 14, runSpacing: 14, children: [
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/register'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.brandRed,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandRed.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text('APPLY NOW',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2.5)),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/login'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1),
                      ),
                      child: Text('SIGN IN',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 2.5)),
                    ),
                  ),
                ),
              ]),

              SizedBox(height: isMobile ? 56 : 80),

              // Scroll hint
              Row(children: [
                Container(
                    width: 18, height: 0.5,
                    color: Colors.white.withOpacity(0.18)),
                const SizedBox(width: 12),
                Text('SCROLL TO EXPLORE',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.22),
                        letterSpacing: 3)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildStatsBar(bool isMobile) {
    return Container(
      color: AppColors.brandRed,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80, vertical: 28),
      child: isMobile
          ? Column(children: [
              _statItem('500+', 'Graduates'),
              const SizedBox(height: 20),
              _statItem('12', 'Active Chapters'),
              const SizedBox(height: 20),
              _statItem('48+', 'Annual Events'),
              const SizedBox(height: 20),
              _statItem('25+', 'Years of Legacy'),
            ])
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('500+', 'Graduates'),
                _statDivider(),
                _statItem('12', 'Active Chapters'),
                _statDivider(),
                _statItem('48+', 'Annual Events'),
                _statDivider(),
                _statItem('25+', 'Years of Legacy'),
              ],
            ),
    );
  }

  Widget _statItem(String value, String label) => Column(children: [
        Text(value,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                color: Colors.white)),
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 9,
                letterSpacing: 2,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600)),
      ]);

  Widget _statDivider() => Container(
      width: 0.5, height: 48, color: Colors.white.withOpacity(0.2));

  Widget _buildAboutSection(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 28 : 80,
          vertical: isMobile ? 80 : 120),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTag('ABOUT'),
              const SizedBox(height: 24),
              _aboutText(isMobile),
              const SizedBox(height: 40),
              _aboutParagraph(),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTag('ABOUT'),
                      const SizedBox(height: 24),
                      _aboutText(isMobile),
                    ]),
              ),
              const SizedBox(width: 80),
              Expanded(flex: 3, child: _aboutParagraph()),
            ]),
    );
  }

  Widget _sectionTag(String label) => Row(children: [
        Container(width: 24, height: 1, color: AppColors.brandRed),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, letterSpacing: 3,
                color: AppColors.brandRed,
                fontWeight: FontWeight.w700)),
      ]);

  Widget _aboutText(bool isMobile) => Text(
        'A Network\nBuilt on\nTradition.',
        style: GoogleFonts.cormorantGaramond(
            fontSize: isMobile ? 40 : 52,
            height: 1.1,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText),
      );

  Widget _aboutParagraph() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The St. Cecilia\'s Alumni Network is an exclusive community connecting graduates across generations. We preserve the legacy of our institution while empowering alumni to grow professionally and personally.',
            style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.mutedText,
                height: 1.8,
                fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 24),
          Text(
            'From batch reunions to career mentorship, our platform is the bridge between where you came from and where you\'re going.',
            style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.mutedText,
                height: 1.8,
                fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/register'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('JOIN THE NETWORK',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandRed,
                        letterSpacing: 1.5)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward,
                    size: 14, color: AppColors.brandRed),
              ]),
            ),
          ),
        ],
      );

  Widget _buildFeaturesSection(bool isMobile) {
    final features = [
      {'icon': Icons.people_outline,         'title': 'Alumni Network',       'desc': 'Connect with thousands of St. Cecilia\'s graduates across all generations and industries.'},
      {'icon': Icons.event_outlined,         'title': 'Exclusive Events',     'desc': 'Access members-only reunions, homecomings, and career networking gatherings.'},
      {'icon': Icons.work_outline,           'title': 'Career Board',         'desc': 'Discover and share career opportunities within the St. Cecilia\'s community.'},
      {'icon': Icons.campaign_outlined,      'title': 'Announcements',        'desc': 'Stay informed with important institutional news and community announcements.'},
      {'icon': Icons.school_outlined,        'title': 'Batch Chapters',       'desc': 'Stay connected with your batch and program through dedicated chapter groups.'},
      {'icon': Icons.emoji_events_outlined,  'title': 'Career Milestones',    'desc': 'Celebrate achievements and share your professional journey with the community.'},
    ];

    return Container(
      color: AppColors.softWhite,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 28 : 80,
          vertical: isMobile ? 80 : 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTag('FEATURES'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Everything You\nNeed, In One\nPlace.',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: isMobile ? 40 : 52,
                      height: 1.1,
                      fontWeight: FontWeight.w300,
                      color: AppColors.darkText)),
              if (!isMobile)
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/register'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.brandRed),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('GET ACCESS',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandRed,
                              letterSpacing: 1.5)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 60),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: isMobile
                ? const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisExtent: 120,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1)
                : const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1),
            itemCount: features.length,
            itemBuilder: (context, i) {
              final f = features[i];
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: AppColors.borderSubtle, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(f['icon'] as IconData,
                          color: AppColors.brandRed, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f['title'].toString(),
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText)),
                          const SizedBox(height: 6),
                          Text(f['desc'].toString(),
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.mutedText,
                                  height: 1.5),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C0C0C),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 28 : 120,
          vertical: isMobile ? 80 : 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 1, color: AppColors.brandRed),
          const SizedBox(height: 48),
          Text(
            '"Exclusivity is not about\nexcluding others — it\'s about\nincluding the right moments."',
            style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 32 : 52,
                height: 1.3,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 40),
          Row(children: [
            Container(
                width: 20, height: 0.5, color: AppColors.brandRed),
            const SizedBox(width: 12),
            Text('ST. CECILIA\'S ALUMNI',
                style: GoogleFonts.inter(
                    fontSize: 10, letterSpacing: 3,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  Widget _buildCtaSection(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 28 : 80,
          vertical: isMobile ? 80 : 120),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ctaContent(isMobile),
              const SizedBox(height: 48),
              _buildCtaImageBlock(),
            ])
          : Row(children: [
              Expanded(flex: 3, child: _ctaContent(isMobile)),
              const SizedBox(width: 80),
              Expanded(flex: 2, child: _buildCtaImageBlock()),
            ]),
    );
  }

  Widget _ctaContent(bool isMobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTag('JOIN US'),
          const SizedBox(height: 24),
          Text('Access the\nInaccessible.',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 42 : 56,
                  height: 1.1,
                  fontWeight: FontWeight.w300,
                  color: AppColors.darkText)),
          const SizedBox(height: 24),
          Text(
            'Connect with the past, present, and future of St. Cecilia\'s through exclusive access to events, resources, and a vibrant community of alumni.',
            style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.mutedText,
                height: 1.7,
                fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 40),
          Wrap(spacing: 14, runSpacing: 14, children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/register'),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  color: AppColors.brandRed,
                  child: Text('APPLY NOW',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2)),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/login'),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text('SIGN IN',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          letterSpacing: 2)),
                ),
              ),
            ),
          ]),
        ],
      );

  Widget _buildCtaImageBlock() => Container(
        height: 320,
        decoration: BoxDecoration(
          color: AppColors.brandRed.withOpacity(0.05),
          border: Border.all(
              color: AppColors.borderSubtle, width: 0.5),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/gallery/building.jpg',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.4),
            ),
          ),
          Positioned(
            bottom: 24, left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ST. CECILIA\'S',
                    style: GoogleFonts.inter(
                        fontSize: 9, letterSpacing: 3,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                Text('Alumni Network',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.w300)),
              ],
            ),
          ),
        ]),
      );

  Widget _buildFooter(bool isMobile) {
    return Container(
      color: const Color(0xFF0C0C0C),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 28 : 80, vertical: 80),
      child: Column(children: [
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _footerBrand(),
                  const SizedBox(height: 48),
                  _footerLinks(),
                ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _footerBrand()),
                _footerLinks(),
              ]),
        const SizedBox(height: 64),
        const Divider(color: Color(0xFF1F1F1F), height: 1),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('© ${DateTime.now().year} Alumni — St. Cecilia\'s',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.25))),
            Text('All rights reserved',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.25))),
          ],
        ),
      ]),
    );
  }

  Widget _footerBrand() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ALUMNI',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 24, letterSpacing: 6,
                  color: Colors.white, fontWeight: FontWeight.w300)),
          const SizedBox(height: 6),
          Text('ST. CECILIA\'S',
              style: GoogleFonts.inter(
                  fontSize: 9, letterSpacing: 3,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            width: 240,
            child: Text(
              'Connecting the past, present, and future of St. Cecilia\'s through community and legacy.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.35),
                  height: 1.7),
            ),
          ),
        ],
      );

  Widget _footerLinks() {
    final sections = {
      'NETWORK' : ['Overview', 'Gallery', 'Events'],
      'ACCOUNT' : ['Sign In', 'Apply Now', 'Support'],
      'LEGAL'   : ['Privacy Policy', 'Terms of Use'],
    };
    return Wrap(
      spacing: 32,
      runSpacing: 32,
      children: sections.entries.map((entry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.key,
              style: GoogleFonts.inter(
                  fontSize: 9, letterSpacing: 2,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...entry.value.map((link) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(link,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w400)),
              )),
        ],
      )).toList(),
    );
  }
}