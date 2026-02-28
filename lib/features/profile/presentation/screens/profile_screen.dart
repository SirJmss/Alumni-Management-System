import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AlumniProfileScreen extends StatefulWidget {
  const AlumniProfileScreen({super.key});

  @override
  State<AlumniProfileScreen> createState() => _AlumniProfileScreenState();
}

class _AlumniProfileScreenState extends State<AlumniProfileScreen> {
  // Brand Colors
  final Color brandRed = const Color(0xFF991B1B);
  final Color backgroundGray = const Color(0xFFF3F4F6);
  final Color darkText = const Color(0xFF111827);
  final Color mutedText = const Color(0xFF6B7280);

  // Firestore State
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User session not found")),
        );
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    if (userData == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: brandRed),
        body: const Center(child: Text("Profile data unavailable")),
      );
    }

    return Scaffold(
      backgroundColor: backgroundGray,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileHeader(),
                _buildStatsRow(),
                _buildSection(
                  title: "Professional Info",
                  child: Column(
                    children: [
                      _buildInfoTile(Icons.work_outline, "Current Role", userData!['currentJob'] ?? userData!['role'] ?? 'Alumni'),
                      _buildInfoTile(Icons.business_outlined, "Company", userData!['company'] ?? 'Add your company'),
                      _buildInfoTile(Icons.school_outlined, "Degree", userData!['degree'] ?? 'Degree not specified'),
                    ],
                  ),
                ),
                _buildSection(
                  title: "Account Details",
                  child: Column(
                    children: [
                      _buildInfoTile(Icons.email_outlined, "Email Address", userData!['email'] ?? 'N/A'),
                      _buildInfoTile(Icons.verified_user_outlined, "Status", (userData!['status'] ?? 'Active').toString().toUpperCase()),
                      _buildInfoTile(Icons.calendar_today_outlined, "Joined", _formatDate(userData!['createdAt'])),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: brandRed,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative background pattern
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [brandRed, brandRed.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(radius: 80, backgroundColor: Colors.white10),
            ),
          ],
        ),
      ),
      title: Text("My Profile", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      centerTitle: true,
      actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: Colors.grey[200],
              backgroundImage: userData!['profileUrl'] != null ? NetworkImage(userData!['profileUrl']) : null,
              child: userData!['profileUrl'] == null ? Icon(Icons.person, size: 50, color: brandRed) : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            userData!['name'] ?? 'Alumni Member',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: darkText),
          ),
          const SizedBox(height: 4),
          Text(
            'Class of ${userData!['batch'] ?? '20XX'}',
            style: GoogleFonts.inter(fontSize: 14, color: brandRed, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              userData!['headline'] ?? "Building a professional legacy through community.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: mutedText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("Connections", "500+"),
          _buildVerticalDivider(),
          _buildStatItem("Projects", "12"),
          _buildVerticalDivider(),
          _buildStatItem("Events", "8"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: darkText)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: mutedText)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: brandRed, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: mutedText.withOpacity(0.7)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: mutedText)),
                Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: darkText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text("Edit Profile", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: IconButton(
              icon: Icon(Icons.share_outlined, color: darkText),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}