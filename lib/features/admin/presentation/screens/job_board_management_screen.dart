// FILE: lib/features/admin/presentation/screens/job_board_management_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JobBoardManagementScreen
//
// DATA SOURCE  : job_posting collection
// ROLES        :
//   alumni → submit (status=pending, requires staff approval)
//   staff  → post directly (status=approved), moderate, edit, delete
//
// CONTACT METHODS (fully clickable):
//   applyLink    → launchUrl (external browser)
//   contactEmail → mailto: scheme  (pre-fills subject line)
//   contactPhone → tel: scheme
//
// VALIDATION:
//   alumni : title + company + location + description + ≥1 contact method
//   staff  : title + company + location + description (contact optional)
// ─────────────────────────────────────────────────────────────────────────────

class JobBoardManagementScreen extends StatefulWidget {
  const JobBoardManagementScreen({super.key});

  @override
  State<JobBoardManagementScreen> createState() =>
      _JobBoardManagementScreenState();
}

class _JobBoardManagementScreenState
    extends State<JobBoardManagementScreen> {
  String? _selectedStatus;
  String  _searchQuery = '';
  String? _userRole;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  // ── Role loader ─────────────────────────────────────────────────────────
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
          _userRole   = doc.data()?['role']?.toString() ?? 'alumni';
          _currentUid = user.uid;
        });
      }
    } catch (e) {
      debugPrint('Role load error: $e');
    }
  }

  bool get _isStaff =>
      _userRole == 'admin'     ||
      _userRole == 'registrar' ||
      _userRole == 'staff'     ||
      _userRole == 'moderator';

  bool get _isAlumni => _userRole == 'alumni';

  // ── Firestore stream ────────────────────────────────────────────────────
  Stream<QuerySnapshot> get _jobStream {
    Query query = FirebaseFirestore.instance
        .collection('job_posting')
        .orderBy('postedAt', descending: true);
    if (_selectedStatus != null) {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }

  // ── URL / email / phone launchers ────────────────────────────────────────
  Future<void> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open: $url', isError: true);
      }
    } catch (e) {
      _snack('Invalid link: $e', isError: true);
    }
  }

  void _launchEmail(String email, String jobTitle) {
    _launch(
      'mailto:$email?subject=${Uri.encodeComponent('Application — $jobTitle')}',
    );
  }

  void _launchPhone(String phone) => _launch('tel:$phone');
  void _launchUrl(String url)     => _launch(url);

  // ════════════════════════════════════════════════════════════════════════
  //  POST / EDIT SHEET
  // ════════════════════════════════════════════════════════════════════════
  void _showPostJobSheet({String? docId, Map<String, dynamic>? existing}) {
    final isEdit = docId != null;

    final titleCtrl        = TextEditingController(text: existing?['title']          ?? '');
    final companyCtrl      = TextEditingController(text: existing?['company']         ?? '');
    final locationCtrl     = TextEditingController(text: existing?['location']        ?? '');
    final typeCtrl         = TextEditingController(text: existing?['type']            ?? '');
    final categoryCtrl     = TextEditingController(text: existing?['category']        ?? '');
    final salaryCtrl       = TextEditingController(text: existing?['salary']          ?? '');
    final reqCourseCtrl    = TextEditingController(text: existing?['requiredCourse']  ?? '');
    final descCtrl         = TextEditingController(text: existing?['description']     ?? '');
    final contactEmailCtrl = TextEditingController(text: existing?['contactEmail']    ?? '');
    final contactPhoneCtrl = TextEditingController(text: existing?['contactPhone']    ?? '');
    final applyLinkCtrl    = TextEditingController(text: existing?['applyLink']       ?? '');

    final formKey      = GlobalKey<FormState>();
    bool  isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.93,
          maxChildSize:     0.97,
          minChildSize:     0.5,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.brandRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.work_outline,
                        color: AppColors.brandRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        isEdit ? 'Edit Job Posting' : 'Post a Job',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText),
                      ),
                      if (_isAlumni && !isEdit)
                        Text('Submitted for admin review',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.orange.shade700)),
                    ]),
                  ),
                  TextButton(
                    onPressed: isSubmitting ? null : () async {
                      if (!formKey.currentState!.validate()) return;

                      // Contact validation (alumni only)
                      final hasContact =
                          contactEmailCtrl.text.trim().isNotEmpty ||
                          contactPhoneCtrl.text.trim().isNotEmpty ||
                          applyLinkCtrl.text.trim().isNotEmpty;
                      if (_isAlumni && !hasContact) {
                        _snack('Add at least one contact method.', isError: true);
                        return;
                      }

                      // URL validation
                      final link = applyLinkCtrl.text.trim();
                      if (link.isNotEmpty &&
                          !link.startsWith('http://') &&
                          !link.startsWith('https://')) {
                        _snack('Apply link must start with https://', isError: true);
                        return;
                      }

                      // Email format validation
                      final email = contactEmailCtrl.text.trim();
                      if (email.isNotEmpty &&
                          !RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                              .hasMatch(email)) {
                        _snack('Enter a valid contact email.', isError: true);
                        return;
                      }

                      // Phone basic validation
                      final phone = contactPhoneCtrl.text.trim();
                      if (phone.isNotEmpty &&
                          phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').length < 7) {
                        _snack('Enter a valid phone number.', isError: true);
                        return;
                      }

                      setSheet(() => isSubmitting = true);

                      final data = <String, dynamic>{
                        'title':          titleCtrl.text.trim(),
                        'company':        companyCtrl.text.trim(),
                        'location':       locationCtrl.text.trim(),
                        'type':           typeCtrl.text.trim().isNotEmpty
                            ? typeCtrl.text.trim()
                            : 'Full-time',
                        'category':       categoryCtrl.text.trim(),
                        'salary':         salaryCtrl.text.trim(),
                        'requiredCourse': reqCourseCtrl.text.trim(),
                        'description':    descCtrl.text.trim(),
                        'contactEmail':   email,
                        'contactPhone':   phone,
                        'applyLink':      link,
                        'updatedAt':      FieldValue.serverTimestamp(),
                      };

                      try {
                        if (isEdit) {
                          await FirebaseFirestore.instance
                              .collection('job_posting')
                              .doc(docId)
                              .update(data);
                        } else {
                          data['postedAt']     = FieldValue.serverTimestamp();
                          data['postedBy']     = _currentUid;
                          data['postedByRole'] = _userRole;
                          data['status']       = _isAlumni ? 'pending' : 'approved';
                          await FirebaseFirestore.instance
                              .collection('job_posting')
                              .add(data);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack(
                            isEdit
                                ? 'Job posting updated!'
                                : _isAlumni
                                    ? 'Job submitted for review!'
                                    : 'Job posted and live!',
                            isError: false,
                          );
                        }
                      } catch (e) {
                        setSheet(() => isSubmitting = false);
                        if (ctx.mounted) _snack('Error: $e', isError: true);
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandRed,
                    ),
                    child: Text(
                      isSubmitting
                          ? 'Saving…'
                          : isEdit
                              ? 'Save'
                              : _isAlumni ? 'Submit' : 'Post Live',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ]),
              ),

              // Alumni review notice
              if (_isAlumni && !isEdit)
                _SheetBanner(
                  icon: Icons.info_outline,
                  message:
                      'Your posting will be reviewed by an admin before going live.',
                  color: Colors.orange,
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                ),

              // Staff no-contact note
              if (_isStaff)
                _SheetBanner(
                  icon: Icons.verified_user_outlined,
                  message:
                      'Contact methods are optional for staff posts. Leave blank if applicants should contact the company directly.',
                  color: Colors.blue,
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                ),

              const Divider(height: 1),

              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    children: [
                      _SheetSection(
                        icon: Icons.work_outline,
                        label: 'JOB DETAILS',
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: titleCtrl,
                        label: 'Job Title *',
                        hint: 'e.g. Senior Registered Nurse',
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Job title required' : null,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: companyCtrl,
                        label: 'Company / Organization *',
                        hint: 'e.g. Chong Hua Hospital',
                        prefixIcon: Icons.business_outlined,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Company name required' : null,
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: locationCtrl,
                        label: 'Location *',
                        hint: 'e.g. Cebu City / Remote / Hybrid',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Location required' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                          child: _formField(
                            controller: typeCtrl,
                            label: 'Job Type',
                            hint: 'Full-time',
                            prefixIcon: Icons.schedule_outlined,
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

                      Row(children: [
                        Expanded(
                          child: _formField(
                            controller: salaryCtrl,
                            label: 'Salary Range',
                            hint: '₱30,000 – ₱50,000/mo',
                            prefixIcon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _formField(
                            controller: reqCourseCtrl,
                            label: 'Required Course',
                            hint: 'e.g. BS Nursing',
                            prefixIcon: Icons.school_outlined,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      _formField(
                        controller: descCtrl,
                        label: 'Job Description *',
                        hint:
                            'Responsibilities, qualifications, requirements…',
                        maxLines: 6,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Description required' : null,
                      ),

                      const SizedBox(height: 28),

                      _SheetSection(
                        icon: Icons.send_outlined,
                        label: 'HOW TO APPLY',
                        subtitle: _isAlumni
                            ? 'At least one contact method is required.'
                            : 'Optional — leave blank to have applicants contact the company directly.',
                      ),
                      const SizedBox(height: 14),

                      _formField(
                        controller: applyLinkCtrl,
                        label: 'Apply Link (URL)',
                        hint: 'https://company.com/careers',
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
                        label: 'Contact Phone',
                        hint: '+63 912 345 6789',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 40),
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

  // ── Status update / delete ──────────────────────────────────────────────
  Future<void> _updateStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('job_posting')
          .doc(id)
          .update({
        'status':     status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': _currentUid,
      });
      _snack(
        status == 'approved' ? 'Job approved and live!' : 'Job rejected.',
        isError: false,
      );
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  Future<void> _deleteJob(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        contentPadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.delete_forever_outlined,
                  color: Colors.red.shade600, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Delete Job Posting',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(
              '"$title" will be permanently removed from the job board.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedText,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Delete',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('job_posting')
          .doc(id)
          .delete();
      _snack('Job posting deleted.', isError: false);
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  void _snack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.inter())),
        ]),
        backgroundColor: isError
            ? Colors.red.shade700
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: Duration(seconds: isError ? 4 : 2),
      ));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF059669);
      case 'rejected': return const Color(0xFFDC2626);
      default:         return const Color(0xFFD97706);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildSidebar(),
        Expanded(
          child: Column(children: [
            _buildTopBar(),
            _buildSearchAndFilters(),
            Expanded(child: _buildJobList()),
          ]),
        ),
      ]),
    );
  }

  // ── Sidebar ──────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 272,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEEF0F4))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('ALUMNI',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    letterSpacing: 6,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('ARCHIVE PORTAL',
                style: GoogleFonts.inter(
                    fontSize: 9, letterSpacing: 2,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _navSection('NETWORK', [
                _navItem(Icons.dashboard_outlined, 'Overview',
                    route: '/admin_dashboard'),
              ]),
              const SizedBox(height: 20),
              _navSection('ENGAGEMENT', [
                _navItem(Icons.emoji_events_outlined,
                    'Career Milestones',
                    route: '/career_milestones'),
              ]),
              const SizedBox(height: 20),
              _navSection('ADMIN FEATURES', [
                _navItem(Icons.verified_user_outlined,
                    'User Verification',
                    route: '/user_verification_moderation'),
                _navItem(Icons.event_outlined, 'Event Planning',
                    route: '/event_planning'),
                _navItem(Icons.work_outline, 'Job Board',
                    route: '/job_board_management', isActive: true),
                _navItem(Icons.bar_chart_outlined, 'Growth Metrics',
                    route: '/growth_metrics'),
                _navItem(Icons.campaign_outlined, 'Announcements',
                    route: '/announcement_management'),
              ]),
            ]),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brandRed.withOpacity(0.1),
              child: Text('A',
                  style: GoogleFonts.cormorantGaramond(
                      color: AppColors.brandRed, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Registrar Admin',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('NETWORK OVERSEER',
                    style: GoogleFonts.inter(
                        fontSize: 9, color: AppColors.mutedText)),
              ]),
            ),
            IconButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: const Icon(Icons.logout_rounded,
                  size: 16, color: AppColors.mutedText),
              tooltip: 'Sign out',
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _navSection(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 9, letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText.withOpacity(0.6))),
      ),
      ...items,
    ]);
  }

  Widget _navItem(IconData icon, String label,
      {String? route, bool isActive = false}) {
    return Material(
      color: isActive
          ? AppColors.brandRed.withOpacity(0.07)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: route != null && !isActive
            ? () => Navigator.pushNamed(context, route)
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(icon,
                size: 17,
                color: isActive ? AppColors.brandRed : AppColors.mutedText),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isActive ? AppColors.brandRed : AppColors.darkText,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Job Board',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText)),
          Text('Post and manage career opportunities for alumni.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText)),
        ]),
        Row(children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Filter by status',
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                child: Row(children: [
                  const Icon(Icons.filter_list,
                      size: 16, color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  Text(
                    _selectedStatus == null
                        ? 'All Status'
                        : _selectedStatus![0].toUpperCase() +
                            _selectedStatus!.substring(1),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: AppColors.mutedText),
                ]),
              ),
              onSelected: (val) => setState(
                  () => _selectedStatus = val == 'all' ? null : val),
              itemBuilder: (_) => [
                _popupItem('all',      'All Jobs'),
                _popupItem('pending',  'Pending Review'),
                _popupItem('approved', 'Approved'),
                _popupItem('rejected', 'Rejected'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showPostJobSheet(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              _isAlumni ? 'Submit Job' : 'Post Job',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Search + filter chips ────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(children: [
        const Divider(height: 1),
        const SizedBox(height: 14),
        TextField(
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by title, company, location…',
            hintStyle:
                GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.mutedText, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEF0F4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEF0F4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.brandRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
          onChanged: (v) =>
              setState(() => _searchQuery = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _filterChip('All', null),
          const SizedBox(width: 8),
          _filterChip('Pending',  'pending',
              dotColor: const Color(0xFFD97706)),
          const SizedBox(width: 8),
          _filterChip('Approved', 'approved',
              dotColor: const Color(0xFF059669)),
          const SizedBox(width: 8),
          _filterChip('Rejected', 'rejected',
              dotColor: const Color(0xFFDC2626)),
        ]),
      ]),
    );
  }

  // ── Job list ────────────────────────────────────────────────────────────
  Widget _buildJobList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _jobStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2.5));
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
            final d = doc.data() as Map<String, dynamic>;
            return (d['title']    ?? '').toString().toLowerCase().contains(_searchQuery) ||
                   (d['company']  ?? '').toString().toLowerCase().contains(_searchQuery) ||
                   (d['location'] ?? '').toString().toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) return _buildEmptyState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _JobCard(
              id:            doc.id,
              data:          data,
              currentUid:    _currentUid,
              isStaff:       _isStaff,
              onApprove:     () => _updateStatus(doc.id, 'approved'),
              onReject:      () => _updateStatus(doc.id, 'rejected'),
              onEdit:        () =>
                  _showPostJobSheet(docId: doc.id, existing: data),
              onDelete:      () => _deleteJob(
                  doc.id, data['title']?.toString() ?? 'this job'),
              onLaunchUrl:   _launchUrl,
              onLaunchEmail: _launchEmail,
              onLaunchPhone: _launchPhone,
              statusColor:   _statusColor,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.work_off_outlined,
              size: 40, color: AppColors.brandRed),
        ),
        const SizedBox(height: 20),
        Text('No job postings found',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24, color: AppColors.darkText)),
        const SizedBox(height: 8),
        Text(
          _isAlumni
              ? 'Submit a job opportunity for the alumni network.'
              : 'Post a new job to get started.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.mutedText),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showPostJobSheet(),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(_isAlumni ? 'Submit Job' : 'Post Job',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }

  // ── Reusable form/filter widgets ──────────────────────────────────────────

  Widget _filterChip(String label, String? value, {Color? dotColor}) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandRed.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brandRed : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dotColor != null && isSelected) ...[
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                  color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.brandRed
                      : AppColors.mutedText)),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(String value, String label) {
    final isSel = _selectedStatus == value ||
        (value == 'all' && _selectedStatus == null);
    return PopupMenuItem(
      value: value,
      child: Text(label,
          style: GoogleFonts.inter(
              color: isSel ? AppColors.brandRed : AppColors.darkText,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.normal)),
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
      controller:   controller,
      maxLines:     maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        labelStyle: GoogleFonts.inter(
            color: AppColors.brandRed,
            fontWeight: FontWeight.w500,
            fontSize: 12),
        hintStyle:  GoogleFonts.inter(
            color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.mutedText, size: 18)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: AppColors.brandRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        filled:         true,
        fillColor:      const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  JOB CARD  — extracted widget, fully clickable contact methods
// ═══════════════════════════════════════════════════════════════════════════

class _JobCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final String? currentUid;
  final bool isStaff;
  final VoidCallback onApprove, onReject, onEdit, onDelete;
  final void Function(String) onLaunchUrl;
  final void Function(String email, String title) onLaunchEmail;
  final void Function(String) onLaunchPhone;
  final Color Function(String) statusColor;

  const _JobCard({
    required this.id,
    required this.data,
    required this.currentUid,
    required this.isStaff,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onLaunchUrl,
    required this.onLaunchEmail,
    required this.onLaunchPhone,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final status       = data['status']?.toString()         ?? 'pending';
    final title        = data['title']?.toString()          ?? 'Untitled';
    final company      = data['company']?.toString()        ?? 'Company';
    final location     = data['location']?.toString()       ?? '';
    final type         = data['type']?.toString()           ?? 'Full-time';
    final salary       = data['salary']?.toString()         ?? '';
    final category     = data['category']?.toString()       ?? '';
    final desc         = data['description']?.toString()    ?? '';
    final postedBy     = data['postedBy']?.toString()       ?? '';
    final reqCourse    = data['requiredCourse']?.toString() ?? '';
    final contactEmail = data['contactEmail']?.toString()   ?? '';
    final contactPhone = data['contactPhone']?.toString()   ?? '';
    final applyLink    = data['applyLink']?.toString()      ?? '';
    final postedAt     = (data['postedAt'] as Timestamp?)?.toDate();
    final isOwner      = postedBy == currentUid;
    final sColor       = statusColor(status);
    final isApproved   = status == 'approved';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApproved
              ? const Color(0xFF059669).withOpacity(0.22)
              : status == 'pending'
                  ? const Color(0xFFD97706).withOpacity(0.28)
                  : const Color(0xFFEEF0F4),
          width: isApproved ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isApproved ? 0.06 : 0.03),
            blurRadius: isApproved ? 14 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Approved highlight header ───────────────────────────────────
        if (isApproved)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 13, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Text('LIVE ON JOB BOARD',
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669),
                      letterSpacing: 1)),
              const Spacer(),
              if (postedAt != null)
                Text(
                  'Posted ${DateFormat('MMM dd, yyyy').format(postedAt)}',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF059669).withOpacity(0.7)),
                ),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

            // ── Title + company + status badge ──────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: sColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business_center_outlined,
                    color: sColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          height: 1.2)),
                  const SizedBox(height: 3),
                  Text(company,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              // Status — staff: dropdown, alumni: static
              if (isStaff)
                PopupMenuButton<String>(
                  tooltip: 'Change status',
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: _StatusBadge(
                      label: status.toUpperCase(),
                      color: sColor,
                      showArrow: true),
                  onSelected: (v) {
                    if (v == 'approved') onApprove();
                    if (v == 'rejected') onReject();
                  },
                  itemBuilder: (_) =>
                      ['approved', 'pending', 'rejected']
                          .map((s) => PopupMenuItem(
                                value: s,
                                child: Row(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: statusColor(s),
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    s[0].toUpperCase() +
                                        s.substring(1),
                                    style: GoogleFonts.inter(
                                        fontSize: 13)),
                                ]),
                              ))
                          .toList(),
                )
              else
                _StatusBadge(
                    label: status.toUpperCase(), color: sColor),
            ]),

            const SizedBox(height: 14),

            // ── Meta chips ──────────────────────────────────────────────
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (location.isNotEmpty)
                _MetaChip(Icons.location_on_outlined, location),
              _MetaChip(Icons.schedule_outlined, type),
              if (category.isNotEmpty)
                _MetaChip(Icons.category_outlined, category),
              if (salary.isNotEmpty)
                _MetaChip(Icons.payments_outlined, salary,
                    color: const Color(0xFF059669)),
              if (reqCourse.isNotEmpty)
                _MetaChip(Icons.school_outlined, reqCourse,
                    color: AppColors.brandRed),
            ]),

            // ── Description preview ─────────────────────────────────────
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedText,
                      height: 1.55)),
            ],

            // ── Clickable contact methods ───────────────────────────────
            if (applyLink.isNotEmpty ||
                contactEmail.isNotEmpty ||
                contactPhone.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (applyLink.isNotEmpty)
                  _ClickableContact(
                    icon:  Icons.open_in_new_rounded,
                    label: 'Apply Online',
                    color: const Color(0xFF2563EB),
                    onTap: () => onLaunchUrl(applyLink),
                  ),
                if (contactEmail.isNotEmpty)
                  _ClickableContact(
                    icon:  Icons.email_outlined,
                    label: contactEmail,
                    color: const Color(0xFF7C3AED),
                    onTap: () => onLaunchEmail(contactEmail, title),
                  ),
                if (contactPhone.isNotEmpty)
                  _ClickableContact(
                    icon:  Icons.phone_outlined,
                    label: contactPhone,
                    color: const Color(0xFF059669),
                    onTap: () => onLaunchPhone(contactPhone),
                  ),
              ]),
            ],

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF0F2F5), height: 1),
            const SizedBox(height: 10),

            // ── Footer: date + action buttons ───────────────────────────
            Row(children: [
              if (postedAt != null && !isApproved)
                Text(
                  DateFormat('MMM dd, yyyy').format(postedAt),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.mutedText),
                ),
              const Spacer(),

              if (isStaff && status == 'pending') ...[
                _IconActionBtn(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF059669),
                  tooltip: 'Approve',
                  onTap: onApprove,
                ),
                const SizedBox(width: 4),
                _IconActionBtn(
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFDC2626),
                  tooltip: 'Reject',
                  onTap: onReject,
                ),
                const SizedBox(width: 4),
              ],

              if (isStaff || isOwner) ...[
                _IconActionBtn(
                  icon: Icons.edit_outlined,
                  color: AppColors.mutedText,
                  tooltip: 'Edit',
                  onTap: onEdit,
                ),
                const SizedBox(width: 4),
              ],

              if (isStaff)
                _IconActionBtn(
                  icon: Icons.delete_outline,
                  color: const Color(0xFFDC2626),
                  tooltip: 'Delete',
                  onTap: onDelete,
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  REUSABLE SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Status badge (with optional dropdown arrow for staff)
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   showArrow;
  const _StatusBadge({
    required this.label,
    required this.color,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5)),
        if (showArrow) ...[
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 13, color: color),
        ],
      ]),
    );
  }
}

