// FILE: lib/features/admin/presentation/screens/job_board_management_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JobBoardManagementScreen
//
// DATA SOURCE: 'job_posting' collection (same collection JobOpportunitiesScreen
//             reads from — unified so alumni see exactly what staff posts).
//
// ROLES:
//   alumni  → can submit jobs (status = 'pending', requires staff approval)
//   staff   → can post directly (status = 'approved'), approve/reject pending,
//             edit any posting, delete any posting
//
// FIELDS added vs original:
//   contactEmail  — email alumni send CVs to
//   contactPhone  — phone number for enquiries
//   applyLink     — external URL (company careers page, Google Forms, etc.)
//   category      — e.g. "Healthcare", "Tech", "Finance"
//   requiredCourse— e.g. "BS Nursing" — used by JobScorer for course alignment
//
// VALIDATION:
//   - Title, Company, Location required for all
//   - Description required for all
//   - At least one contact method required (email OR phone OR link)
//   - Staff can post without contact (contact shown as "Contact company directly")
//   - End date must be after start date if both set
//   - Salary format is free-text (no numeric enforcement)
// ─────────────────────────────────────────────────────────────────────────────
class JobBoardManagementScreen extends StatefulWidget {
  const JobBoardManagementScreen({super.key});

  @override
  State<JobBoardManagementScreen> createState() =>
      _JobBoardManagementScreenState();
}

