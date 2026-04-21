import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EVENT STATUS HELPER
//
// Computes the display status based on current time and stored dates.
// Admin-set statuses (DRAFT, CANCELLED) are always respected.
// PUBLISHED, ONGOING, COMPLETED are auto-derived from dates when possible.
// ─────────────────────────────────────────────────────────────────────────────

class _EventStatus {
  static const draft      = 'DRAFT';
  static const published  = 'PUBLISHED';
  static const ongoing    = 'ONGOING';
  static const completed  = 'COMPLETED';
  static const cancelled  = 'CANCELLED';

  /// Returns the effective display status for an event.
  /// Draft and Cancelled are sticky — only changed manually by admin.
  /// Published, Ongoing, Completed are auto-derived from dates.
  static String resolve({
    required String stored,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    if (stored == draft || stored == cancelled) return stored;
    if (startDate == null) return stored;

    final now = DateTime.now();
    if (endDate != null && now.isAfter(endDate)) return completed;
    if (now.isAfter(startDate) || now.isAtSameMomentAs(startDate)) return ongoing;
    return published;
  }

  static Color color(String status) {
    switch (status.toUpperCase()) {
      case published:  return const Color(0xFF3B82F6);
      case ongoing:    return const Color(0xFFF59E0B);
      case completed:  return const Color(0xFF10B981);
      case cancelled:  return const Color(0xFFEF4444);
      default:         return const Color(0xFF9CA3AF); // draft
    }
  }

  static IconData icon(String status) {
    switch (status.toUpperCase()) {
      case published:  return Icons.schedule_outlined;
      case ongoing:    return Icons.play_circle_outline;
      case completed:  return Icons.check_circle_outline;
      case cancelled:  return Icons.cancel_outlined;
      default:         return Icons.edit_outlined; // draft
    }
  }

  /// Human-readable time context: "Happening Now", "3 days away", "Ended 2d ago"
  static String? timeLabel(DateTime? startDate, DateTime? endDate) {
    if (startDate == null) return null;
    final now = DateTime.now();

    if (endDate != null && now.isAfter(endDate)) {
      final diff = now.difference(endDate);
      if (diff.inDays == 0) return 'Ended today';
      return 'Ended ${diff.inDays}d ago';
    }

    if (now.isAfter(startDate)) return 'Happening Now';

    final diff = startDate.difference(now);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'In ${diff.inDays} days';
    if (diff.inDays < 30) return 'In ${(diff.inDays / 7).floor()}w';
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EventPlanningScreen extends StatefulWidget {
  const EventPlanningScreen({super.key});

  @override
  State<EventPlanningScreen> createState() => _EventPlanningScreenState();
}

class _EventPlanningScreenState extends State<EventPlanningScreen> {
  String? _userRole;
  String  _adminName    = 'Admin';
  String  _searchQuery  = '';
  String? _statusFilter;

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
          .collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _userRole  = d['role']?.toString() ?? 'alumni';
          _adminName = d['name']?.toString() ??
                       d['fullName']?.toString() ??
                       user.displayName ?? 'Admin';
        });
      }
    } catch (e) {
      debugPrint('Role load error: $e');
    }
  }

  bool get _canManage =>
      _userRole == 'admin'    ||
      _userRole == 'staff'    ||
      _userRole == 'moderator'||
      _userRole == 'registrar';

  // ══════════════════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════════════════

  Future<void> _showAlert({
    required String title,
    required String message,
    IconData icon  = Icons.info_outline,
    Color   color  = AppColors.brandRed,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _StyledAlertDialog(
          title: title, message: message, icon: icon, color: color),
    );
  }

  Future<bool?> _showConfirm({
    required String title,
    required String message,
    required String confirmLabel,
    Color   confirmColor = Colors.red,
    IconData icon        = Icons.warning_amber_outlined,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _StyledConfirmDialog(
        title:        title,
        message:      message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        icon:         icon,
      ),
    );
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  // ══════════════════════════════════════════════════════
  //  DATE / TIME PICKER
  // ══════════════════════════════════════════════════════

  Future<DateTime?> _pickDateTime(BuildContext ctx, DateTime? initial) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => _redTheme(child!),
    );
    if (date == null || !ctx.mounted) return null;

    final time = await showTimePicker(
      context: ctx,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
      builder: (context, child) => _redTheme(child!),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _redTheme(Widget child) => Theme(
    data: ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(primary: AppColors.brandRed),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
      ),
    ),
    child: child,
  );

  // ══════════════════════════════════════════════════════
  //  FIRESTORE ACTIONS
  // ══════════════════════════════════════════════════════

  Future<void> _deleteEvent(String id, String title) async {
    final ok = await _showConfirm(
      title:        'Delete Event',
      message:      'Permanently delete "$title"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
      icon:         Icons.delete_outline,
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('events').doc(id).delete();
      _snack('Event deleted', isError: false);
    } catch (_) {
      await _showAlert(
        title:   'Delete Failed',
        message: 'Could not delete this event. Check your connection and try again.',
        icon:    Icons.cloud_off_outlined,
        color:   Colors.red,
      );
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(id).update({
        'status':    status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Status updated to $status', isError: false);
    } catch (e) {
      _snack('Failed to update status: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  EVENT FORM
  // ══════════════════════════════════════════════════════

  void _openEventForm({String? eventId, Map<String, dynamic>? data}) {
    final isEdit    = eventId != null;
    final formKey   = GlobalKey<FormState>();

    final titleCtrl    = TextEditingController(text: data?['title']?.toString()       ?? '');
    final descCtrl     = TextEditingController(text: data?['description']?.toString() ?? '');
    final locationCtrl = TextEditingController(text: data?['location']?.toString()    ?? '');
    final capacityCtrl = TextEditingController(text: data?['capacity']?.toString()    ?? '');

    DateTime? startDate = (data?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate   = (data?['endDate']   as Timestamp?)?.toDate();
    String    status    = data?['status']?.toString()    ?? 'DRAFT';
    bool      isImportant = data?['isImportant'] as bool? ?? false;
    bool      isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.95,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        isEdit ? 'Edit Event' : 'Create Event',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 26, fontWeight: FontWeight.w600,
                            color: AppColors.darkText),
                      ),
                      Text(
                        isEdit ? 'Update event details' : 'Fields marked * are required',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                      ),
                    ]),
                  ),
                  if (!isSubmitting)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.mutedText),
                      ),
                    ),
                  const SizedBox(width: 10),
                  _FormSaveButton(
                    isEdit:        isEdit,
                    isSubmitting:  isSubmitting,
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (startDate == null) {
                        await _showAlert(
                          title: 'Start Date Required',
                          message: 'Please set a start date and time before saving.',
                          icon: Icons.calendar_today_outlined, color: Colors.orange,
                        );
                        return;
                      }
                      if (!isEdit && startDate!.isBefore(
                          DateTime.now().subtract(const Duration(minutes: 5)))) {
                        await _showAlert(
                          title: 'Invalid Date',
                          message: 'Start date cannot be in the past.',
                          icon: Icons.history, color: Colors.orange,
                        );
                        return;
                      }
                      if (endDate != null && endDate!.isBefore(startDate!)) {
                        await _showAlert(
                          title: 'Invalid End Date',
                          message: 'End date must be after the start date.',
                          icon: Icons.event_busy_outlined, color: Colors.orange,
                        );
                        return;
                      }
                      setSheet(() => isSubmitting = true);
                      final payload = <String, dynamic>{
                        'title':       titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'location':    locationCtrl.text.trim(),
                        'capacity':    int.tryParse(capacityCtrl.text.trim()) ?? 0,
                        'startDate':   Timestamp.fromDate(startDate!),
                        'endDate':     endDate != null ? Timestamp.fromDate(endDate!) : null,
                        'status':      status,
                        'isImportant': isImportant,
                        'updatedAt':   FieldValue.serverTimestamp(),
                      };
                      try {
                        if (isEdit) {
                          await FirebaseFirestore.instance
                              .collection('events').doc(eventId).update(payload);
                        } else {
                          payload['createdAt']    = FieldValue.serverTimestamp();
                          payload['createdBy']    = FirebaseAuth.instance.currentUser?.uid ?? '';
                          payload['createdByRole']= _userRole ?? '';
                          payload['likesCount']   = 0;
                          await FirebaseFirestore.instance
                              .collection('events').add(payload);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack(isEdit
                              ? 'Event updated successfully!'
                              : 'Event created successfully!',
                              isError: false);
                        }
                      } catch (e) {
                        setSheet(() => isSubmitting = false);
                        if (ctx.mounted) {
                          await _showAlert(
                            title: 'Save Failed',
                            message: 'Something went wrong. Please check your connection.',
                            icon: Icons.cloud_off_outlined, color: Colors.red,
                          );
                        }
                      }
                    },
                  ),
                ]),
              ),

              Divider(height: 1, color: AppColors.borderSubtle.withOpacity(0.6)),

              // ── Form ──
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(24),
                    children: [

                      // ── Status note ──
                      _InfoBanner(
                        icon:  Icons.auto_awesome_outlined,
                        color: Colors.purple,
                        text:  'Status auto-updates to Ongoing / Completed based on dates. '
                               'Draft and Cancelled are always manually set.',
                      ),
                      const SizedBox(height: 22),

                      // ── Section: Basics ──
                      _FormSectionLabel('Event Details'),
                      const SizedBox(height: 12),
                      _formField(controller: titleCtrl,
                        label: 'Event Title *',
                        hint:  'e.g. Grand Alumni Homecoming 2026',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Title is required';
                          if (v.trim().length < 5) return 'At least 5 characters';
                          if (v.trim().length > 150) return 'Max 150 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _formField(controller: descCtrl,
                        label:    'Description *',
                        hint:     'What is this event about?',
                        maxLines: 4,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Description is required';
                          if (v.trim().length < 10) return 'At least 10 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _formField(controller: locationCtrl,
                        label:      'Location *',
                        hint:       'e.g. College Gymnasium, Cebu City',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Location is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _formField(controller: capacityCtrl,
                        label:         'Capacity *',
                        hint:          'Max attendees (0 = unlimited)',
                        prefixIcon:    Icons.people_outline,
                        keyboardType:  TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required (use 0 for unlimited)';
                          final n = int.tryParse(v.trim());
                          if (n == null) return 'Must be a whole number';
                          if (n < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Section: Schedule ──
                      _FormSectionLabel('Schedule'),
                      const SizedBox(height: 12),
                      _DateTile(
                        label: 'Start Date & Time *',
                        value: startDate,
                        onTap: () async {
                          final p = await _pickDateTime(ctx, startDate);
                          if (p != null) setSheet(() => startDate = p);
                        },
                      ),
                      const SizedBox(height: 10),
                      _DateTile(
                        label:   'End Date & Time (optional)',
                        value:   endDate,
                        onTap: () async {
                          final p = await _pickDateTime(ctx, endDate);
                          if (p != null) setSheet(() => endDate = p);
                        },
                        onClear: endDate != null
                            ? () => setSheet(() => endDate = null)
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // ── Section: Settings ──
                      _FormSectionLabel('Settings'),
                      const SizedBox(height: 12),

                      // Status dropdown
                      _StyledDropdown<String>(
                        label: 'Manual Status Override',
                        value: status,
                        items: const [
                          'DRAFT', 'PUBLISHED', 'ONGOING', 'COMPLETED', 'CANCELLED'
                        ],
                        onChanged: (v) { if (v != null) setSheet(() => status = v); },
                      ),
                      const SizedBox(height: 12),

                      // Important toggle
                      _ToggleTile(
                        icon:     Icons.star_outline,
                        title:    'Mark as Important',
                        subtitle: 'Highlight this event for all alumni',
                        value:    isImportant,
                        onChanged: (v) => setSheet(() => isImportant = v),
                      ),

                      const SizedBox(height: 32),
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

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Sidebar ──
        _Sidebar(
          adminName: _adminName,
          userRole:  _userRole,
          onSignOut: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            }
          },
        ),

        // ── Main content ──
        Expanded(
          child: Column(children: [

            // ── Top bar ──
            _TopBar(
              canManage:  _canManage,
              onCreateTap: () => _openEventForm(),
            ),

            // ── Search + filter chips ──
            _SearchFilterBar(
              statusFilter: _statusFilter,
              onSearch: (v) => setState(() => _searchQuery = v.toLowerCase()),
              onFilterChanged: (v) => setState(() => _statusFilter = v),
            ),

            // ── Event list ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .orderBy('startDate', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: AppColors.brandRed, strokeWidth: 2));
                  }
                  if (snap.hasError) {
                    return _ErrorState(error: '${snap.error}');
                  }

                  var docs = snap.data?.docs ?? [];

                  // Apply status filter — match against resolved status
                  if (_statusFilter != null) {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final resolved = _EventStatus.resolve(
                        stored:    data['status']?.toString() ?? 'DRAFT',
                        startDate: (data['startDate'] as Timestamp?)?.toDate(),
                        endDate:   (data['endDate']   as Timestamp?)?.toDate(),
                      );
                      return resolved == _statusFilter;
                    }).toList();
                  }

                  // Apply search
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((d) {
                      final data  = d.data() as Map<String, dynamic>;
                      final title = data['title']?.toString().toLowerCase()       ?? '';
                      final loc   = data['location']?.toString().toLowerCase()    ?? '';
                      final desc  = data['description']?.toString().toLowerCase() ?? '';
                      return title.contains(_searchQuery) ||
                             loc.contains(_searchQuery)   ||
                             desc.contains(_searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return _EmptyState(
                      canManage:    _canManage,
                      hasFilters:   _statusFilter != null || _searchQuery.isNotEmpty,
                      onCreateTap:  () => _openEventForm(),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(32),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final doc  = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      return _EventCard(
                        id:         doc.id,
                        data:       data,
                        canManage:  _canManage,
                        onEdit:     () => _openEventForm(eventId: doc.id, data: data),
                        onDelete:   () => _deleteEvent(doc.id, data['title']?.toString() ?? ''),
                        onStatusChange: (s) => _updateStatus(doc.id, s),
                        onSnack:    _snack,
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Form helpers ────────────────────────────────────────────────────────────

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
      controller:       controller,
      maxLines:         maxLines,
      keyboardType:     keyboardType,
      style:            GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        labelStyle: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.w500),
        hintStyle:  GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.mutedText, size: 20) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderSubtle)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderSubtle)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        filled:         true,
        fillColor:      AppColors.softWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final String  adminName;
  final String? userRole;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.adminName,
    required this.userRole,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Brand
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALUMNI',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, letterSpacing: 6,
                    color: AppColors.brandRed, fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('ARCHIVE PORTAL',
                style: GoogleFonts.inter(
                    fontSize: 9, letterSpacing: 2,
                    color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ]),
        ),

        // Nav
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _navSection('NETWORK', [
                _navItem(context, 'Overview', route: '/admin_dashboard'),
              ]),
              const SizedBox(height: 32),
              _navSection('ENGAGEMENT', [
                _navItem(context, 'Career Milestones', route: '/career_milestones'),
              ]),
              const SizedBox(height: 32),
              _navSection('ADMIN FEATURES', [
                _navItem(context, 'User Verification & Moderation',
                    route: '/user_verification_moderation'),
                _navItem(context, 'Event Planning',
                    route: '/event_planning', isActive: true),
                _navItem(context, 'Job Board Management',
                    route: '/job_board_management'),
                _navItem(context, 'Growth Metrics', route: '/growth_metrics'),
                _navItem(context, 'Announcement Management',
                    route: '/announcement_management'),
              ]),
            ]),
          ),
        ),

        // User footer
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(
                color: AppColors.borderSubtle.withOpacity(0.3))),
          ),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brandRed.withOpacity(0.1),
                child: Text(
                  adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                  style: GoogleFonts.cormorantGaramond(
                      color: AppColors.brandRed, fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(adminName,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.darkText),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text((userRole ?? 'admin').toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 9, color: AppColors.mutedText,
                        letterSpacing: 0.8)),
              ])),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout, size: 13, color: AppColors.mutedText),
                label: Text('DISCONNECT',
                    style: GoogleFonts.inter(
                        fontSize: 10, letterSpacing: 2,
                        color: AppColors.mutedText, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _navSection(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: GoogleFonts.inter(
              fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold,
              color: AppColors.mutedText.withOpacity(0.7))),
      const SizedBox(height: 14),
      ...items,
    ],
  );

  Widget _navItem(BuildContext context, String label,
      {String? route, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null && !isActive
            ? () => Navigator.pushNamed(context, route) : null,
        child: MouseRegion(
          cursor: !isActive
              ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: isActive ? AppColors.brandRed : AppColors.darkText,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool canManage;
  final VoidCallback onCreateTap;

  const _TopBar({required this.canManage, required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Event Planning',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 34, fontWeight: FontWeight.w400,
                  color: AppColors.darkText, height: 1.0)),
          const SizedBox(height: 4),
          Text('Coordinate and track all alumni gatherings.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText)),
        ]),
        const Spacer(),
        if (canManage)
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('New Event',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ]),
    );
  }
}

