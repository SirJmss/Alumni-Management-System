import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:alumni/features/admin/data/models/alumni_registry_models.dart';
import 'package:alumni/features/admin/data/services/csv_parser.dart';
import 'package:alumni/features/admin/data/services/excel_parser.dart';
import 'package:alumni/features/admin/data/services/registry_service.dart';

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() =>
      _UserVerificationScreenState();
}

class _UserVerificationScreenState
    extends State<UserVerificationScreen> {
  // 0=All, 1=Rejected, 2=Recent, 3=Queue, 4=Registry
  int _currentTab = 3;

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> rejectedUsers = [];
  List<Map<String, dynamic>> recentLogins = [];
  List<Map<String, dynamic>> verificationQueue = [];

  bool isLoading = true;
  String? errorMessage;
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';

  final _searchController = TextEditingController();
  String _searchText = '';

  final _registryService = RegistryService();
  bool _isUploading = false;
  String _registrySearch = '';
  int _registryTab = 0;
  String? _selectedUploadId;
  final _registrySearchCtrl = TextEditingController();

  final Map<String, AlumniRecord?> _matchCache = {};
  bool _loadingMatches = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(
        () => _searchText =
            _searchController.text.trim().toLowerCase()));
    _registrySearchCtrl.addListener(() => setState(
        () => _registrySearch =
            _registrySearchCtrl.text.trim()));
    _loadAdminProfile();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _registrySearchCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════
  //  DATA LOADERS
  // ══════════════════════════════════════════

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
          'name':
              (d['name'] ?? d['fullName'] ?? 'Unknown')
                  .toString()
                  .trim(),
          'email': d['email']?.toString() ?? '—',
          'role': d['role']?.toString() ?? 'alumni',
          'status':
              d['status']?.toString() ?? 'active',
          'verificationStatus':
              d['verificationStatus']?.toString() ??
                  'none',
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
                  (d['lastActive'] as Timestamp?)
                      ?.toDate(),
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
          'registryMatchId':
              d['registryMatchId']?.toString() ?? '',
          'matchConfidence':
              (d['matchConfidence'] as num?)
                      ?.toDouble() ??
                  0.0,
          'verifiedBy':
              d['verifiedBy']?.toString() ?? '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        allUsers = list;

        // ─── Tab 1: Rejected accounts ───
        rejectedUsers = list.where((u) {
          final status = u['status'].toString();
          final ver =
              u['verificationStatus'].toString();
          return status == 'denied' ||
              status == 'rejected' ||
              ver == 'rejected';
        }).toList();

        recentLogins = List.from(list)
          ..sort((a, b) {
            final aT = a['lastLogin'] as DateTime?;
            final bT = b['lastLogin'] as DateTime?;
            return (bT ?? DateTime(2000))
                .compareTo(aT ?? DateTime(2000));
          });

        // ─── Queue: only truly pending, exclude rejected ───
        verificationQueue = list.where((u) {
          final status = u['status'].toString();
          final ver =
              u['verificationStatus'].toString();
          final isRejected = status == 'denied' ||
              status == 'rejected' ||
              ver == 'rejected';
          final isPending = status == 'pending' ||
              ver == 'pending';
          return isPending && !isRejected;
        }).toList();

        isLoading = false;
      });

      await _loadMatchesForQueue();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load users: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadMatchesForQueue() async {
    if (!mounted) return;
    setState(() => _loadingMatches = true);

    final queue = verificationQueue;
    final newCache = <String, AlumniRecord?>{};

    for (final user in queue) {
      final uid = user['id'].toString();
      final matchId =
          user['registryMatchId'].toString();

      if (matchId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('alumni_registry')
              .doc(matchId)
              .get();
          if (doc.exists) {
            newCache[uid] = AlumniRecord.fromMap(
                doc.id, doc.data()!);
          } else {
            newCache[uid] = null;
          }
        } catch (_) {
          newCache[uid] = null;
        }
      } else {
        try {
          final result =
              await _registryService.checkUser(
            fullName: user['name'].toString(),
            batch: user['batch'].toString(),
            course: user['course'].toString(),
            email: user['email'].toString(),
          );
          newCache[uid] =
              result.isMatch ? result.record : null;
        } catch (_) {
          newCache[uid] = null;
        }
      }
    }

    if (mounted) {
      setState(() {
        _matchCache.addAll(newCache);
        _loadingMatches = false;
      });
    }
  }

  // ══════════════════════════════════════════
  //  REGISTRY UPLOAD
  // ══════════════════════════════════════════

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnackBar('Could not read file bytes.',
          isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      List<AlumniRecord> records = [];
      final ext =
          (file.extension ?? '').toLowerCase();
      const tempBatchId = 'temp';

      if (ext == 'csv') {
        final content = String.fromCharCodes(bytes);
        records =
            CsvParser.parse(content, tempBatchId);
      } else if (ext == 'xlsx' || ext == 'xls') {
        records = ExcelParser.parse(
            bytes.toList(), tempBatchId);
      } else {
        _showSnackBar('Unsupported file type.',
            isError: true);
        setState(() => _isUploading = false);
        return;
      }

      if (records.isEmpty) {
        _showSnackBar(
            'No valid records found. Check column headers.',
            isError: true);
        setState(() => _isUploading = false);
        return;
      }

      final confirmed = await _showUploadPreviewDialog(
          records, file.name);
      if (confirmed != true) {
        setState(() => _isUploading = false);
        return;
      }

      final upload =
          await _registryService.uploadRecords(
        records: records,
        fileName: file.name,
        uploadedByName: _adminName,
      );

      if (mounted) {
        _showSnackBar(
            'Uploaded ${upload.totalRecords} records. '
            '${upload.matchedCount} auto-matched.',
            isError: false);
        setState(() {
          _registryTab = 0;
          _selectedUploadId = null;
        });
        await _loadUsers();
      }
    } catch (e) {
      _showSnackBar('Upload failed: $e',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<bool?> _showUploadPreviewDialog(
      List<AlumniRecord> records, String fileName) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.upload_file,
              color: AppColors.brandRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Confirm Upload',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
        ]),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _previewInfoRow('File', fileName),
              _previewInfoRow('Records found',
                  '${records.length}'),
              const SizedBox(height: 12),
              Text('Preview (first 5 rows):',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.borderSubtle),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 36,
                    headingTextStyle: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedText),
                    dataTextStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.darkText),
                    columns: const [
                      DataColumn(
                          label: Text('FULL NAME')),
                      DataColumn(
                          label: Text('BATCH')),
                      DataColumn(
                          label: Text('COURSE')),
                      DataColumn(
                          label: Text('EMAIL')),
                    ],
                    rows: records.take(5).map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r.fullName)),
                        DataCell(Text(r.batch.isEmpty
                            ? '—'
                            : r.batch)),
                        DataCell(Text(r.course.isEmpty
                            ? '—'
                            : r.course)),
                        DataCell(Text(r.email.isEmpty
                            ? '—'
                            : r.email)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              if (records.length > 5)
                Padding(
                  padding:
                      const EdgeInsets.only(top: 6),
                  child: Text(
                      '...and ${records.length - 5} more records',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
            child: Text(
                'Upload ${records.length} Records',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _previewInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$label: ',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.darkText)),
      ]),
    );
  }

  Future<void> _confirmDeleteUpload(
      RegistryUpload upload) async {
    final confirmed = await _confirmDialog(
      title: 'Delete Upload Batch',
      message:
          'Delete "${upload.fileName}" and all ${upload.totalRecords} records? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;
    try {
      await _registryService.deleteUpload(upload.id);
      _showSnackBar('Upload batch deleted.',
          isError: false);
      setState(() => _selectedUploadId = null);
    } catch (e) {
      _showSnackBar('Delete failed: $e',
          isError: true);
    }
  }

  // ══════════════════════════════════════════
  //  USER ACTIONS
  // ══════════════════════════════════════════

  List<Map<String, dynamic>> get _filtered {
    final list = switch (_currentTab) {
      0 => allUsers,
      1 => rejectedUsers,
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
      final ver =
          u['verificationStatus'].toString().toLowerCase();
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
        content:
            Text(msg, style: GoogleFonts.inter()),
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

      final match = _matchCache[uid];
      if (match != null) {
        await FirebaseFirestore.instance
            .collection('alumni_registry')
            .doc(match.id)
            .update({
          'isMatched': true,
          'matchedUserId': uid,
        });
      }

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
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
        'status': 'rejected',
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

      // ─── Remove from local queue immediately ───
      if (mounted) {
        setState(() {
          verificationQueue.removeWhere(
              (u) => u['id'].toString() == uid);
          _matchCache.remove(uid);
        });
      }

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
              Text('Select a new role:',
                  style: GoogleFonts.inter()),
              const SizedBox(height: 16),
              ...[
                'alumni',
                'admin',
                'registrar',
                'staff',
                'moderator'
              ].map(
                (role) => RadioListTile<String>(
                  value: role,
                  groupValue: selected,
                  activeColor: AppColors.brandRed,
                  title: Text(role.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w500)),
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
    final isSuspended =
        currentStatus == 'suspended';
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

  // ══════════════════════════════════════════
  //  VERIFICATION QUEUE VIEW
  // ══════════════════════════════════════════

  Widget _buildVerificationQueueView() {
    final data = _filtered;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.how_to_reg_outlined,
                size: 72,
                color: AppColors.borderSubtle),
            const SizedBox(height: 16),
            Text('No pending verification requests',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(
                'New registrations will appear here for review.',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: AppColors.softWhite,
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(
                  '${data.length} applicant${data.length == 1 ? '' : 's'} awaiting review',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w500)),
            ),
            if (_loadingMatches)
              Row(children: [
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandRed)),
                const SizedBox(width: 8),
                Text('Loading registry matches...',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedText)),
              ]),
            const SizedBox(width: 12),
            _legendChip(Colors.green, 'Registry Match'),
            const SizedBox(width: 8),
            _legendChip(Colors.orange, 'No Match'),
            const SizedBox(width: 8),
            _legendChip(Colors.blue, 'Auto-Verified'),
          ]),
        ),
        Container(
          color: AppColors.softWhite,
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 8),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Row(children: [
                const SizedBox(width: 8),
                Text('REGISTERED APPLICANT',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedText,
                        letterSpacing: 0.8)),
              ]),
            ),
            Container(
                width: 1,
                height: 16,
                color: AppColors.borderSubtle),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text('MATCHED REGISTRY RECORD',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedText,
                        letterSpacing: 0.8)),
              ),
            ),
            const SizedBox(width: 160),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _buildMatchCard(data[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> user) {
    final uid = user['id'].toString();
    final status = user['status'].toString();
    final verStatus =
        user['verificationStatus'].toString();
    final match = _matchCache[uid];
    final confidence =
        (user['matchConfidence'] as double?) ?? 0.0;
    final hasMatch = match != null;
    final isAutoVerified =
        user['verifiedBy'].toString() == 'system_auto';
    final created = user['createdAt'] as DateTime?;

    Color accentColor;
    if (isAutoVerified) {
      accentColor = Colors.blue;
    } else if (hasMatch) {
      accentColor = Colors.green;
    } else {
      accentColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11)),
            ),
            child: Row(children: [
              Icon(
                isAutoVerified
                    ? Icons.auto_awesome
                    : hasMatch
                        ? Icons.link
                        : Icons.help_outline,
                size: 14,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAutoVerified
                      ? 'Auto-verified via registry match'
                      : hasMatch
                          ? 'Registry match found (${(confidence * 100).toStringAsFixed(0)}% confidence)'
                          : 'No registry match found — manual review required',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor),
                ),
              ),
              if (created != null)
                Text(
                    'Applied ${DateFormat('MMM dd, yyyy').format(created)}',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.mutedText)),
            ]),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: _buildUserPanel(user),
                  ),
                ),
                Container(
                  width: 1,
                  color:
                      accentColor.withOpacity(0.15),
                  margin: const EdgeInsets.symmetric(
                      vertical: 12),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: hasMatch
                        ? _buildRegistryPanel(
                            match, confidence)
                        : _buildNoMatchPanel(),
                  ),
                ),
                Container(
                  width: 160,
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      _matchField(
                          'Status',
                          _statusBadgeRow(
                              status, verStatus)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _approve(uid),
                          icon: const Icon(
                              Icons
                                  .check_circle_outline,
                              size: 14),
                          label: Text('Approve',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700)),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green,
                            foregroundColor:
                                Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets
                                .symmetric(
                                vertical: 10),
                            shape:
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                                8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _reject(uid),
                          icon: const Icon(
                              Icons.cancel_outlined,
                              size: 14),
                          label: Text('Reject',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700)),
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                AppColors.brandRed,
                            side: const BorderSide(
                                color:
                                    AppColors.brandRed),
                            padding: const EdgeInsets
                                .symmetric(
                                vertical: 10),
                            shape:
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                                8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () =>
                              _showUserDetails(user),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                AppColors.mutedText,
                            padding: const EdgeInsets
                                .symmetric(
                                vertical: 8),
                          ),
                          child: Text('View Profile',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPanel(Map<String, dynamic> user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(user['name'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                Text(user['email'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedText),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _infoGrid([
          ['Batch', user['batch'].toString()],
          ['Course', user['course'].toString()],
          ['Phone', user['phone'].toString()],
          ['Location', user['location'].toString()],
        ]),
      ],
    );
  }

  Widget _buildRegistryPanel(
      AlumniRecord record, double confidence) {
    final pct =
        (confidence * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user,
                color: Colors.green, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(record.fullName,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                Row(children: [
                  _confidenceBar(confidence),
                  const SizedBox(width: 6),
                  Text('$pct% match',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color:
                              Colors.green.shade700,
                          fontWeight:
                              FontWeight.w600)),
                ]),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _infoGrid([
          [
            'Batch',
            record.batch.isEmpty ? '—' : record.batch
          ],
          [
            'Course',
            record.course.isEmpty
                ? '—'
                : record.course
          ],
          [
            'Email',
            record.email.isEmpty ? '—' : record.email
          ],
          [
            'Student ID',
            record.studentId.isEmpty
                ? '—'
                : record.studentId
          ],
        ]),
      ],
    );
  }

  Widget _buildNoMatchPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.search_off,
              color: Colors.orange, size: 26),
        ),
        const SizedBox(height: 12),
        Text('No Registry Record Found',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
            'This applicant\'s credentials could not\nbe matched to the alumni registry.',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedText,
                height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color:
                    Colors.orange.withOpacity(0.3)),
          ),
          child: Text(
              'Requires manual identity verification',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _infoGrid(List<List<String>> rows) {
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
              width: 72,
              child: Text(row[0],
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ),
            Expanded(
              child: Text(
                  row[1].isEmpty ? '—' : row[1],
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.darkText,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _matchField(String label, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        value,
      ],
    );
  }

  Widget _statusBadgeRow(
      String status, String verStatus) {
    return Wrap(spacing: 4, runSpacing: 4, children: [
      _badge(status.toUpperCase(),
          _statusColor(status)),
      _badge(verStatus.toUpperCase(),
          _verColor(verStatus)),
    ]);
  }

  Widget _confidenceBar(double confidence) {
    return SizedBox(
      width: 60,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: confidence.clamp(0.0, 1.0),
          backgroundColor:
              Colors.green.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation(
            confidence >= 0.80
                ? Colors.green
                : confidence >= 0.65
                    ? Colors.lightGreen
                    : Colors.orange,
          ),
        ),
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.mutedText)),
    ]);
  }

  // ══════════════════════════════════════════
  //  USER DETAIL BOTTOM SHEET
  // ══════════════════════════════════════════

  void _showUserDetails(Map<String, dynamic> user) {
    final created =
        user['createdAt'] as DateTime?;
    final lastLogin =
        user['lastLogin'] as DateTime?;
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
                    Row(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            AppColors.brandRed
                                .withOpacity(0.08),
                        backgroundImage:
                            user['profilePictureUrl'] !=
                                    null
                                ? NetworkImage(
                                    user['profilePictureUrl']
                                        .toString())
                                : null,
                        child: user[
                                    'profilePictureUrl'] ==
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
                                        fontSize: 28,
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
                            Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _badge(
                                      user['role']
                                          .toString()
                                          .toUpperCase(),
                                      AppColors.brandRed),
                                  _badge(
                                      status.toUpperCase(),
                                      _statusColor(
                                          status)),
                                  _badge(
                                      verStatus
                                          .toUpperCase(),
                                      _verColor(
                                          verStatus)),
                                ]),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
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
                      _statMini('Batch',
                          user['batch'].toString()),
                    ]),
                    const SizedBox(height: 20),
                    Container(
                      padding:
                          const EdgeInsets.all(16),
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
                        _infoRow(Icons.school_outlined,
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
                            Icons
                                .calendar_today_outlined,
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
                                'Reason',
                                user['rejectionReason']
                                    .toString()),
                          ],
                        ],
                      ]),
                    ),

                    // ─── Matched registry record ───
                    if (_matchCache[uid] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding:
                            const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green
                              .withOpacity(0.05),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.green
                                  .withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(
                                  Icons.verified_user,
                                  color: Colors.green,
                                  size: 16),
                              const SizedBox(width: 8),
                              Text(
                                  'Matched Registry Record',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: Colors
                                          .green.shade700,
                                      letterSpacing:
                                          0.4)),
                            ]),
                            const SizedBox(height: 12),
                            _infoRow(
                                Icons.person_outline,
                                'Full Name',
                                _matchCache[uid]!
                                    .fullName),
                            _divider(),
                            _infoRow(
                                Icons.school_outlined,
                                'Batch',
                                _matchCache[uid]!
                                        .batch
                                        .isEmpty
                                    ? '—'
                                    : _matchCache[uid]!
                                        .batch),
                            _divider(),
                            _infoRow(
                                Icons.book_outlined,
                                'Course',
                                _matchCache[uid]!
                                        .course
                                        .isEmpty
                                    ? '—'
                                    : _matchCache[uid]!
                                        .course),
                            _divider(),
                            _infoRow(
                                Icons.email_outlined,
                                'Email',
                                _matchCache[uid]!
                                        .email
                                        .isEmpty
                                    ? '—'
                                    : _matchCache[uid]!
                                        .email),
                            _divider(),
                            _infoRow(
                                Icons.badge_outlined,
                                'Student ID',
                                _matchCache[uid]!
                                        .studentId
                                        .isEmpty
                                    ? '—'
                                    : _matchCache[uid]!
                                        .studentId),
                          ],
                        ),
                      ),
                    ],

                    if (user['about']
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(16),
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
                                    color:
                                        AppColors.mutedText,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              user['about'].toString(),
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.darkText,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
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
                                  .symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(10)),
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
                            icon: const Icon(
                                Icons.cancel,
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
                                  .symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(10)),
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

  // ══════════════════════════════════════════
  //  REGISTRY WIDGETS
  // ══════════════════════════════════════════

  Widget _buildRegistryTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.fromLTRB(40, 0, 40, 12),
          child: Row(
            children: [
              _regSubTab('Upload Batches', 0),
              const SizedBox(width: 8),
              _regSubTab('All Records', 1),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _registrySearchCtrl,
                  style:
                      GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _registryTab == 0
                        ? 'Search batches...'
                        : 'Search records...',
                    hintStyle: GoogleFonts.inter(
                        color: AppColors.mutedText,
                        fontSize: 12),
                    prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.brandRed,
                        size: 16),
                    filled: true,
                    fillColor: AppColors.softWhite,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isUploading
                    ? null
                    : _pickAndUploadFile,
                icon: _isUploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Icon(Icons.upload_file,
                        size: 16),
                label: Text(
                    _isUploading
                        ? 'Uploading...'
                        : 'Upload CSV / Excel',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _registryTab == 0
              ? _buildUploadsView()
              : _buildAllRecordsView(),
        ),
      ],
    );
  }

  Widget _buildUploadsView() {
    if (_selectedUploadId != null) {
      return _buildBatchRecordsView(
          _selectedUploadId!);
    }

    return StreamBuilder<List<RegistryUpload>>(
      stream: _registryService.uploadsStream(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(
                      color: Colors.red)));
        }

        final uploads =
            (snap.data ?? []).where((u) {
          if (_registrySearch.isEmpty) return true;
          return u.fileName
                  .toLowerCase()
                  .contains(_registrySearch
                      .toLowerCase()) ||
              u.uploadedByName
                  .toLowerCase()
                  .contains(
                      _registrySearch.toLowerCase());
        }).toList();

        if (uploads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const Icon(
                    Icons.cloud_upload_outlined,
                    size: 72,
                    color: AppColors.borderSubtle),
                const SizedBox(height: 16),
                Text('No registry uploads yet',
                    style:
                        GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            color: AppColors.darkText)),
                const SizedBox(height: 8),
                Text(
                    'Upload a CSV or Excel file to populate the alumni registry.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.mutedText)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor:
                  const WidgetStatePropertyAll(
                      AppColors.softWhite),
              headingTextStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                  letterSpacing: 0.5),
              dataTextStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.darkText),
              columns: const [
                DataColumn(
                    label: Text('FILE NAME')),
                DataColumn(
                    label: Text('RECORDS')),
                DataColumn(
                    label: Text('MATCHED')),
                DataColumn(label: Text('STATUS')),
                DataColumn(
                    label: Text('UPLOADED BY')),
                DataColumn(
                    label: Text('UPLOADED AT')),
                DataColumn(
                    label: Text('ACTIONS')),
              ],
              rows: uploads.map((upload) {
                final matchPct =
                    upload.totalRecords > 0
                        ? ((upload.matchedCount /
                                    upload.totalRecords) *
                                100)
                            .toStringAsFixed(0)
                        : '0';
                return DataRow(cells: [
                  DataCell(Row(children: [
                    Icon(
                      upload.fileName.endsWith('.csv')
                          ? Icons.table_chart_outlined
                          : Icons.grid_on,
                      size: 16,
                      color: AppColors.brandRed,
                    ),
                    const SizedBox(width: 8),
                    Text(upload.fileName,
                        style: GoogleFonts.inter(
                            fontWeight:
                                FontWeight.w600,
                            fontSize: 13)),
                  ])),
                  DataCell(Text(
                      '${upload.totalRecords}',
                      style: GoogleFonts.inter(
                          fontWeight:
                              FontWeight.w600))),
                  DataCell(Row(children: [
                    Text('${upload.matchedCount}',
                        style: GoogleFonts.inter(
                            color: Colors.green,
                            fontWeight:
                                FontWeight.w600)),
                    Text(' ($matchPct%)',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color:
                                AppColors.mutedText)),
                  ])),
                  DataCell(_uploadStatusBadge(
                      upload.status)),
                  DataCell(
                      Text(upload.uploadedByName)),
                  DataCell(Text(
                    upload.uploadedAt != null
                        ? DateFormat('MMM dd, yyyy')
                            .format(upload.uploadedAt!)
                        : '—',
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'View Records',
                        child: GestureDetector(
                          onTap: () => setState(() =>
                              _selectedUploadId =
                                  upload.id),
                          child: Container(
                            padding:
                                const EdgeInsets.all(
                                    6),
                            decoration: BoxDecoration(
                              color: AppColors.brandRed
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(
                                      6),
                            ),
                            child: const Icon(
                                Icons
                                    .list_alt_outlined,
                                color:
                                    AppColors.brandRed,
                                size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Delete Batch',
                        child: GestureDetector(
                          onTap: () =>
                              _confirmDeleteUpload(
                                  upload),
                          child: Container(
                            padding:
                                const EdgeInsets.all(
                                    6),
                            decoration: BoxDecoration(
                              color: Colors.red
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(
                                      6),
                            ),
                            child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 16),
                          ),
                        ),
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchRecordsView(String uploadId) {
    return StreamBuilder<List<AlumniRecord>>(
      stream:
          _registryService.recordsStream(uploadId),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed));
        }

        final allRecs = snap.data ?? [];
        final records = allRecs.where((r) {
          if (_registrySearch.isEmpty) return true;
          final q = _registrySearch.toLowerCase();
          return r.fullName
                  .toLowerCase()
                  .contains(q) ||
              r.batch.contains(q) ||
              r.course.toLowerCase().contains(q) ||
              r.email.toLowerCase().contains(q) ||
              r.studentId.contains(q);
        }).toList();

        return Column(
          children: [
            Container(
              color: AppColors.softWhite,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              child: Row(children: [
                TextButton.icon(
                  onPressed: () => setState(() =>
                      _selectedUploadId = null),
                  icon: const Icon(Icons.arrow_back,
                      size: 16,
                      color: AppColors.brandRed),
                  label: Text('Back to Uploads',
                      style: GoogleFonts.inter(
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(width: 16),
                Text(
                    '${records.length} of ${allRecs.length} records',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText)),
                const Spacer(),
                _filterChip('All', allRecs.length,
                    AppColors.mutedText),
                const SizedBox(width: 6),
                _filterChip(
                    'Matched',
                    allRecs
                        .where((r) => r.isMatched)
                        .length,
                    Colors.green),
                const SizedBox(width: 6),
                _filterChip(
                    'Unmatched',
                    allRecs
                        .where((r) => !r.isMatched)
                        .length,
                    Colors.orange),
              ]),
            ),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Text(
                          'No records found.',
                          style: GoogleFonts.inter(
                              color:
                                  AppColors.mutedText)))
                  : SingleChildScrollView(
                      padding:
                          const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        scrollDirection:
                            Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor:
                              const WidgetStatePropertyAll(
                                  AppColors.softWhite),
                          headingTextStyle:
                              GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      AppColors.mutedText,
                                  letterSpacing: 0.5),
                          dataTextStyle:
                              GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.darkText),
                          columns: const [
                            DataColumn(
                                label:
                                    Text('FULL NAME')),
                            DataColumn(
                                label: Text('BATCH')),
                            DataColumn(
                                label: Text('COURSE')),
                            DataColumn(
                                label: Text('EMAIL')),
                            DataColumn(
                                label:
                                    Text('STUDENT ID')),
                            DataColumn(
                                label: Text('STATUS')),
                          ],
                          rows: records.map((r) {
                            return DataRow(cells: [
                              DataCell(Text(
                                  r.fullName,
                                  style: GoogleFonts
                                      .inter(
                                          fontWeight:
                                              FontWeight
                                                  .w600))),
                              DataCell(Text(
                                  r.batch.isEmpty
                                      ? '—'
                                      : r.batch)),
                              DataCell(Text(
                                  r.course.isEmpty
                                      ? '—'
                                      : r.course,
                                  overflow:
                                      TextOverflow
                                          .ellipsis)),
                              DataCell(Text(
                                  r.email.isEmpty
                                      ? '—'
                                      : r.email)),
                              DataCell(Text(
                                  r.studentId.isEmpty
                                      ? '—'
                                      : r.studentId)),
                              DataCell(r.isMatched
                                  ? _badge('MATCHED',
                                      Colors.green)
                                  : _badge(
                                      'UNMATCHED',
                                      Colors.orange)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAllRecordsView() {
    return StreamBuilder<List<AlumniRecord>>(
      stream: _registryService.allRecordsStream(
          search: _registrySearch.isEmpty
              ? null
              : _registrySearch),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(
                      color: Colors.red)));
        }

        final records = snap.data ?? [];
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline,
                    size: 72,
                    color: AppColors.borderSubtle),
                const SizedBox(height: 16),
                Text('No records found',
                    style:
                        GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            color: AppColors.darkText)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor:
                  const WidgetStatePropertyAll(
                      AppColors.softWhite),
              headingTextStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                  letterSpacing: 0.5),
              dataTextStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.darkText),
              columns: const [
                DataColumn(
                    label: Text('FULL NAME')),
                DataColumn(label: Text('BATCH')),
                DataColumn(label: Text('COURSE')),
                DataColumn(label: Text('EMAIL')),
                DataColumn(
                    label: Text('STUDENT ID')),
                DataColumn(
                    label: Text('UPLOAD BATCH')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: records.map((r) {
                return DataRow(cells: [
                  DataCell(Text(r.fullName,
                      style: GoogleFonts.inter(
                          fontWeight:
                              FontWeight.w600))),
                  DataCell(Text(r.batch.isEmpty
                      ? '—'
                      : r.batch)),
                  DataCell(Text(
                      r.course.isEmpty
                          ? '—'
                          : r.course,
                      overflow:
                          TextOverflow.ellipsis)),
                  DataCell(Text(
                      r.email.isEmpty
                          ? '—'
                          : r.email)),
                  DataCell(Text(
                      r.studentId.isEmpty
                          ? '—'
                          : r.studentId)),
                  DataCell(Text(
                    r.uploadBatchId.length > 8
                        ? '...${r.uploadBatchId.substring(r.uploadBatchId.length - 8)}'
                        : r.uploadBatchId,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedText),
                  )),
                  DataCell(r.isMatched
                      ? _badge(
                          'MATCHED', Colors.green)
                      : _badge(
                          'UNMATCHED',
                          Colors.orange)),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _regSubTab(String label, int index) {
    final active = _registryTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _registryTab = index;
        _selectedUploadId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandRed
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
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

  Widget _uploadStatusBadge(String status) {
    final color = switch (status) {
      'done' => Colors.green,
      'processing' => Colors.orange,
      _ => AppColors.mutedText,
    };
    return _badge(status.toUpperCase(), color);
  }

  Widget _filterChip(
      String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withOpacity(0.2)),
      ),
      child: Text('$label ($count)',
          style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════
  //  SHARED SMALL WIDGETS
  // ══════════════════════════════════════════

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
          border: Border.all(
              color: AppColors.borderSubtle),
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
      padding:
          const EdgeInsets.symmetric(vertical: 8),
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
      case 'denied':
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

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
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
                          style: GoogleFonts
                              .cormorantGaramond(
                                  fontSize: 22,
                                  letterSpacing: 6,
                                  color:
                                      AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w300)),
                      const SizedBox(height: 6),
                      Text('ARCHIVE PORTAL',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: AppColors.mutedText,
                              fontWeight:
                                  FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sidebarSection('NETWORK', [
                          _sidebarItem('Overview',
                              route:
                                  '/admin_dashboard'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ENGAGEMENT', [
                          _sidebarItem(
                              'Career Milestones',
                              route:
                                  '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ADMIN FEATURES', [
                          _sidebarItem(
                              'User Verification & Moderation',
                              route:
                                  '/user_verification_moderation',
                              isActive: true),
                          _sidebarItem(
                              'Event Planning',
                              route: '/event_planning'),
                          _sidebarItem(
                              'Job Board Management',
                              route:
                                  '/job_board_management'),
                          _sidebarItem(
                              'Growth Metrics',
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
                            color: AppColors
                                .borderSubtle
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
                          style: GoogleFonts
                              .cormorantGaramond(
                                  color:
                                      AppColors.brandRed,
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
                                color:
                                    AppColors.mutedText,
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
                          Text(
                              _currentTab == 4
                                  ? 'Alumni Registry'
                                  : 'Trust & Safety Dashboard',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      fontSize: 32,
                                      fontWeight:
                                          FontWeight.w400,
                                      color:
                                          AppColors.darkText)),
                          Text(
                              _currentTab == 4
                                  ? 'Upload and manage the official alumni registry.'
                                  : _currentTab == 3
                                      ? 'Review applicants side-by-side with registry records.'
                                      : _currentTab == 1
                                          ? 'Accounts that have been rejected or denied access.'
                                          : 'Verify identities and moderate community interactions.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                      if (_currentTab != 4)
                        ElevatedButton.icon(
                          onPressed: _loadUsers,
                          icon: const Icon(
                              Icons.refresh,
                              size: 16),
                          label: Text('Refresh',
                              style: GoogleFonts.inter(
                                  fontWeight:
                                      FontWeight.w600)),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.brandRed,
                            foregroundColor:
                                Colors.white,
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12),
                            shape:
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(8)),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── Stats chips ───
                if (_currentTab != 4)
                  Container(
                    color: AppColors.cardWhite,
                    padding: const EdgeInsets.fromLTRB(
                        40, 10, 40, 10),
                    child: Row(children: [
                      _statChip(
                          'Total',
                          allUsers.length.toString(),
                          AppColors.mutedText),
                      const SizedBox(width: 10),
                      _statChip(
                          'Queue',
                          verificationQueue.length
                              .toString(),
                          Colors.orange),
                      const SizedBox(width: 10),
                      _statChip(
                          'Rejected',
                          rejectedUsers.length
                              .toString(),
                          AppColors.brandRed),
                    ]),
                  ),

                // ─── Tabs ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      40, 8, 40, 12),
                  child: Column(children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _tabBtn('All Users', 0),
                        const SizedBox(width: 8),
                        // ─── Tab 1 is now Rejected ───
                        _tabBtn('Rejected', 1),
                        const SizedBox(width: 8),
                        _tabBtn('Recent Logins', 2),
                        const SizedBox(width: 8),
                        _tabBtn(
                            'Verification Queue', 3),
                        const SizedBox(width: 8),
                        _tabBtn('Registry', 4),
                      ]),
                    ),
                    if (_currentTab != 4 &&
                        _currentTab != 3) ...[
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
                                color:
                                    AppColors.mutedText,
                                fontSize: 13),
                            prefixIcon: const Icon(
                                Icons.search,
                                color:
                                    AppColors.brandRed,
                                size: 18),
                            filled: true,
                            fillColor:
                                AppColors.softWhite,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      12),
                              borderSide:
                                  BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                                        vertical: 12,
                                        horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),

                Expanded(
                  child: _currentTab == 4
                      ? _buildRegistryTab()
                      : _currentTab == 3
                          ? _buildVerificationQueueView()
                          : isLoading
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(
                                          color: AppColors
                                              .brandRed))
                              : errorMessage != null
                                  ? Center(
                                      child: Text(
                                          errorMessage!,
                                          style:
                                              const TextStyle(
                                                  color:
                                                      Colors.red)))
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline,
                size: 72,
                color: AppColors.borderSubtle),
            const SizedBox(height: 16),
            Text(
              _currentTab == 1
                  ? 'No rejected accounts'
                  : 'No users found',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  color: AppColors.darkText),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: const WidgetStatePropertyAll(
              AppColors.softWhite),
          headingTextStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
              letterSpacing: 0.5),
          dataTextStyle: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.darkText),
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
            final status =
                user['status'].toString();
            final verStatus =
                user['verificationStatus'].toString();
            

            return DataRow(cells: [
              DataCell(Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandRed
                      .withOpacity(0.1),
                  backgroundImage:
                      user['profilePictureUrl'] != null
                          ? NetworkImage(
                              user['profilePictureUrl']
                                  .toString())
                          : null,
                  child:
                      user['profilePictureUrl'] == null
                          ? Text(
                              user['name']
                                      .toString()
                                      .isNotEmpty
                                  ? user['name']
                                      .toString()[0]
                                      .toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                  color:
                                      AppColors.brandRed,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700))
                          : null,
                ),
                const SizedBox(width: 10),
                Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(user['name'].toString(),
                          style: GoogleFonts.inter(
                              fontWeight:
                                  FontWeight.w600,
                              fontSize: 13)),
                      Text(user['email'].toString(),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color:
                                  AppColors.mutedText)),
                    ]),
              ])),
              DataCell(_badge(
                  user['role']
                      .toString()
                      .toUpperCase(),
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
                        padding:
                            const EdgeInsets.all(6),
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
        border: Border.all(
            color: color.withOpacity(0.2)),
      ),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      onTap: () =>
          setState(() => _currentTab = index),
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
            ? () =>
                Navigator.pushNamed(context, route)
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