/// Compact metadata chip (location, type, salary, etc.)
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _MetaChip(this.icon, this.label,
      {this.color = AppColors.mutedText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: color,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

/// Fully tappable contact chip — opens browser / mail / dialer on tap
class _ClickableContact extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ClickableContact({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to open',
      child: Material(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: color.withOpacity(0.12),
          highlightColor: color.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_outward_rounded, size: 11, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Icon-only action button (approve / reject / edit / delete)
class _IconActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;
  const _IconActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

/// Section label inside the post/edit sheet
class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  subtitle;
  const _SheetSection({
    required this.icon,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: AppColors.brandRed),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: AppColors.brandRed)),
      ]),
      if (subtitle != null) ...[
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Text(subtitle!,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedText,
                  height: 1.4)),
        ),
      ],
    ]);
  }
}

/// Coloured info banner inside the post sheet
class _SheetBanner extends StatelessWidget {
  final IconData icon;
  final String   message;
  final Color    color;
  final EdgeInsets margin;
  const _SheetBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color.withOpacity(0.8), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: color.shade800 ?? color,
                  height: 1.4)),
        ),
      ]),
    );
  }
}

// ── Extension to safely access MaterialColor shades ─────────────────────────
extension _ColorShade on Color {
  Color? get shade800 {
    if (this == Colors.orange) return Colors.orange.shade800;
    if (this == Colors.blue)   return Colors.blue.shade800;
    return null;
  }
}