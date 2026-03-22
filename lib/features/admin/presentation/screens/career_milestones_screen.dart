import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class CareerMilestonesScreen extends StatefulWidget {
  const CareerMilestonesScreen({super.key});

  @override
  State<CareerMilestonesScreen> createState() =>
      _CareerMilestonesScreenState();
}

class _CareerMilestonesScreenState
    extends State<CareerMilestonesScreen> {
  String? _statusFilter = 'pending';
  String _searchQuery = '';
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
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

  Stream<QuerySnapshot> get _stream {
    Query query = FirebaseFirestore.instance
        .collection('career_milestones')
        .orderBy('submittedAt', descending: true);
    if (_statusFilter != null) {
      query = query.where('status',
          isEqualTo: _statusFilter);
    }
    return query.snapshots();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return AppColors.mutedText;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'promotion':
        return Icons.trending_up;
      case 'new_job':
        return Icons.work_outline;
      case 'award':
        return Icons.emoji_events_outlined;
      case 'certification':
        return Icons.school_outlined;
      case 'retirement':
        return Icons.celebration_outlined;
      default:
        return Icons.workspace_premium_outlined;
    }
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

  Future<void> _updateStatus(
      String id, String status) async {
    final action =
        status == 'approved' ? 'Approve' : 'Reject';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('$action Milestone',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to $action this career milestone?',
            style: GoogleFonts.inter()),
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
            child: Text(action,
                style: GoogleFonts.inter(
                    color: status == 'approved'
                        ? Colors.green
                        : AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final update = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == 'approved') {
        update['approvedBy'] =
            FirebaseAuth.instance.currentUser?.uid;
        update['approvedAt'] =
            FieldValue.serverTimestamp();
      } else {
        update['rejectedBy'] =
            FirebaseAuth.instance.currentUser?.uid;
        update['rejectedAt'] =
            FieldValue.serverTimestamp();
      }
      await FirebaseFirestore.instance
          .collection('career_milestones')
          .doc(id)
          .update(update);
      _showSnackBar(
          'Milestone ${status == 'approved' ? 'approved' : 'rejected'}',
          isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(
      String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Milestone',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text(
            'Delete "$title"? This cannot be undone.',
            style: GoogleFonts.inter()),
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
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('career_milestones')
          .doc(id)
          .delete();
      _showSnackBar('Milestone deleted', isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showEditForm(
      String id, Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(
        text: data['title']?.toString() ?? '');
    final companyCtrl = TextEditingController(
        text: data['company']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text: data['description']?.toString() ?? '');
    String type =
        data['type']?.toString() ?? 'promotion';
    DateTime? date =
        (data['date'] as Timestamp?)?.toDate();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) =>
            DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
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
                      horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text('Edit Milestone',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final t =
                                    titleCtrl.text.trim();
                                if (t.isEmpty) {
                                  _showSnackBar(
                                      'Title is required',
                                      isError: true);
                                  return;
                                }
                                if (date == null) {
                                  _showSnackBar(
                                      'Date is required',
                                      isError: true);
                                  return;
                                }
                                setSheet(() =>
                                    isSubmitting = true);
                                try {
                                  await FirebaseFirestore
                                      .instance
                                      .collection(
                                          'career_milestones')
                                      .doc(id)
                                      .update({
                                    'title': t,
                                    'company': companyCtrl
                                        .text
                                        .trim(),
                                    'description':
                                        descCtrl.text
                                            .trim(),
                                    'type': type,
                                    'date':
                                        Timestamp.fromDate(
                                            date!),
                                    'updatedAt': FieldValue
                                        .serverTimestamp(),
                                  });
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _showSnackBar(
                                        'Milestone updated!',
                                        isError: false);
                                  }
                                } catch (e) {
                                  setSheet(() =>
                                      isSubmitting = false);
                                  _showSnackBar(
                                      'Error: $e',
                                      isError: true);
                                }
                              },
                        child: Text(
                          isSubmitting
                              ? 'Saving...'
                              : 'Save',
                          style: GoogleFonts.inter(
                              color: AppColors.brandRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _field(titleCtrl, 'Title',
                          'e.g. Promoted to Senior Manager'),
                      const SizedBox(height: 16),
                      _field(companyCtrl, 'Company',
                          'e.g. Accenture Philippines'),
                      const SizedBox(height: 16),
                      _field(descCtrl, 'Description',
                          'Describe this achievement...',
                          maxLines: 4),
                      const SizedBox(height: 16),

                      // ─── Type dropdown ───
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppColors.borderSubtle),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child:
                            DropdownButtonFormField<String>(
                          value: type,
                          decoration: InputDecoration(
                            labelText: 'Milestone Type',
                            labelStyle: GoogleFonts.inter(
                                color: AppColors.brandRed,
                                fontWeight:
                                    FontWeight.w500),
                            border: InputBorder.none,
                          ),
                          items: [
                            'promotion',
                            'new_job',
                            'award',
                            'certification',
                            'retirement',
                            'other',
                          ]
                              .map((v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                        v.replaceAll(
                                            '_', ' '),
                                        style:
                                            GoogleFonts.inter(
                                                fontSize:
                                                    14)),
                                  ))
                              .toList(),
                          onChanged: (v) => setSheet(
                              () => type = v!),
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.darkText),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ─── Date picker ───
                      GestureDetector(
                        onTap: () async {
                          final picked =
                              await showDatePicker(
                            context: context,
                            initialDate:
                                date ?? DateTime.now(),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now().add(
                                const Duration(days: 730)),
                            builder: (context, child) =>
                                Theme(
                              data: ThemeData.light()
                                  .copyWith(
                                colorScheme:
                                    const ColorScheme
                                        .light(
                                        primary: AppColors
                                            .brandRed),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setSheet(() => date = picked);
                          }
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.softWhite,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: date != null
                                  ? AppColors.brandRed
                                      .withOpacity(0.4)
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.brandRed
                                    .withOpacity(0.08),
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                              ),
                              child: const Icon(
                                  Icons
                                      .calendar_today_outlined,
                                  color: AppColors.brandRed,
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text('Milestone Date *',
                                      style: GoogleFonts
                                          .inter(
                                              fontSize: 11,
                                              color: AppColors
                                                  .mutedText,
                                              fontWeight:
                                                  FontWeight
                                                      .w500)),
                                  Text(
                                    date != null
                                        ? DateFormat(
                                                'EEE, MMM dd yyyy')
                                            .format(date!)
                                        : 'Tap to set',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: date != null
                                          ? AppColors
                                              .darkText
                                          : AppColors
                                              .mutedText,
                                      fontWeight: date !=
                                              null
                                          ? FontWeight.w500
                                          : FontWeight
                                              .normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              date != null
                                  ? Icons.edit_outlined
                                  : Icons.add_circle_outline,
                              color: AppColors.brandRed,
                              size: 18,
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                              fontWeight:
                                  FontWeight.bold)),
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
                              route: '/career_milestones',
                              isActive: true),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ADMIN FEATURES', [
                          _sidebarItem(
                              'User Verification & Moderation',
                              route:
                                  '/user_verification_moderation'),
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
                        backgroundColor: AppColors
                            .brandRed
                            .withOpacity(0.1),
                        child: Text(
                          _adminName[0].toUpperCase(),
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
                      horizontal: 32, vertical: 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Career Milestones',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      fontSize: 32,
                                      fontWeight:
                                          FontWeight.w400,
                                      color:
                                          AppColors.darkText)),
                          Text(
                              'Review and moderate alumni career achievements.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Search + filter chips ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      32, 12, 32, 12),
                  child: Column(children: [
                    TextField(
                      style: GoogleFonts.inter(
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Search by title, alumni name, company...',
                        hintStyle: GoogleFonts.inter(
                            color: AppColors.mutedText,
                            fontSize: 13),
                        prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.mutedText,
                            size: 20),
                        filled: true,
                        fillColor: AppColors.softWhite,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12),
                      ),
                      onChanged: (v) => setState(() =>
                          _searchQuery =
                              v.toLowerCase()),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      _filterChip('All', null),
                      const SizedBox(width: 8),
                      _filterChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _filterChip('Approved', 'approved'),
                      const SizedBox(width: 8),
                      _filterChip('Rejected', 'rejected'),
                    ]),
                  ]),
                ),

                // ─── List ───
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator(
                                    color:
                                        AppColors.brandRed));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                              'Error: ${snapshot.error}',
                              style: GoogleFonts.inter(
                                  color: Colors.red)),
                        );
                      }

                      var docs =
                          snapshot.data?.docs ?? [];

                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          final title = data['title']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          final name = (data['userName'] ??
                                  data[
                                      'submittedByName'] ??
                                  '')
                              .toString()
                              .toLowerCase();
                          final company = data['company']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          return title.contains(
                                  _searchQuery) ||
                              name.contains(
                                  _searchQuery) ||
                              company
                                  .contains(_searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons
                                      .work_history_outlined,
                                  size: 72,
                                  color: AppColors
                                      .borderSubtle),
                              const SizedBox(height: 16),
                              Text(
                                'No milestones found',
                                style: GoogleFonts
                                    .cormorantGaramond(
                                        fontSize: 22,
                                        color: AppColors
                                            .darkText),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _statusFilter != null
                                    ? 'No ${_statusFilter!} milestones'
                                    : 'Alumni can submit career updates from their profile',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        AppColors.mutedText),
                                textAlign:
                                    TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(32),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data()
                              as Map<String, dynamic>;
                          return _milestoneCard(
                              doc.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestoneCard(
      String id, Map<String, dynamic> data) {
    final status =
        data['status']?.toString() ?? 'pending';
    final title =
        data['title']?.toString() ?? 'Untitled';
    final company =
        data['company']?.toString() ?? '';
    final description =
        data['description']?.toString() ?? '';
    final type =
        data['type']?.toString() ?? 'other';
    final userName = (data['userName'] ??
            data['submittedByName'] ??
            'Unknown Alumni')
        .toString();
    final avatarUrl =
        data['userPhotoUrl']?.toString();
    final submittedAt =
        (data['submittedAt'] as Timestamp?)?.toDate();
    final milestoneDate =
        (data['date'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'pending'
              ? Colors.orange.withOpacity(0.3)
              : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ─── Type icon ───
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor(status)
                      .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(type),
                    color: _statusColor(status),
                    size: 24),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    if (company.isNotEmpty)
                      Text(company,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.brandRed,
                              fontWeight:
                                  FontWeight.w600)),
                  ],
                ),
              ),

              // ─── Status badge ───
              _badge(status.toUpperCase(),
                  _statusColor(status)),
            ],
          ),

          const SizedBox(height: 12),

          if (description.isNotEmpty)
            Text(description,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

          const SizedBox(height: 10),

          // ─── Info chips ───
          Wrap(spacing: 6, runSpacing: 6, children: [
            // ─── Submitted by ───
            Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    AppColors.brandRed.withOpacity(0.1),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 6),
              Text(userName,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w500)),
            ]),
            if (milestoneDate != null)
              _chip(Icons.calendar_today_outlined,
                  DateFormat('MMM dd, yyyy')
                      .format(milestoneDate)),
            _chip(Icons.category_outlined,
                type.replaceAll('_', ' ')),
            if (submittedAt != null)
              _chip(Icons.upload_outlined,
                  'Submitted ${DateFormat('MMM dd').format(submittedAt)}'),
          ]),

          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 4),

          // ─── Actions ───
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'pending') ...[
                _actionBtn(
                  icon: Icons.check_circle_outline,
                  label: 'Approve',
                  color: Colors.green,
                  onTap: () =>
                      _updateStatus(id, 'approved'),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.cancel_outlined,
                  label: 'Reject',
                  color: AppColors.brandRed,
                  onTap: () =>
                      _updateStatus(id, 'rejected'),
                ),
                const SizedBox(width: 8),
              ],
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: AppColors.mutedText,
                onTap: () => _showEditForm(id, data),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () =>
                    _confirmDelete(id, title),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5)),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedText)),
      ]),
    );
  }

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
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () =>
          setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandRed
              : AppColors.softWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? AppColors.brandRed
                  : AppColors.borderSubtle),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppColors.mutedText)),
      ),
    );
  }

  Widget _field(TextEditingController ctrl,
      String label, String hint,
      {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
            color: AppColors.brandRed,
            fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(
            color: AppColors.mutedText, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.brandRed, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.softWhite,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
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
      padding: const EdgeInsets.only(bottom: 16),
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

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}