class _JobBoardManagementScreenState extends State<JobBoardManagementScreen> {
  String? _selectedStatus; // null = all
  String _searchQuery = '';
  String? _userRole;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role']?.toString() ?? 'alumni';
          _currentUid = user.uid;
        });
      }
    } catch (e) {
      debugPrint('Role load error: $e');
    }
  }

  bool get _isStaff =>
      _userRole == 'admin' ||
      _userRole == 'registrar' ||
      _userRole == 'staff' ||
      _userRole == 'moderator';

  bool get _isAlumni => _userRole == 'alumni';

  Stream<QuerySnapshot> get _jobStream {
    Query query = FirebaseFirestore.instance
        .collection('job_posting')
        .orderBy('postedAt', descending: true);
    if (_selectedStatus != null) {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  POST / EDIT JOB SHEET
  // ═══════════════════════════════════════════════════════════════════════════
  void _showPostJobSheet({
    String? docId,
    Map<String, dynamic>? existing,
  }) {
    final isEdit = docId != null;

    // Controllers
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final companyCtrl = TextEditingController(text: existing?['company'] ?? '');
    final locationCtrl =
        TextEditingController(text: existing?['location'] ?? '');
    final typeCtrl = TextEditingController(text: existing?['type'] ?? '');
    final categoryCtrl =
        TextEditingController(text: existing?['category'] ?? '');
    final salaryCtrl = TextEditingController(text: existing?['salary'] ?? '');
    final reqCourseCtrl =
        TextEditingController(text: existing?['requiredCourse'] ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] ?? '');
    final contactEmailCtrl =
        TextEditingController(text: existing?['contactEmail'] ?? '');
    final contactPhoneCtrl =
        TextEditingController(text: existing?['contactPhone'] ?? '');
    final applyLinkCtrl =
        TextEditingController(text: existing?['applyLink'] ?? '');

    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.93,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Job Posting' : 'Post a Job',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                          if (_isAlumni && !isEdit)
                            Text(
                              'Will be reviewed before going live',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.orange.shade700),
                            ),
                        ]),
                  ),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            // ── Contact validation ──
                            final hasContact =
                                contactEmailCtrl.text.trim().isNotEmpty ||
                                    contactPhoneCtrl.text.trim().isNotEmpty ||
                                    applyLinkCtrl.text.trim().isNotEmpty;

                            if (_isAlumni && !hasContact) {
                              _showSnackBar(
                                'Please provide at least one contact method '
                                '(email, phone, or apply link).',
                                isError: true,
                              );
                              return;
                            }

                            // ── Email format validation ──
                            final email = contactEmailCtrl.text.trim();
                            if (email.isNotEmpty &&
                                !RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                                    .hasMatch(email)) {
                              _showSnackBar(
                                  'Enter a valid contact email address.',
                                  isError: true);
                              return;
                            }

                            // ── URL validation ──
                            final link = applyLinkCtrl.text.trim();
                            if (link.isNotEmpty &&
                                !link.startsWith('http://') &&
                                !link.startsWith('https://')) {
                              _showSnackBar(
                                  'Apply link must start with http:// or https://',
                                  isError: true);
                              return;
                            }

                            setSheet(() => isSubmitting = true);

                            final Map<String, dynamic> data = {
                              'title': titleCtrl.text.trim(),
                              'company': companyCtrl.text.trim(),
                              'location': locationCtrl.text.trim(),
                              'type': typeCtrl.text.trim().isNotEmpty
                                  ? typeCtrl.text.trim()
                                  : 'Full-time',
                              'category': categoryCtrl.text.trim(),
                              'salary': salaryCtrl.text.trim(),
                              'requiredCourse': reqCourseCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'contactEmail': contactEmailCtrl.text.trim(),
                              'contactPhone': contactPhoneCtrl.text.trim(),
                              'applyLink': applyLinkCtrl.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            try {
                              if (isEdit) {
                                await FirebaseFirestore.instance
                                    .collection('job_posting')
                                    .doc(docId)
                                    .update(data);
                              } else {
                                data['postedAt'] = FieldValue.serverTimestamp();
                                data['postedBy'] = _currentUid;
                                data['postedByRole'] = _userRole;
                                // Alumni posts start pending, staff posts go live immediately
                                data['status'] =
                                    _isAlumni ? 'pending' : 'approved';

                                await FirebaseFirestore.instance
                                    .collection('job_posting')
                                    .add(data);
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showSnackBar(
                                  isEdit
                                      ? 'Job posting updated!'
                                      : _isAlumni
                                          ? 'Job submitted for review! It will go live once approved.'
                                          : 'Job posted and live!',
                                  isError: false,
                                );
                              }
                            } catch (e) {
                              setSheet(() => isSubmitting = false);
                              if (ctx.mounted) {
                                _showSnackBar('Error: $e', isError: true);
                              }
                            }
                          },
                    child: Text(
                      isSubmitting
                          ? 'Saving...'
                          : isEdit
                              ? 'Save'
                              : _isAlumni
                                  ? 'Submit'
                                  : 'Post',
                      style: GoogleFonts.inter(
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                ]),
              ),

              // Alumni info banner
              if (_isAlumni && !isEdit)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your posting will be reviewed by an admin before going live.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ),
                  ]),
                ),

              const Divider(height: 1),

              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ── Section: Basic Info ──────────────────────────
                      _sectionLabel('JOB DETAILS'),
                      const SizedBox(height: 12),

                      _formField(
                        controller: titleCtrl,
                        label: 'Job Title *',
                        hint: 'e.g. Senior Registered Nurse',
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Job title is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: companyCtrl,
                        label: 'Company / Organization *',
                        hint: 'e.g. Chong Hua Hospital',
                        prefixIcon: Icons.business_outlined,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Company name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: locationCtrl,
                        label: 'Location *',
                        hint: 'e.g. Cebu City / Remote / Hybrid',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Location is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                          child: _formField(
                            controller: typeCtrl,
                            label: 'Job Type',
                            hint: 'Full-time',
                            prefixIcon: Icons.work_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _formField(
                            controller: categoryCtrl,
                            label: 'Category',
                            hint: 'e.g. Healthcare',
                            prefixIcon: Icons.category_outlined,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      _formField(
                        controller: salaryCtrl,
                        label: 'Salary Range (optional)',
                        hint: 'e.g. ₱30,000 – ₱50,000 / mo',
                        prefixIcon: Icons.payments_outlined,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: reqCourseCtrl,
                        label: 'Required Course (optional)',
                        hint: 'e.g. BS Nursing — improves job matching',
                        prefixIcon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: descCtrl,
                        label: 'Job Description *',
                        hint:
                            'Describe responsibilities, qualifications, requirements...',
                        maxLines: 6,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Job description is required'
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // ── Section: Contact / Apply Info ────────────────
                      _sectionLabel('HOW TO APPLY'),
                      const SizedBox(height: 4),
                      Text(
                        _isAlumni
                            ? 'At least one contact method is required.'
                            : 'Provide at least one way for applicants to reach you.',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedText,
                            height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      _formField(
                        controller: applyLinkCtrl,
                        label: 'Apply Link (URL)',
                        hint: 'https://company.com/careers or Google Form link',
                        prefixIcon: Icons.open_in_new_rounded,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: contactEmailCtrl,
                        label: 'Contact Email',
                        hint: 'hr@company.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: contactPhoneCtrl,
                        label: 'Contact Phone (optional)',
                        hint: '+63 912 345 6789',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─── Staff actions ────────────────────────────────────────────────────────
  Future<void> _updateStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('job_posting')
          .doc(id)
          .update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': _currentUid,
      });
      _showSnackBar(
        status == 'approved' ? 'Job approved and now live!' : 'Job rejected.',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteJob(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.delete_outline,
                color: Colors.red.shade700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Delete Job Posting',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.darkText)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '"$title"',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This job posting will be permanently deleted and removed from the alumni job board.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.mutedText, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Delete',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('job_posting')
          .doc(id)
          .delete();
      _showSnackBar('Job posting deleted.', isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: Duration(seconds: isError ? 4 : 2),
      ));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          _buildSidebar(),

          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Column(children: [
              _buildTopBar(),
              _buildSearchAndFilters(),
              Expanded(child: _buildJobList()),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── Sidebar ──────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            right: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALUMNI',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    letterSpacing: 6,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 6),
            Text('ARCHIVE PORTAL',
                style: GoogleFonts.inter(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sidebarSection('NETWORK', [
                _sidebarItem('Overview', route: '/admin_dashboard'),
              ]),
              const SizedBox(height: 32),
              _sidebarSection('ENGAGEMENT', [
                _sidebarItem('Career Milestones', route: '/career_milestones'),
              ]),
              const SizedBox(height: 32),
              _sidebarSection('ADMIN FEATURES', [
                _sidebarItem('User Verification & Moderation',
                    route: '/user_verification_moderation'),
                _sidebarItem('Event Planning', route: '/event_planning'),
                _sidebarItem('Job Board Management',
                    route: '/job_board_management', isActive: true),
                _sidebarItem('Growth Metrics', route: '/growth_metrics'),
                _sidebarItem('Announcement Management',
                    route: '/announcement_management'),
              ]),
            ]),
          ),
        ),
        _buildSidebarFooter(),
      ]),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.borderSubtle.withOpacity(0.3))),
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.brandRed,
            child: Text('A',
                style: GoogleFonts.cormorantGaramond(
                    color: Colors.white, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Registrar Admin',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            Text('NETWORK OVERSEER',
                style:
                    GoogleFonts.inter(fontSize: 9, color: AppColors.mutedText)),
          ]),
        ]),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: Text('DISCONNECT',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Job Board Management',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: AppColors.darkText)),
          Text(
            'Post and monitor career opportunities for the alumni network.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
          ),
        ]),
        Row(children: [
          // Filter popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: AppColors.mutedText),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) =>
                setState(() => _selectedStatus = val == 'all' ? null : val),
            itemBuilder: (_) => [
              _popupItem('all', 'All Jobs'),
              _popupItem('pending', 'Pending Review'),
              _popupItem('approved', 'Approved'),
              _popupItem('rejected', 'Rejected'),
            ],
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showPostJobSheet(),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              _isAlumni ? 'Submit Job' : 'Post Job',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── Search + filter chips ────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
      child: Column(children: [
        TextField(
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search jobs, companies...',
            hintStyle:
                GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.mutedText, size: 20),
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
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
    );
  }

  // ─── Job list stream ──────────────────────────────────────────────────────
  Widget _buildJobList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _jobStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: GoogleFonts.inter(color: Colors.red)),
          );
        }

        var docs = snapshot.data?.docs ?? [];

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            final company = data['company']?.toString().toLowerCase() ?? '';
            final loc = data['location']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery) ||
                company.contains(_searchQuery) ||
                loc.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.work_off_outlined,
                  size: 72, color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              Text('No job postings found',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text(
                _isAlumni
                    ? 'Tap + to submit a job opportunity for review'
                    : 'Tap + to post a new job',
                style:
                    GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showPostJobSheet(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  _isAlumni ? 'Submit Job' : 'Post Job',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _jobCard(doc.id, data);
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  JOB CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _jobCard(String id, Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'pending';
    final title = data['title']?.toString() ?? 'Untitled';
    final company = data['company']?.toString() ?? 'Company';
    final location = data['location']?.toString() ?? 'Remote';
    final type = data['type']?.toString() ?? 'Full-time';
    final salary = data['salary']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final desc = data['description']?.toString() ?? '';
    final postedBy = data['postedBy']?.toString() ?? '';
    final reqCourse = data['requiredCourse']?.toString() ?? '';
    final contactEmail = data['contactEmail']?.toString() ?? '';
    final contactPhone = data['contactPhone']?.toString() ?? '';
    final applyLink = data['applyLink']?.toString() ?? '';
    final postedAt = (data['postedAt'] as Timestamp?)?.toDate();
    final isOwner = postedBy == _currentUid;

    final hasContact = contactEmail.isNotEmpty ||
        contactPhone.isNotEmpty ||
        applyLink.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'pending'
              ? Colors.orange.withOpacity(0.4)
              : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top row ──────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.business_center_outlined,
                color: _statusColor(status), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
              const SizedBox(height: 2),
              Text(company,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          // Status badge + staff dropdown
          if (_isStaff)
            PopupMenuButton<String>(
              tooltip: 'Change status',
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(status.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status),
                          letterSpacing: 0.5)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down,
                      size: 14, color: _statusColor(status)),
                ]),
              ),
              onSelected: (v) => _updateStatus(id, v),
              itemBuilder: (_) => ['pending', 'approved', 'rejected']
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Row(children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _statusColor(s), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(s.toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 13)),
                        ]),
                      ))
                  .toList(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(status.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                      letterSpacing: 0.5)),
            ),
        ]),

        const SizedBox(height: 12),

        // ── Tags ─────────────────────────────────────────────────────────
        Wrap(spacing: 6, runSpacing: 6, children: [
          _tag(Icons.location_on_outlined, location),
          _tag(Icons.work_outline, type),
          if (category.isNotEmpty) _tag(Icons.category_outlined, category),
          if (salary.isNotEmpty)
            _tag(Icons.payments_outlined, salary, color: Colors.green.shade700),
          if (reqCourse.isNotEmpty)
            _tag(Icons.school_outlined, reqCourse, color: AppColors.brandRed),
        ]),

        const SizedBox(height: 10),

        // ── Description ───────────────────────────────────────────────────
        if (desc.isNotEmpty)
          Text(desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText, height: 1.5)),

        // ── Contact info preview ──────────────────────────────────────────
        if (hasContact) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (applyLink.isNotEmpty)
              _contactChip(Icons.open_in_new_rounded, 'Apply link',
                  Colors.blue.shade700),
            if (contactEmail.isNotEmpty)
              _contactChip(
                  Icons.email_outlined, contactEmail, Colors.blue.shade700),
            if (contactPhone.isNotEmpty)
              _contactChip(
                  Icons.phone_outlined, contactPhone, Colors.green.shade700),
          ]),
        ],

        const SizedBox(height: 10),

        // ── Footer ────────────────────────────────────────────────────────
        Row(children: [
          if (postedAt != null)
            Text(
              DateFormat('MMM dd, yyyy').format(postedAt),
              style:
                  GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText),
            ),
          const Spacer(),

          // Staff: approve / reject pending
          if (_isStaff && status == 'pending') ...[
            _actionBtn(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              tooltip: 'Approve',
              onTap: () => _updateStatus(id, 'approved'),
            ),
            _actionBtn(
              icon: Icons.cancel_outlined,
              color: Colors.red,
              tooltip: 'Reject',
              onTap: () => _updateStatus(id, 'rejected'),
            ),
          ],

          // Edit: staff or owner
          if (_isStaff || isOwner)
            _actionBtn(
              icon: Icons.edit_outlined,
              color: AppColors.mutedText,
              tooltip: 'Edit',
              onTap: () => _showPostJobSheet(docId: id, existing: data),
            ),

          // Delete: staff only
          if (_isStaff)
            _actionBtn(
              icon: Icons.delete_outline,
              color: Colors.red,
              tooltip: 'Delete',
              onTap: () => _deleteJob(id, title),
            ),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Row(children: [
      Container(width: 14, height: 1, color: AppColors.brandRed),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 9,
              letterSpacing: 2,
              color: AppColors.brandRed,
              fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _tag(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: c, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _contactChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandRed : AppColors.softWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brandRed : AppColors.borderSubtle,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.mutedText)),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(String value, String label) {
    final isSelected =
        _selectedStatus == value || (value == 'all' && _selectedStatus == null);
    return PopupMenuItem(
      value: value,
      child: Text(label,
          style: GoogleFonts.inter(
              color: isSelected ? AppColors.brandRed : AppColors.darkText,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
    );
  }

  Widget _sidebarSection(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedText.withOpacity(0.7))),
      const SizedBox(height: 16),
      ...items,
    ]);
  }

  Widget _sidebarItem(String label, {String? route, bool isActive = false}) {
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
                  color: isActive ? AppColors.brandRed : AppColors.darkText,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
            color: AppColors.brandRed, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.mutedText, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.softWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}