// ── Search + filter bar ───────────────────────────────────────────────────────

class _SearchFilterBar extends StatelessWidget {
  final String?  statusFilter;
  final ValueChanged<String>  onSearch;
  final ValueChanged<String?> onFilterChanged;

  const _SearchFilterBar({
    required this.statusFilter,
    required this.onSearch,
    required this.onFilterChanged,
  });

  static const _filters = <String?, String>{
    null:        'All',
    'DRAFT':     'Draft',
    'PUBLISHED': 'Published',
    'ONGOING':   'Ongoing',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(children: [
        Divider(height: 1, color: AppColors.borderSubtle.withOpacity(0.5)),
        const SizedBox(height: 14),
        TextField(
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
          decoration: InputDecoration(
            hintText: 'Search events by title, location, or description…',
            hintStyle: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.mutedText, size: 20),
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
          onChanged: onSearch,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.entries.map((e) {
              final isSelected = statusFilter == e.key;
              final color = e.key != null
                  ? _EventStatus.color(e.key!)
                  : AppColors.mutedText;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFilterChanged(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.12)
                          : AppColors.softWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : AppColors.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (e.key != null) ...[
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? color : AppColors.mutedText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(e.value,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? color : AppColors.mutedText)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final String               id;
  final Map<String, dynamic> data;
  final bool                 canManage;
  final VoidCallback         onEdit;
  final VoidCallback         onDelete;
  final ValueChanged<String> onStatusChange;
  final void Function(String, {required bool isError}) onSnack;

  const _EventCard({
    required this.id,
    required this.data,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
    final storedStatus = data['status']?.toString() ?? 'DRAFT';
    final startDate    = (data['startDate'] as Timestamp?)?.toDate();
    final endDate      = (data['endDate']   as Timestamp?)?.toDate();
    final title        = data['title']?.toString()       ?? 'Untitled Event';
    final description  = data['description']?.toString() ?? '';
    final location     = data['location']?.toString()    ?? 'TBD';
    final capacity     = data['capacity']?.toString()    ?? '0';
    final isImportant  = data['isImportant'] as bool?    ?? false;
    final currentUid   = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Resolve effective display status from dates
    final status = _EventStatus.resolve(
      stored: storedStatus, startDate: startDate, endDate: endDate);
    final statusColor = _EventStatus.color(status);
    final timeLabel   = _EventStatus.timeLabel(startDate, endDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'DRAFT'
              ? AppColors.borderSubtle
              : statusColor.withOpacity(0.25),
          width: 0.8,
        ),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Status accent bar ──
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Title row ──
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Event icon
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_EventStatus.icon(status),
                    color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Title + location
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppColors.darkText, height: 1.25)),
                    ),
                    if (isImportant) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_rounded,
                              size: 10, color: Colors.amber.shade700),
                          const SizedBox(width: 3),
                          Text('Important',
                              style: GoogleFonts.inter(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade700,
                                  letterSpacing: 0.3)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.mutedText),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(location,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.mutedText),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              )),

              const SizedBox(width: 10),

              // Status badge / dropdown
              if (canManage)
                _StatusDropdown(
                  status:   status,
                  color:    statusColor,
                  onSelect: onStatusChange,
                )
              else
                _StatusBadge(status: status, color: statusColor),
            ]),

            // ── Description ──
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText, height: 1.55)),
            ],

            const SizedBox(height: 14),

            // ── Info chips ──
            Wrap(spacing: 6, runSpacing: 8, children: [
              if (startDate != null)
                _InfoChip(
                  icon:  Icons.calendar_today_outlined,
                  label: DateFormat('EEE, MMM d, yyyy').format(startDate),
                ),
              if (startDate != null)
                _InfoChip(
                  icon:  Icons.access_time_outlined,
                  label: endDate != null
                      ? '${DateFormat('h:mm a').format(startDate)} – ${DateFormat('h:mm a').format(endDate)}'
                      : DateFormat('h:mm a').format(startDate),
                ),
              _InfoChip(
                icon:  Icons.people_outline,
                label: int.tryParse(capacity) == 0
                    ? 'Unlimited' : '$capacity capacity',
              ),
              // Time label (Happening Now / 3 days away / etc.)
              if (timeLabel != null)
                _InfoChip(
                  icon:  status == 'ONGOING'
                      ? Icons.radio_button_checked : Icons.schedule_outlined,
                  label: timeLabel,
                  color: status == 'ONGOING'
                      ? Colors.green : AppColors.brandRed,
                  highlighted: true,
                ),
            ]),

            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.borderSubtle.withOpacity(0.5)),
            const SizedBox(height: 12),

            // ── RSVP row ──
            if (status != 'CANCELLED' &&
                status != 'COMPLETED' &&
                currentUid.isNotEmpty)
              _RsvpRow(eventId: id, currentUid: currentUid, onSnack: onSnack),

            if (status == 'CANCELLED')
              _StatusNote(
                icon: Icons.block, color: Colors.red,
                label: 'This event has been cancelled.',
              ),

            if (status == 'COMPLETED')
              _StatusNote(
                icon: Icons.check_circle_outline, color: Colors.green,
                label: 'This event has ended.',
              ),

            // ── Admin actions ──
            if (canManage) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _CardActionBtn(
                  icon: Icons.edit_outlined, label: 'Edit',
                  color: AppColors.mutedText, onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _CardActionBtn(
                  icon: Icons.delete_outline, label: 'Delete',
                  color: Colors.red, onTap: onDelete,
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── RSVP Row ──────────────────────────────────────────────────────────────────

class _RsvpRow extends StatelessWidget {
  final String eventId;
  final String currentUid;
  final void Function(String, {required bool isError}) onSnack;

  const _RsvpRow({
    required this.eventId,
    required this.currentUid,
    required this.onSnack,
  });

  static const _options = [
    (label: 'Going',  value: 'going',     color: Color(0xFF10B981), icon: Icons.check_circle_outline),
    (label: 'Maybe',  value: 'maybe',     color: Color(0xFFF59E0B), icon: Icons.help_outline),
    (label: 'No',     value: 'not_going', color: Color(0xFFEF4444), icon: Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events').doc(eventId)
          .collection('rsvps').doc(currentUid).snapshots(),
      builder: (context, snap) {
        final rsvpData   = snap.data?.data() as Map<String, dynamic>?;
        final rsvpStatus = rsvpData?['status']?.toString();

        return Row(children: [
          Text('RSVP:',
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.mutedText, letterSpacing: 0.5)),
          const SizedBox(width: 10),

          ..._options.map((opt) {
            final isSelected = rsvpStatus == opt.value;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () async {
                  final ref = FirebaseFirestore.instance
                      .collection('events').doc(eventId)
                      .collection('rsvps').doc(currentUid);
                  if (isSelected) {
                    await ref.delete();
                  } else {
                    await ref.set({
                      'uid':    currentUid,
                      'status': opt.value,
                      'rsvpAt': FieldValue.serverTimestamp(),
                    });
                    onSnack('RSVP: ${opt.label}', isError: false);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withOpacity(0.12)
                        : AppColors.softWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? opt.color.withOpacity(0.45)
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(children: [
                    Icon(opt.icon, size: 12,
                        color: isSelected ? opt.color : AppColors.mutedText),
                    const SizedBox(width: 4),
                    Text(opt.label,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? opt.color : AppColors.mutedText)),
                  ]),
                ),
              ),
            );
          }),

          // Going count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events').doc(eventId)
                .collection('rsvps')
                .where('status', isEqualTo: 'going').snapshots(),
            builder: (_, goingSnap) {
              final count = goingSnap.data?.docs.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Row(children: [
                Container(width: 1, height: 14,
                    color: AppColors.borderSubtle),
                const SizedBox(width: 8),
                Text('$count going',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700)),
              ]);
            },
          ),
        ]);
      },
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color  color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: color, letterSpacing: 0.5)),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String                 status;
  final Color                  color;
  final ValueChanged<String>   onSelect;
  const _StatusDropdown({required this.status, required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Change status',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(status,
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: color, letterSpacing: 0.5)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 14, color: color),
        ]),
      ),
      onSelected: onSelect,
      itemBuilder: (_) => ['DRAFT', 'PUBLISHED', 'ONGOING', 'COMPLETED', 'CANCELLED']
          .map((s) => PopupMenuItem(
            value: s,
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: _EventStatus.color(s), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(s, style: GoogleFonts.inter(fontSize: 13)),
            ]),
          )).toList(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  final bool     highlighted;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? c.withOpacity(0.1) : AppColors.softWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? c.withOpacity(0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: c,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }
}

