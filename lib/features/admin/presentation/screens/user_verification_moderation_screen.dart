import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() =>
      _UserVerificationScreenState();
}

class _UserVerificationScreenState
    extends State<UserVerificationScreen> {
  int _currentTab = 3;

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> pendingUsers = [];
  List<Map<String, dynamic>> recentLogins = [];
  List<Map<String, dynamic>> verificationQueue = [];

  bool isLoading = true;
  String? errorMessage;
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';

  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(
        () => _searchText =
            _searchController.text.trim().toLowerCase()));
    _loadAdminProfile();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _adminName = data['name']?.toString() ??
              data['fullName']?.toString() ??
              user.displayName ??
              'Admin';
          _adminRole =
              data['role']?.toString().toUpperCase() ??
                  'ADMIN';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final list = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': (d['name'] ?? d['fullName'] ?? 'Unknown')
              .toString()
              .trim(),
          'email': d['email']?.toString() ?? '—',
          'role': d['role']?.toString() ?? 'alumni',
          'status': d['status']?.toString() ?? 'active',
          'verificationStatus':
              d['verificationStatus']?.toString() ?? 'none',
          'batch': d['batchYear']?.toString() ??
              d['batch']?.toString() ??
              '—',
          'course': d['course']?.toString() ??
              d['program']?.toString() ??
              '—',
          'headline': d['headline']?.toString() ?? '',
          'location': d['location']?.toString() ?? '—',
          'phone': d['phone']?.toString() ?? '—',
          'about': d['about']?.toString() ?? '',
          'createdAt':
              (d['createdAt'] as Timestamp?)?.toDate(),
          'lastLogin':
              (d['lastLogin'] as Timestamp?)?.toDate() ??
                  (d['lastActive'] as Timestamp?)?.toDate(),
          'verifiedAt':
              (d['verifiedAt'] as Timestamp?)?.toDate(),
          'rejectedAt':
              (d['rejectedAt'] as Timestamp?)?.toDate(),
          'rejectionReason':
              d['rejectionReason']?.toString() ?? '',
          'profilePictureUrl':
              d['profilePictureUrl']?.toString(),
          'connectionsCount':
              d['connectionsCount']?.toString() ?? '0',
          'followersCount':
              d['followersCount']?.toString() ?? '0',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        allUsers = list;
        pendingUsers = list
            .where((u) => u['status'] == 'pending')
            .toList();
        recentLogins = List.from(list)
          ..sort((a, b) {
            final aT = a['lastLogin'] as DateTime?;
            final bT = b['lastLogin'] as DateTime?;
            return (bT ?? DateTime(2000))
                .compareTo(aT ?? DateTime(2000));
          });
        verificationQueue = list.where((u) {
          return u['status'] == 'pending' ||
              u['verificationStatus'] == 'pending';
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

  List<Map<String, dynamic>> get _filtered {
    final list = switch (_currentTab) {
      0 => allUsers,
      1 => pendingUsers,
      2 => recentLogins,
      3 => verificationQueue,
      _ => <Map<String, dynamic>>[],
    };
    if (_searchText.isEmpty) return list;
    return list.where((u) {
      final name =
          u['name'].toString().toLowerCase();
      final email =
          u['email'].toString().toLowerCase();
      final role =
          u['role'].toString().toLowerCase();
      final batch =
          u['batch'].toString().toLowerCase();
      final status =
          u['status'].toString().toLowerCase();
      final ver = u['verificationStatus']
          .toString()
          .toLowerCase();
      return name.contains(_searchText) ||
          email.contains(_searchText) ||
          role.contains(_searchText) ||
          batch.contains(_searchText) ||
          status.contains(_searchText) ||
          ver.contains(_searchText);
    }).toList();
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

  Future<void> _approve(String uid) async {
    final user = allUsers.firstWhere(
        (u) => u['id'] == uid,
        orElse: () => {'name': 'User'});
    final name = user['name'].toString();

    final confirm = await _confirmDialog(
      title: 'Approve Verification',
      message: 'Verify $name and grant them access?',
      confirmText: 'Approve',
      confirmColor: Colors.green,
    );
    if (confirm != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'verificationStatus': 'verified',
        'status': 'active',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy':
            FirebaseAuth.instance.currentUser?.uid,
      });
      _showSnackBar('$name has been verified',
          isError: false);
      await _loadUsers();
    } catch (e) {
      _showSnackBar('Failed to approve: $e',
          isError: true);
    }
  }

  Future<void> _reject(String uid) async {
    final user = allUsers.firstWhere(
        (u) => u['id'] == uid,
        orElse: () => {'name': 'User'});
    final name = user['name'].toString();
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Verification',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject verification for $name?',
                style: GoogleFonts.inter()),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w500),
                hintText:
                    'e.g. Incomplete documents submitted',
                hintStyle: GoogleFonts.inter(
                    color: AppColors.mutedText,
                    fontSize: 13),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.brandRed,
                      width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.softWhite,
              ),
            ),
          ],
        ),
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
            child: Text('Reject',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirm != true || !mounted) return;

    try {
      final update = <String, dynamic>{
        'verificationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy':
            FirebaseAuth.instance.currentUser?.uid,
      };
      if (reason.isNotEmpty) {
        update['rejectionReason'] = reason;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(update);
      _showSnackBar('Verification rejected for $name',
          isError: false);
      await _loadUsers();
    } catch (e) {
      _showSnackBar('Failed to reject: $e',
          isError: true);
    }
  }

  Future<void> _changeRole(
      String uid, String currentRole) async {
    String selected = currentRole;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Change Role',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select a new role for this user:',
                  style: GoogleFonts.inter()),
              const SizedBox(height: 16),
              ...['alumni', 'admin', 'registrar',
                  'staff', 'moderator'].map(
                (role) => RadioListTile<String>(
                  value: role,
                  groupValue: selected,
                  activeColor: AppColors.brandRed,
                  title: Text(role.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  onChanged: (v) =>
                      setSt(() => selected = v!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: AppColors.mutedText)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              child: Text('Save',
                  style: GoogleFonts.inter(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'role': selected});
      _showSnackBar('Role updated to $selected',
          isError: false);
      await _loadUsers();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _toggleSuspend(
      String uid, String currentStatus) async {
    final isSuspended = currentStatus == 'suspended';
    final action =
        isSuspended ? 'Unsuspend' : 'Suspend';
    final confirm = await _confirmDialog(
      title: '$action User',
      message: isSuspended
          ? 'Restore access for this user?'
          : 'Suspend this user? They will not be able to log in.',
      confirmText: action,
      confirmColor:
          isSuspended ? Colors.green : Colors.orange,
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'status':
            isSuspended ? 'active' : 'suspended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar(
          isSuspended
              ? 'User unsuspended'
              : 'User suspended',
          isError: false);
      await _loadUsers();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteUser(
      String uid, String name) async {
    final confirm = await _confirmDialog(
      title: 'Delete User',
      message:
          'Permanently delete $name? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
      _showSnackBar('User deleted', isError: false);
      await _loadUsers();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700)),
        content:
            Text(message, style: GoogleFonts.inter()),
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
            child: Text(confirmText,
                style: GoogleFonts.inter(
                    color: confirmColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final created = user['createdAt'] as DateTime?;
    final lastLogin = user['lastLogin'] as DateTime?;
    final verifiedAt =
        user['verifiedAt'] as DateTime?;
    final rejectedAt =
        user['rejectedAt'] as DateTime?;
    final status = user['status'].toString();
    final verStatus =
        user['verificationStatus'].toString();
    final isPending = status == 'pending' ||
        verStatus == 'pending';
    final uid = user['id'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ─── Handle ───
              Container(
                margin: const EdgeInsets.symmetric(
                    vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),

              // ─── Header ───
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24),
                child: Row(
                  children: [
                    Text('User Profile',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    AppColors.darkText)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.mutedText),
                      onPressed: () =>
                          Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const Divider(
                  color: AppColors.borderSubtle,
                  height: 1),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ─── Profile hero ───
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              AppColors.brandRed
                                  .withOpacity(0.08),
                          backgroundImage:
                              user['profilePictureUrl'] !=
                                      null
                                  ? NetworkImage(user[
                                          'profilePictureUrl']
                                      .toString())
                                  : null,
                          child:
                              user['profilePictureUrl'] ==
                                      null
                                  ? Text(
                                      user['name']
                                              .toString()
                                              .isNotEmpty
                                          ? user['name']
                                              .toString()[0]
                                              .toUpperCase()
                                          : '?',
                                      style: GoogleFonts
                                          .cormorantGaramond(
                                              fontSize:
                                                  28,
                                              color: AppColors
                                                  .brandRed,
                                              fontWeight:
                                                  FontWeight
                                                      .w600))
                                  : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name'].toString(),
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        AppColors.darkText),
                              ),
                              if (user['headline']
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user['headline']
                                      .toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors
                                          .mutedText),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(children: [
                                _badge(
                                    user['role']
                                        .toString()
                                        .toUpperCase(),
                                    AppColors.brandRed),
                                const SizedBox(width: 6),
                                _badge(
                                    status.toUpperCase(),
                                    _statusColor(status)),
                                const SizedBox(width: 6),
                                _badge(
                                    verStatus.toUpperCase(),
                                    _verColor(verStatus)),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ─── Stats row ───
                    Row(children: [
                      _statMini(
                          'Connections',
                          user['connectionsCount']
                              .toString()),
                      const SizedBox(width: 12),
                      _statMini(
                          'Followers',
                          user['followersCount']
                              .toString()),
                      const SizedBox(width: 12),
                      _statMini(
                          'Batch',
                          user['batch'].toString()),
                    ]),

                    const SizedBox(height: 20),

                    // ─── Info card ───
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppColors.borderSubtle),
                      ),
                      child: Column(children: [
                        _infoRow(Icons.email_outlined,
                            'Email',
                            user['email'].toString()),
                        _divider(),
                        _infoRow(
                            Icons.school_outlined,
                            'Course',
                            user['course'].toString()),
                        _divider(),
                        _infoRow(
                            Icons.location_on_outlined,
                            'Location',
                            user['location'].toString()),
                        _divider(),
                        _infoRow(Icons.phone_outlined,
                            'Phone',
                            user['phone'].toString()),
                        _divider(),
                        _infoRow(
                            Icons.calendar_today_outlined,
                            'Joined',
                            created != null
                                ? DateFormat(
                                        'MMM dd, yyyy • HH:mm')
                                    .format(created)
                                : '—'),
                        _divider(),
                        _infoRow(
                            Icons.access_time_outlined,
                            'Last Login',
                            lastLogin != null
                                ? DateFormat(
                                        'MMM dd, yyyy • HH:mm')
                                    .format(lastLogin)
                                : '—'),
                        if (verifiedAt != null) ...[
                          _divider(),
                          _infoRow(
                              Icons
                                  .verified_user_outlined,
                              'Verified On',
                              DateFormat(
                                      'MMM dd, yyyy • HH:mm')
                                  .format(verifiedAt)),
                        ],
                        if (rejectedAt != null) ...[
                          _divider(),
                          _infoRow(
                              Icons.cancel_outlined,
                              'Rejected On',
                              DateFormat(
                                      'MMM dd, yyyy • HH:mm')
                                  .format(rejectedAt)),
                          if (user['rejectionReason']
                                  .toString()
                                  .isNotEmpty) ...[
                            _divider(),
                            _infoRow(
                                Icons.info_outline,
                                'Rejection Reason',
                                user['rejectionReason']
                                    .toString()),
                          ],
                        ],
                      ]),
                    ),

                    if (user['about']
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('About',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w700,
                                    color: AppColors
                                        .mutedText,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              user['about'].toString(),
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.darkText,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ─── Action buttons ───
                    if (isPending) ...[
                      Text('VERIFICATION',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedText,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _approve(uid);
                            },
                            icon: const Icon(
                                Icons.check_circle,
                                size: 16),
                            label: Text('Approve',
                                style: GoogleFonts.inter(
                                    fontWeight:
                                        FontWeight.w600)),
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.green,
                              foregroundColor:
                                  Colors.white,
                              padding: const EdgeInsets
                                  .symmetric(vertical: 12),
                              shape:
                                  RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _reject(uid);
                            },
                            icon: const Icon(Icons.cancel,
                                size: 16),
                            label: Text('Reject',
                                style: GoogleFonts.inter(
                                    fontWeight:
                                        FontWeight.w600)),
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.brandRed,
                              foregroundColor:
                                  Colors.white,
                              padding: const EdgeInsets
                                  .symmetric(vertical: 12),
                              shape:
                                  RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  10)),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    Text('ACCOUNT ACTIONS',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedText,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),

                    Row(children: [
                      Expanded(
                        child: _actionBtn(
                          icon: Icons
                              .manage_accounts_outlined,
                          label: 'Change Role',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pop(ctx);
                            _changeRole(uid,
                                user['role'].toString());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          icon: status == 'suspended'
                              ? Icons.lock_open_outlined
                              : Icons.block_outlined,
                          label: status == 'suspended'
                              ? 'Unsuspend'
                              : 'Suspend',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.pop(ctx);
                            _toggleSuspend(uid, status);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          color: Colors.red,
                          onTap: () {
                            Navigator.pop(ctx);
                            _deleteUser(uid,
                                user['name'].toString());
                          },
                        ),
                      ),
                    ]),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4)),
    );
  }

  Widget _statMini(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.mutedText)),
        ]),
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon,
            size: 16, color: AppColors.mutedText),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _divider() => const Divider(
      height: 1, color: AppColors.borderSubtle);

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'suspended':
        return Colors.red.shade700;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.mutedText;
    }
  }

  Color _verColor(String s) {
    switch (s.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
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
          // ─── Sidebar ───
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  right: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('ALUMNI',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  letterSpacing: 6,
                                  color: AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w300)),
                      const SizedBox(height: 6),
                      Text('ARCHIVE PORTAL',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sidebarSection('NETWORK', [
                          _sidebarItem('Overview',
                              route: '/admin_dashboard'),
                          _sidebarItem(
                              'Chapter Management',
                              route:
                                  '/chapter_management'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection('ENGAGEMENT', [
                          _sidebarItem(
                              'Reunions & Events',
                              route: '/reunions_events'),
                          _sidebarItem(
                              'Career Milestones',
                              route: '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ADMIN FEATURES', [
                          _sidebarItem(
                              'User Verification & Moderation',
                              route:
                                  '/user_verification_moderation',
                              isActive: true),
                          _sidebarItem('Event Planning',
                              route: '/event_planning'),
                          _sidebarItem(
                              'Job Board Management',
                              route:
                                  '/job_board_management'),
                          _sidebarItem('Growth Metrics',
                              route: '/growth_metrics'),
                          _sidebarItem(
                              'Announcement Management',
                              route:
                                  '/announcement_management'),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: AppColors.borderSubtle
                                .withOpacity(0.3))),
                  ),
                  child: Column(children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.brandRed
                                .withOpacity(0.1),
                        child: Text(
                          _adminName.isNotEmpty
                              ? _adminName[0]
                                  .toUpperCase()
                              : 'A',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  color: AppColors.brandRed,
                                  fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(_adminName,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.bold),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                            Text(_adminRole,
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color:
                                        AppColors.mutedText)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance
                              .signOut();
                          if (mounted) {
                            Navigator
                                .pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (r) => false);
                          }
                        },
                        icon: const Icon(Icons.logout,
                            size: 13,
                            color: AppColors.mutedText),
                        label: Text('DISCONNECT',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: AppColors.mutedText,
                                fontWeight:
                                    FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ─── Main content ───
          Expanded(
            child: Column(
              children: [
                // ─── Top bar ───
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Trust & Safety Dashboard',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      fontSize: 32,
                                      fontWeight:
                                          FontWeight.w400,
                                      color:
                                          AppColors.darkText)),
                          Text(
                              'Verify identities and moderate community interactions.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh,
                            size: 16),
                        label: Text('Refresh',
                            style: GoogleFonts.inter(
                                fontWeight:
                                    FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Stats chips ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      40, 10, 40, 10),
                  child: Row(children: [
                    _statChip('Total',
                        allUsers.length.toString(),
                        AppColors.mutedText),
                    const SizedBox(width: 10),
                    _statChip(
                        'Pending',
                        pendingUsers.length.toString(),
                        Colors.orange),
                    const SizedBox(width: 10),
                    _statChip(
                        'Queue',
                        verificationQueue.length
                            .toString(),
                        AppColors.brandRed),
                  ]),
                ),

                // ─── Tabs + search ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      40, 0, 40, 12),
                  child: Column(children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _tabBtn('All Users', 0),
                        const SizedBox(width: 8),
                        _tabBtn('Pending', 1),
                        const SizedBox(width: 8),
                        _tabBtn('Recent Logins', 2),
                        const SizedBox(width: 8),
                        _tabBtn(
                            'Verification Queue', 3),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 400,
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(
                            fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Search name, email, role...',
                          hintStyle: GoogleFonts.inter(
                              color: AppColors.mutedText,
                              fontSize: 13),
                          prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.brandRed,
                              size: 18),
                          filled: true,
                          fillColor: AppColors.softWhite,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16),
                        ),
                      ),
                    ),
                  ]),
                ),

                // ─── Table ───
                Expanded(
                  child: isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                                  color:
                                      AppColors.brandRed))
                      : errorMessage != null
                          ? Center(
                              child: Text(errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.red)))
                          : _buildTable(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final data = _filtered;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline,
                size: 72, color: AppColors.borderSubtle),
            const SizedBox(height: 16),
            Text(
              _currentTab == 3
                  ? 'No pending verification requests'
                  : 'No users found',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22, color: AppColors.darkText),
            ),
          ],
        ),
      );
    }

    final isVerTab = _currentTab == 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStatePropertyAll(
              AppColors.softWhite),
          headingTextStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
              letterSpacing: 0.5),
          dataTextStyle: GoogleFonts.inter(
              fontSize: 13, color: AppColors.darkText),
          columns: const [
            DataColumn(label: Text('USER')),
            DataColumn(label: Text('ROLE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('VER. STATUS')),
            DataColumn(label: Text('BATCH')),
            DataColumn(label: Text('JOINED')),
            DataColumn(label: Text('LAST LOGIN')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: data.map((user) {
            final created =
                user['createdAt'] as DateTime?;
            final lastLogin =
                user['lastLogin'] as DateTime?;
            final status = user['status'].toString();
            final verStatus =
                user['verificationStatus'].toString();
            final isPending = status == 'pending' ||
                verStatus == 'pending';
            final uid = user['id'].toString();

            return DataRow(cells: [
              // ─── User cell ───
              DataCell(Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.brandRed.withOpacity(0.1),
                  backgroundImage:
                      user['profilePictureUrl'] != null
                          ? NetworkImage(
                              user['profilePictureUrl']
                                  .toString())
                          : null,
                  child: user['profilePictureUrl'] == null
                      ? Text(
                          user['name']
                                  .toString()
                                  .isNotEmpty
                              ? user['name']
                                  .toString()[0]
                                  .toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                              color: AppColors.brandRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(user['name'].toString(),
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text(user['email'].toString(),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.mutedText)),
                    ]),
              ])),
              DataCell(_badge(
                  user['role'].toString().toUpperCase(),
                  AppColors.brandRed)),
              DataCell(_badge(
                  status.toUpperCase(),
                  _statusColor(status))),
              DataCell(_badge(
                  verStatus.toUpperCase(),
                  _verColor(verStatus))),
              DataCell(
                  Text(user['batch'].toString())),
              DataCell(Text(created != null
                  ? DateFormat('MMM dd, yyyy')
                      .format(created)
                  : '—')),
              DataCell(Text(lastLogin != null
                  ? DateFormat('MMM dd, yyyy')
                      .format(lastLogin)
                  : '—')),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'View Profile',
                    child: GestureDetector(
                      onTap: () =>
                          _showUserDetails(user),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brandRed
                              .withOpacity(0.08),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: const Icon(
                            Icons.visibility_outlined,
                            color: AppColors.brandRed,
                            size: 16),
                      ),
                    ),
                  ),
                  if (isVerTab && isPending) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Approve',
                      child: GestureDetector(
                        onTap: () => _approve(uid),
                        child: Container(
                          padding:
                              const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green
                                .withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Reject',
                      child: GestureDetector(
                        onTap: () => _reject(uid),
                        child: Container(
                          padding:
                              const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red
                                .withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                              size: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statChip(
      String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandRed
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? AppColors.brandRed
                  : AppColors.borderSubtle),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: active
                    ? Colors.white
                    : AppColors.darkText,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }

  Widget _sidebarSection(
      String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                color: AppColors.mutedText
                    .withOpacity(0.7))),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _sidebarItem(String label,
      {String? route, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null && !isActive
            ? () => Navigator.pushNamed(context, route)
            : null,
        child: MouseRegion(
          cursor: route != null && !isActive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: isActive
                      ? AppColors.brandRed
                      : AppColors.darkText,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w400)),
        ),
      ),
    );
  }
}