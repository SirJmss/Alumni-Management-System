import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  int _currentTab = 3; // Default: Verification Queue

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> pendingUsers = [];
  List<Map<String, dynamic>> recentLogins = [];
  List<Map<String, dynamic>> verificationQueue = [];

  bool isLoading = true;
  String? errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> usersList = usersSnap.docs.map((doc) {
        final data = doc.data();
        final name = (data['name'] ?? data['fullName'] ?? 'Unknown').trim();
        return {
          'id': doc.id,
          'name': name,
          'email': data['email'] ?? '—',
          'role': data['role'] ?? 'alumni',
          'status': data['status'] ?? 'active',
          'verificationStatus': data['verificationStatus'] ?? 'none',
          'batch': data['batchYear'] ?? data['batch'] ?? '—',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'lastLogin': (data['lastLogin'] as Timestamp?)?.toDate() ?? (data['lastActive'] as Timestamp?)?.toDate(),
          'profilePictureUrl': data['profilePictureUrl'],
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        allUsers = usersList;
        pendingUsers = usersList.where((u) => u['status'] == 'pending').toList();
        recentLogins = List.from(usersList)
          ..sort((a, b) {
            final aTime = a['lastLogin'] as DateTime?;
            final bTime = b['lastLogin'] as DateTime?;
            return (bTime ?? DateTime(2000)).compareTo(aTime ?? DateTime(2000));
          });
        verificationQueue = usersList.where((u) {
          final status = u['status'] as String?;
          final verStatus = u['verificationStatus'] as String?;
          return status == 'pending' || verStatus == 'pending';
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load users: $e';
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredData() {
    final list = switch (_currentTab) {
      0 => allUsers,
      1 => pendingUsers,
      2 => recentLogins,
      3 => verificationQueue,
      _ => <Map<String, dynamic>>[],
    };

    if (_searchText.isEmpty) return list;

    return list.where((user) {
      final name = (user['name'] as String?)?.toLowerCase() ?? '';
      final email = (user['email'] as String?)?.toLowerCase() ?? '';
      final role = (user['role'] as String?)?.toLowerCase() ?? '';
      final batch = (user['batch'] as String?)?.toLowerCase() ?? '';
      final status = (user['status'] as String?)?.toLowerCase() ?? '';
      final verStatus = (user['verificationStatus'] as String?)?.toLowerCase() ?? '';

      return name.contains(_searchText) ||
          email.contains(_searchText) ||
          role.contains(_searchText) ||
          batch.contains(_searchText) ||
          status.contains(_searchText) ||
          verStatus.contains(_searchText);
    }).toList();
  }

  Future<void> _approveVerification(String userId) async {
    final user = allUsers.firstWhere(
      (u) => u['id'] == userId,
      orElse: () => {'name': 'User'},
    );
    final userName = user['name'] as String? ?? 'User';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Verification'),
        content: Text('Confirm verification for $userName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Approving...'), duration: Duration(seconds: 15)),
    );

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'verificationStatus': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $userName has been verified'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to approve verification. Please try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      debugPrint('Approve error for $userId: $e');
    }
  }

  Future<void> _rejectVerification(String userId) async {
    final user = allUsers.firstWhere(
      (u) => u['id'] == userId,
      orElse: () => {'name': 'User'},
    );
    final userName = user['name'] as String? ?? 'User';

    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject verification for $userName?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for rejection (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rejecting...'), duration: Duration(seconds: 15)),
    );

    try {
      final update = {
        'verificationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      };
      if (reason.isNotEmpty) update['rejectionReason'] = reason;

      await FirebaseFirestore.instance.collection('users').doc(userId).update(update);

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Verification rejected for $userName'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reject verification. Please try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      debugPrint('Reject error for $userId: $e');
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final created = user['createdAt'] as DateTime?;
    final lastLogin = user['lastLogin'] as DateTime?;
    final status = user['status'] as String? ?? 'active';
    final verStatus = user['verificationStatus'] as String? ?? 'none';
    final isPending = status == 'pending' || verStatus == 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'User Profile',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 36,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkText,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.brandRed, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Profile avatar & name
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: AppColors.brandRed.withOpacity(0.08),
                        backgroundImage: user['profilePictureUrl'] != null
                            ? NetworkImage(user['profilePictureUrl'] as String)
                            : null,
                        child: user['profilePictureUrl'] == null
                            ? Icon(Icons.person, size: 80, color: AppColors.brandRed.withOpacity(0.7))
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        user['name'] as String,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user['email'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Details section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Role', user['role'] as String? ?? '—'),
                      const Divider(height: 32, color: AppColors.borderSubtle),
                      _detailRow('Batch', user['batch'] as String? ?? '—'),
                      const Divider(height: 32, color: AppColors.borderSubtle),
                      _detailRow('Account Status', status, chipColor: _statusColor(status)),
                      const Divider(height: 32, color: AppColors.borderSubtle),
                      _detailRow('Verification Status', verStatus, chipColor: _verColor(verStatus)),
                      const Divider(height: 32, color: AppColors.borderSubtle),
                      _detailRow('Created', created != null ? DateFormat('MMM dd, yyyy • HH:mm').format(created) : '—'),
                      const Divider(height: 32, color: AppColors.borderSubtle),
                      _detailRow('Last Login', lastLogin != null ? DateFormat('MMM dd, yyyy • HH:mm').format(lastLogin) : '—'),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Quick actions (only for pending users)
                if (isPending)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _approveVerification(user['id'] as String);
                        },
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.cancel, size: 20),
                        label: const Text('Reject'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectVerification(user['id'] as String);
                        },
                      ),
                    ],
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? chipColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText,
              ),
            ),
          ),
          Expanded(
            child: chipColor != null
                ? Chip(
                    label: Text(
                      value.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: chipColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  )
                : Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.darkText,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return AppColors.mutedText;
    }
  }

  Color _verColor(String verStatus) {
    switch (verStatus.toLowerCase()) {
      case 'verified':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return AppColors.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar unchanged
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALUMNI',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          letterSpacing: 6,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ARCHIVE PORTAL',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSidebarSection('NETWORK', [
                          _SidebarItem(label: 'Overview', route: '/overview'),
                          _SidebarItem(label: 'Chapter Management', route: '/chapter_management'),
                        ]),
                        const SizedBox(height: 32),
                        _buildSidebarSection('ENGAGEMENT', [
                          _SidebarItem(label: 'Reunions & Events', route: '/reunions_events'),
                          _SidebarItem(label: 'Career Milestones', route: '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _buildSidebarSection('ADMIN FEATURES', [
                          _SidebarItem(label: 'User Verification & Moderation', isActive: true, route: '/user_verification_moderation'),
                          _SidebarItem(label: 'Event Planning', route: '/event_planning'),
                          _SidebarItem(label: 'Job Board Management', route: '/job_board_management'),
                          _SidebarItem(label: 'Growth Metrics', route: '/growth_metrics'),
                          _SidebarItem(label: 'Announcement Management', route: '/announcement_management'),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.borderSubtle.withOpacity(0.3))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.brandRed,
                            child: Text('A', style: GoogleFonts.cormorantGaramond(color: Colors.white, fontSize: 14)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Registrar Admin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('NETWORK OVERSEER', style: GoogleFonts.inter(fontSize: 9, color: AppColors.mutedText)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) Navigator.pushReplacementNamed(context, '/');
                        },
                        child: Text(
                          'DISCONNECT',
                          style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content (unchanged)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trust & Safety Dashboard',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 40,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verify identities and moderate community interactions.',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh All'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandRed,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loadUsers,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _TabButton('All Users', 0),
                        const SizedBox(width: 12),
                        _TabButton('Pending Users', 1),
                        const SizedBox(width: 12),
                        _TabButton('Recent Logins', 2),
                        const SizedBox(width: 12),
                        _TabButton('Verification Queue', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: 400,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, role, batch...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.brandRed),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
                      : errorMessage != null
                          ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
                          : _buildDataTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final data = _getFilteredData();

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 100),
          child: Text(
            _currentTab == 3 ? 'No pending verification requests' : 'No users found in this category',
            style: GoogleFonts.inter(fontSize: 17, color: AppColors.mutedText),
          ),
        ),
      );
    }

    final bool isVerificationTab = _currentTab == 3;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 32,
        headingRowColor: WidgetStatePropertyAll(Colors.white),
        headingTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        dataTextStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
        columns: [
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Role')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Batch')),
          const DataColumn(label: Text('Created')),
          const DataColumn(label: Text('Last Login')),
          DataColumn(label: Text(isVerificationTab ? 'Actions' : 'View')),
        ],
        rows: data.map((user) {
          final created = user['createdAt'] as DateTime?;
          final lastLogin = user['lastLogin'] as DateTime?;
          final isPendingVerification = user['verificationStatus'] == 'pending';

          return DataRow(cells: [
            DataCell(Text(user['name'] as String)),
            DataCell(Text(user['email'] as String)),
            DataCell(Text(user['role'] as String)),
            DataCell(Text(user['status'] as String)),
            DataCell(Text(user['batch'] as String)),
            DataCell(Text(created != null ? DateFormat('MMM dd, yyyy').format(created) : '—')),
            DataCell(Text(lastLogin != null ? DateFormat('MMM dd, yyyy • HH:mm').format(lastLogin) : '—')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, color: AppColors.brandRed, size: 20),
                    tooltip: 'View Details',
                    onPressed: () => _showUserDetails(user),
                  ),
                  if (isVerificationTab && isPendingVerification) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      tooltip: 'Approve Verification',
                      onPressed: () => _approveVerification(user['id'] as String),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                      tooltip: 'Reject Verification',
                      onPressed: () => _rejectVerification(user['id'] as String),
                    ),
                  ],
                ],
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _TabButton(String label, int index) {
    final active = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.brandRed : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.brandRed : AppColors.borderSubtle),
          boxShadow: active ? [BoxShadow(color: AppColors.brandRed.withOpacity(0.2), blurRadius: 12)] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? Colors.white : AppColors.darkText,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedText.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _SidebarItem({required String label, bool isActive = false, String? route}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
        child: MouseRegion(
          cursor: route != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: isActive ? AppColors.brandRed : AppColors.darkText,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}