class _StatusNote extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _StatusNote({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _CardActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _CardActionBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Form helpers ──────────────────────────────────────────────────────────────

class _FormSectionLabel extends StatelessWidget {
  final String text;
  const _FormSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 16, height: 1, color: AppColors.brandRed),
      const SizedBox(width: 8),
      Text(text,
          style: GoogleFonts.inter(
              fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700,
              color: AppColors.brandRed)),
    ]);
  }
}

class _FormSaveButton extends StatelessWidget {
  final bool         isEdit;
  final bool         isSubmitting;
  final VoidCallback onTap;
  const _FormSaveButton({required this.isEdit, required this.isSubmitting,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSubmitting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSubmitting
              ? AppColors.brandRed.withOpacity(0.5)
              : AppColors.brandRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isSubmitting
            ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                isEdit ? 'Save Changes' : 'Create Event',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13, color: Colors.white),
              ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _InfoBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 11, color: color.withOpacity(0.85), height: 1.5)),
        ),
      ]),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String    label;
  final DateTime? value;
  final VoidCallback  onTap;
  final VoidCallback? onClear;
  const _DateTile({required this.label, required this.value,
      required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? AppColors.brandRed.withOpacity(0.45)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: AppColors.brandRed, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.mutedText,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              value != null
                  ? DateFormat('EEE, MMM dd yyyy  •  h:mm a').format(value!)
                  : 'Tap to set',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: value != null ? AppColors.darkText : AppColors.mutedText,
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.normal),
            ),
          ])),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: AppColors.mutedText),
            )
          else
            Icon(
              value != null ? Icons.edit_outlined : Icons.add_circle_outline,
              color: AppColors.brandRed, size: 18,
            ),
        ]),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final String           label;
  final T                value;
  final List<T>          items;
  final ValueChanged<T?> onChanged;
  const _StyledDropdown({required this.label, required this.value,
      required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: GoogleFonts.inter(
              color: AppColors.brandRed, fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
        items: items.map((v) => DropdownMenuItem<T>(
          value: v,
          child: Text(v.toString(),
              style: GoogleFonts.inter(fontSize: 14)),
        )).toList(),
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData          icon;
  final String            title;
  final String            subtitle;
  final bool              value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.title,
      required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.brandRed, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
        value: value,
        activeColor: AppColors.brandRed,
        onChanged: onChanged,
      ),
    );
  }
}

