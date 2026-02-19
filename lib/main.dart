import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

// Import your screens (adjust paths if needed)
import 'package:alumni/features/auth/presentation/screens/login_screen.dart';
import 'package:alumni/features/dashboard/presentation/screens/dashboard_screen.dart';

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
      title: 'St. Cecilia’s Alumni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ── Changed to red theme to match dashboard ──
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red.shade800,
          primary: Colors.red.shade800,
          secondary: Colors.red.shade600,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
      ),
      home: const LandingPage(),

      // Named routes (already correct)
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "St. Cecilia’s Alumni",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        titleSpacing: 0,
        toolbarHeight: 56,
        backgroundColor: const Color(0xFFE64646),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_outlined),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      drawer: Drawer(
        backgroundColor: Colors.white,
        elevation: 8,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFE64646)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.school_outlined, size: 40, color: Color(0xFFE64646)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'St. Cecilia’s Alumni',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Welcome back',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            _buildEnhancedDrawerTile(Icons.home_outlined, 'Home', () => Navigator.pop(context), isPrimary: true),
            _buildEnhancedDrawerTile(Icons.login_outlined, 'Login', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            }),
            _buildEnhancedDrawerTile(Icons.person_add_outlined, 'Register', () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Register coming soon")),
              );
            }),
            const Divider(color: Colors.white30, indent: 16, endIndent: 16),
            _buildEnhancedDrawerTile(Icons.event_outlined, 'Events', () => Navigator.pop(context)),
            _buildEnhancedDrawerTile(Icons.photo_library_outlined, 'Gallery', () => Navigator.pop(context)),
            _buildEnhancedDrawerTile(Icons.campaign_outlined, 'News & Announcements', () => Navigator.pop(context)),
            _buildEnhancedDrawerTile(Icons.work_outline, 'Available Jobs', () => Navigator.pop(context)),
            const Divider(color: Colors.white30, indent: 16, endIndent: 16),
            _buildEnhancedDrawerTile(Icons.settings_outlined, 'Settings', () => Navigator.pop(context)),
            _buildEnhancedDrawerTile(Icons.help_outline, 'Help & Support', () => Navigator.pop(context)),
          ],
        ),
      ),

      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 0),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFE64646),
                    const Color(0xFFF06A6A),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    "Welcome Home,",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "St. Cecilia’s Alumni",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "A warm greeting that welcomes all former students back to their school community.\n"
                    "Even after graduation, St. Cecilia’s is still your home —\n"
                    "a place where memories, friendships, and achievements live on.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE64646),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 4,
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Register coming soon")),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white, width: 2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text(
                          "Join Now",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Feature sections with modern card design
            _buildSection(
              title: "Gallery",
              description: "Relive special moments, school events, and alumni gatherings.",
              icon: Icons.photo_library_outlined,
              backgroundColor: Colors.white,
            ),
            _buildSection(
              title: "Upcoming Events",
              description: "Reunions, seminars, outreach programs — stay connected.",
              icon: Icons.event_outlined,
              backgroundColor: const Color(0xFFF5E6E6),
            ),
            _buildSection(
              title: "About Us",
              description: "Mission, vision, core values, and history of the alumni community.",
              icon: Icons.info_outlined,
              backgroundColor: Colors.white,
            ),
            _buildSection(
              title: "Core Values",
              description: "Unity • Integrity • Service • Excellence",
              icon: Icons.favorite_outline,
              backgroundColor: const Color(0xFFF5E6E6),
            ),
            _buildSection(
              title: "News & Announcements",
              description: "Latest updates about alumni activities and school programs.",
              icon: Icons.campaign_outlined,
              backgroundColor: Colors.white,
            ),
            _buildSection(
              title: "Available Jobs",
              description: "Career opportunities shared for alumni and students.",
              icon: Icons.work_outline,
              backgroundColor: const Color(0xFFF5E6E6),
            ),
            _buildSection(
              title: "Success Stories",
              description: "Inspiring journeys of alumni who excelled in various fields.",
              icon: Icons.star_outline,
              backgroundColor: Colors.white,
            ),
            _buildSection(
              title: "Testimonials",
              description: "Personal messages from alumni sharing memories and pride.",
              icon: Icons.format_quote_outlined,
              backgroundColor: const Color(0xFFF5E6E6),
            ),

            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "St. Cecilia’s College – Cebu, Inc.\n© ${DateTime.now().year} Alumni Community",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    IconData? icon,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      color: backgroundColor ?? Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE79A9A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE64646).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(icon, size: 28, color: const Color(0xFFE64646), weight: 300),
            ),
          if (icon != null) const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDrawerTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFE64646).withOpacity(0.1),
        highlightColor: const Color(0xFFE64646).withOpacity(0.05),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFFF5E6E6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isPrimary ? const Color(0xFFE64646) : Colors.grey.shade700,
              size: 22,
              weight: 300,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFFE64646) : Colors.grey.shade800,
                fontSize: 15,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            trailing: isPrimary
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE64646),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}