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
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  int pendingCount = 0;

  bool isLoading = true;
  bool isActionInProgress = false;
  String? errorMessage;

  String statusFilter = 'all';
  String searchQuery = '';

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final querySnap = await firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final users = querySnap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'name': (data['name'] as String? ?? data['fullName'] as String? ?? 'Unknown').trim(),
          'email': (data['email'] as String? ?? '—').trim(),
          'degree': (data['degree'] as String? ?? '').trim(),
          'batchYear': (data['batchYear'] as String? ?? data['batch'] as String? ?? '').trim(),
          'status': (data['status'] as String? ?? 'unknown').toLowerCase(),
          'submitted': _formatTimestamp(data['createdAt'] as Timestamp?),
          'profilePhotoUrl': data['profilePhotoUrl'] as String?,
          'idPhotoFrontUrl': data['idPhotoFrontUrl'] as String?,
          'idPhotoBackUrl': data['idPhotoBackUrl'] as String?,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        allUsers = users;
        pendingCount = users.where((u) => u['status'] == 'pending').length;
        _applyFilters();
        isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Failed to load users: $e\n$stack');
      if (mounted) {
        setState(() {
          errorMessage = 'Unable to load users.\nPlease try again.';
          isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var temp = List<Map<String, dynamic>>.from(allUsers);

    if (statusFilter != 'all') {
      temp = temp.where((u) => u['status'] == statusFilter).toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      temp = temp.where((u) {
        final name = (u['name'] as String?)?.toLowerCase() ?? '';
        final email = (u['email'] as String?)?.toLowerCase() ?? '';
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    if (mounted) {
      setState(() => filteredUsers = temp);
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final date = ts.toDate();
    final now = DateTime.now();
    if (date.isAfter(now.subtract(const Duration(days: 2)))) {
      return DateFormat('h:mm a').format(date);
    }
    if (date.year == now.year) {
      return DateFormat('MMM d • h:mm a').format(date);
    }
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  Future<void> _performAction(
    Future<void> Function() action, {
    required String successMessage,
    required String errorPrefix,
    required Color successColor,
  }) async {
    if (isActionInProgress || !mounted) return;
    setState(() => isActionInProgress = true);

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: successColor,
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorPrefix: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isActionInProgress = false);
    }
  }

  Future<void> _verifyUser(String uid) => _performAction(
        () => FirebaseFirestore.instance.collection('users').doc(uid).update({
          'status': 'verified',
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        successMessage: 'User verified successfully',
        errorPrefix: 'Verification failed',
        successColor: AppColors.success,
      );

  Future<void> _denyOrBanUser(String uid, String currentStatus) async {
    final reasonCtrl = TextEditingController();

    final title = currentStatus == 'pending' ? 'Deny Verification' : 'Ban User';

    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a reason (optional but recommended):'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'e.g. Invalid documents, policy violation...',
                hintStyle: GoogleFonts.inter(color: AppColors.mutedText),
              ),
              maxLines: 3,
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _performAction(
      () => FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'denied',
        'deniedReason': reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
        'deniedAt': FieldValue.serverTimestamp(),
        'deniedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      successMessage: 'User denied/banned successfully',
      errorPrefix: 'Action failed',
      successColor: AppColors.warning,
    );
  }

  Future<void> _reinstateUser(String uid) => _performAction(
        () => FirebaseFirestore.instance.collection('users').doc(uid).update({
          'status': 'verified',
          'reinstatedAt': FieldValue.serverTimestamp(),
          'reinstatedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'deniedReason': FieldValue.delete(),
        }),
        successMessage: 'User reinstated successfully',
        errorPrefix: 'Reinstate failed',
        successColor: AppColors.success,
      );

  Future<void> _deleteUser(String uid) async {
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _performAction(
      () => FirebaseFirestore.instance.collection('users').doc(uid).delete(),
      successMessage: 'User deleted successfully',
      errorPrefix: 'Delete failed',
      successColor: AppColors.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'User Verification & Moderation',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          if (isActionInProgress)
            const Padding(
              padding: EdgeInsets.only(right: 24),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.brandRed),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.brandRed),
              onPressed: isLoading ? null : _loadUsers,
              tooltip: 'Refresh',
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: isLoading || isActionInProgress ? () async {} : _loadUsers,
        color: AppColors.brandRed,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
            : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                      child: SelectableText(
                        errorMessage!,
                        style: GoogleFonts.inter(
                          color: AppColors.error,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(64, 24, 64, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                decoration: const InputDecoration(
                                  labelText: 'Search by name or email',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                  filled: true,
                                  fillColor: AppColors.cardWhite,
                                ),
                                onChanged: (value) {
                                  searchQuery = value;
                                  _applyFilters();
                                },
                              ),
                            ),
                            const SizedBox(width: 24),
                            DropdownButton<String>(
                              value: statusFilter,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All')),
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'verified', child: Text('Verified')),
                                DropdownMenuItem(value: 'denied', child: Text('Denied')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    statusFilter = value;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(64, 0, 64, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Management',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 48,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pending verifications: $pendingCount',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  letterSpacing: 0.8,
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 48),

                              if (filteredUsers.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 120),
                                    child: Text(
                                      'No users match the current filters.',
                                      style: GoogleFonts.inter(
                                        color: AppColors.mutedText,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(AppColors.softWhite),
                                    dataRowMinHeight: 72,
                                    dataRowMaxHeight: 96,
                                    columnSpacing: 24,
                                    columns: const [
                                      DataColumn(label: _HeaderLabel('ALUMNUS')),
                                      DataColumn(label: _HeaderLabel('EMAIL')),
                                      DataColumn(label: _HeaderLabel('BATCH / DEGREE')),
                                      DataColumn(label: _HeaderLabel('STATUS')),
                                      DataColumn(label: _HeaderLabel('SUBMITTED')),
                                      DataColumn(label: _HeaderLabel('IMAGES')),
                                      DataColumn(label: _HeaderLabel('ACTIONS')),
                                    ],
                                    rows: filteredUsers.map(_buildRow).toList(),
                                  ),
                                ),

                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> user) {
    final degree = user['degree'] as String? ?? '';
    final batchYear = user['batchYear'] as String? ?? '';
    final degreeBatch = (degree.isNotEmpty && batchYear.isNotEmpty)
        ? '$degree • $batchYear'
        : (degree.isNotEmpty ? degree : (batchYear.isNotEmpty ? batchYear : '—'));

    final status = (user['status'] as String?)?.toLowerCase() ?? 'unknown';

    return DataRow(
      cells: [
        DataCell(
          Text(
            user['name'] as String? ?? 'Unknown',
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Text(
            user['email'] as String? ?? '—',
            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.mutedText),
          ),
        ),
        DataCell(
          Text(
            degreeBatch,
            style: GoogleFonts.inter(fontSize: 12.5),
          ),
        ),
        DataCell(_buildStatusChip(status)),
        DataCell(
          Text(
            user['submitted'] as String? ?? 'N/A',
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.mutedText),
          ),
        ),
        DataCell(
          TextButton(
            onPressed: () => _showImages(user),
            child: Text(
              'View',
              style: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending') ...[
                _ActionButton('Verify', Icons.check_circle_outline, AppColors.success, () => _verifyUser(user['id'] as String)),
                _ActionButton('Deny', Icons.block, AppColors.warning, () => _denyOrBanUser(user['id'] as String, status)),
              ] else if (status == 'verified') ...[
                _ActionButton('Edit', Icons.edit, AppColors.info, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit feature coming soon')),
                  );
                }),
                _ActionButton('Ban', Icons.block, AppColors.warning, () => _denyOrBanUser(user['id'] as String, status)),
              ] else if (status == 'denied') ...[
                _ActionButton('Reinstate', Icons.restore, AppColors.success, () => _reinstateUser(user['id'] as String)),
              ],
              _ActionButton('Delete', Icons.delete_outline, AppColors.error, () => _deleteUser(user['id'] as String)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'verified':
        color = AppColors.success;
        label = 'VERIFIED';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'PENDING';
        break;
      case 'denied':
        color = AppColors.error;
        label = 'DENIED';
        break;
      default:
        color = AppColors.mutedText;
        label = 'UNKNOWN';
    }

    return Chip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showImages(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Images'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user['profilePhotoUrl'] != null) ...[
                const Text('Profile Photo:'),
                Image.network(user['profilePhotoUrl'] as String, height: 200, errorBuilder: (_, __, ___) => const Text('Error loading image')),
                const SizedBox(height: 16),
              ],
              if (user['idPhotoFrontUrl'] != null) ...[
                const Text('ID Front:'),
                Image.network(user['idPhotoFrontUrl'] as String, height: 200, errorBuilder: (_, __, ___) => const Text('Error loading image')),
                const SizedBox(height: 16),
              ],
              if (user['idPhotoBackUrl'] != null) ...[
                const Text('ID Back:'),
                Image.network(user['idPhotoBackUrl'] as String, height: 200, errorBuilder: (_, __, ___) => const Text('Error loading image')),
              ],
              if (user['profilePhotoUrl'] == null && user['idPhotoFrontUrl'] == null && user['idPhotoBackUrl'] == null)
                const Text('No images available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;

  const _HeaderLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
        color: AppColors.mutedText,
      ),
    );
  }
}

Widget _ActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
  return TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18, color: color),
    label: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
  );
}