// ── Alert / Confirm dialogs ───────────────────────────────────────────────────

class _StyledAlertDialog extends StatelessWidget {
  final String   title;
  final String   message;
  final IconData icon;
  final Color    color;
  const _StyledAlertDialog({required this.title, required this.message,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22, fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Got it',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StyledConfirmDialog extends StatelessWidget {
  final String   title;
  final String   message;
  final String   confirmLabel;
  final Color    confirmColor;
  final IconData icon;
  const _StyledConfirmDialog({required this.title, required this.message,
      required this.confirmLabel, required this.confirmColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: confirmColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: confirmColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22, fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText, height: 1.5)),
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
                  backgroundColor: confirmColor, foregroundColor: Colors.white,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(confirmLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         canManage;
  final bool         hasFilters;
  final VoidCallback onCreateTap;
  const _EmptyState({required this.canManage, required this.hasFilters,
      required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(48),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_busy_outlined,
              size: 38, color: AppColors.mutedText),
        ),
        const SizedBox(height: 20),
        Text(
          hasFilters ? 'No matching events' : 'No events yet',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 26, fontWeight: FontWeight.w400,
              color: AppColors.darkText),
        ),
        const SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Try adjusting your search or filters.'
              : 'Create your first event to get started.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
        ),
        if (canManage && !hasFilters) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Create Event',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ]),
    ));
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text('Error loading events',
          style: GoogleFonts.inter(
              color: Colors.red, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(error,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText)),
    ]));
  }
}