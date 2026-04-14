import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class EventPlanningScreen extends StatefulWidget {
  const EventPlanningScreen({super.key});

  @override
  State<EventPlanningScreen> createState() =>
      _EventPlanningScreenState();
}

class _EventPlanningScreenState
    extends State<EventPlanningScreen> {
  String? _userRole;
  String _adminName = 'Admin';
  String _searchQuery = '';
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
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _userRole =
              data['role']?.toString() ?? 'alumni';
          _adminName = data['name']?.toString() ??
              data['fullName']?.toString() ??
              user.displayName ??
              'Admin';
        });
      }
    } catch (e) {
      debugPrint('Role error: $e');
    }
  }

  bool get _canManage =>
      _userRole == 'admin' ||
      _userRole == 'staff' ||
      _userRole == 'moderator' ||
      _userRole == 'registrar';

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.blue;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.mutedText;
    }
  }

  // ══════════════════════════════════════════════
  //  STYLED ALERT DIALOG
  // ══════════════════════════════════════════════

  Future<void> _showAlert({
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    Color color = AppColors.brandRed,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 360,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedText,
                      height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                  child: Text('Got it',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = Colors.red,
    IconData icon = Icons.warning_amber_outlined,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 360,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: confirmColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedText,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedText,
                      side: const BorderSide(
                          color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                    child: Text(confirmLabel,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  CREATE / EDIT EVENT FORM
  // ══════════════════════════════════════════════

  void _showEventForm({
    String? eventId,
    Map<String, dynamic>? initialData,
  }) {
    final isEdit = eventId != null;
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(
        text: initialData?['title']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text:
            initialData?['description']?.toString() ?? '');
    final locationCtrl = TextEditingController(
        text: initialData?['location']?.toString() ?? '');
    final capacityCtrl = TextEditingController(
        text:
            initialData?['capacity']?.toString() ?? '');

    DateTime? startDate =
        (initialData?['startDate'] as Timestamp?)
            ?.toDate();
    DateTime? endDate =
        (initialData?['endDate'] as Timestamp?)
            ?.toDate();
    String status =
        initialData?['status']?.toString() ?? 'DRAFT';
    bool isVirtual =
        initialData?['isVirtual'] as bool? ?? false;
    bool isImportant =
        initialData?['isImportant'] as bool? ?? false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) =>
            DraggableScrollableSheet(
          initialChildSize: 0.93,
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
                      horizontal: 20, vertical: 4),
                  child: Row(children: [
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? 'Edit Event'
                              : 'Create Event',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.w600),
                        ),
                        Text(
                          isEdit
                              ? 'Update event details'
                              : 'Fill in all required fields',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.mutedText),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              // ─── Form validation ───
                              if (!formKey.currentState!
                                  .validate()) {
                                return;
                              }

                              // ─── Date validation ───
                              if (startDate == null) {
                                await _showAlert(
                                  title: 'Start Date Required',
                                  message:
                                      'Please set a start date and time for this event before saving.',
                                  icon: Icons
                                      .calendar_today_outlined,
                                  color: Colors.orange,
                                );
                                return;
                              }

                              if (startDate!.isBefore(
                                  DateTime.now().subtract(
                                      const Duration(
                                          minutes: 5))) &&
                                  !isEdit) {
                                await _showAlert(
                                  title: 'Invalid Date',
                                  message:
                                      'Start date cannot be in the past. Please choose a future date and time.',
                                  icon: Icons.history,
                                  color: Colors.orange,
                                );
                                return;
                              }

                              if (endDate != null &&
                                  endDate!.isBefore(
                                      startDate!)) {
                                await _showAlert(
                                  title: 'Invalid End Date',
                                  message:
                                      'End date and time must be after the start date. Please adjust your schedule.',
                                  icon: Icons
                                      .event_busy_outlined,
                                  color: Colors.orange,
                                );
                                return;
                              }

                              setSheet(() =>
                                  isSubmitting = true);

                              final eventData = {
                                'title': titleCtrl.text
                                    .trim(),
                                'description':
                                    descCtrl.text.trim(),
                                'location': locationCtrl
                                    .text
                                    .trim(),
                                'capacity':
                                    int.tryParse(
                                            capacityCtrl
                                                .text
                                                .trim()) ??
                                        0,
                                'startDate':
                                    Timestamp.fromDate(
                                        startDate!),
                                'endDate': endDate != null
                                    ? Timestamp.fromDate(
                                        endDate!)
                                    : null,
                                'status': status,
                                'isVirtual': isVirtual,
                                'isImportant': isImportant,
                                'updatedAt': FieldValue
                                    .serverTimestamp(),
                              };

                              try {
                                if (isEdit) {
                                  await FirebaseFirestore
                                      .instance
                                      .collection(
                                          'events')
                                      .doc(eventId)
                                      .update(eventData);
                                } else {
                                  eventData['createdAt'] =
                                      FieldValue
                                          .serverTimestamp();
                                  eventData[
                                          'createdBy'] =
                                      FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid ??
                                          '';
                                  eventData[
                                          'createdByRole'] =
                                      _userRole ?? '';
                                  eventData[
                                      'likesCount'] = 0;
                                  await FirebaseFirestore
                                      .instance
                                      .collection(
                                          'events')
                                      .add(eventData);
                                }

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  _showSnackBar(
                                    isEdit
                                        ? 'Event updated successfully!'
                                        : 'Event created successfully!',
                                    isError: false,
                                  );
                                }
                              } catch (e) {
                                setSheet(() =>
                                    isSubmitting = false);
                                if (ctx.mounted) {
                                  await _showAlert(
                                    title: 'Save Failed',
                                    message:
                                        'Something went wrong while saving the event. Please check your connection and try again.',
                                    icon: Icons
                                        .cloud_off_outlined,
                                    color: Colors.red,
                                  );
                                }
                              }
                            },
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.brandRed,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: Text(
                        isSubmitting
                            ? 'Saving...'
                            : isEdit
                                ? 'Save Changes'
                                : 'Create Event',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
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
                        // ─── Required fields note ───
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue
                                .withOpacity(0.06),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue
                                    .withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 14,
                                color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                                'Fields marked with * are required',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.blue
                                        .shade700)),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // ─── Title ───
                        _formField(
                          controller: titleCtrl,
                          label: 'Event Title *',
                          hint:
                              'e.g. Grand Alumni Homecoming 2026',
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'Event title is required';
                            }
                            if (v.trim().length < 5) {
                              return 'Title must be at least 5 characters';
                            }
                            if (v.trim().length > 150) {
                              return 'Title cannot exceed 150 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ─── Description ───
                        _formField(
                          controller: descCtrl,
                          label: 'Description *',
                          hint:
                              'What is this event about?',
                          maxLines: 4,
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'Description is required';
                            }
                            if (v.trim().length < 10) {
                              return 'Description must be at least 10 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ─── Location ───
                        _formField(
                          controller: locationCtrl,
                          label: 'Location *',
                          hint:
                              'e.g. College Gym / Online',
                          prefixIcon:
                              Icons.location_on_outlined,
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'Location is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ─── Capacity ───
                        _formField(
                          controller: capacityCtrl,
                          label: 'Capacity *',
                          hint:
                              'Max attendees (0 = unlimited)',
                          prefixIcon:
                              Icons.people_outline,
                          keyboardType:
                              TextInputType.number,
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'Capacity is required (use 0 for unlimited)';
                            }
                            final n = int.tryParse(
                                v.trim());
                            if (n == null) {
                              return 'Capacity must be a whole number';
                            }
                            if (n < 0) {
                              return 'Capacity cannot be negative';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // ─── Start date ───
                        _dateTile(
                          label: 'Start Date & Time *',
                          value: startDate,
                          onTap: () async {
                            final picked =
                                await _pickDateTime(
                                    ctx, startDate);
                            if (picked != null) {
                              setSheet(() =>
                                  startDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // ─── End date ───
                        _dateTile(
                          label:
                              'End Date & Time (optional)',
                          value: endDate,
                          onTap: () async {
                            final picked =
                                await _pickDateTime(
                                    ctx, endDate);
                            if (picked != null) {
                              setSheet(
                                  () => endDate = picked);
                            }
                          },
                          onClear: endDate != null
                              ? () => setSheet(
                                  () => endDate = null)
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // ─── Status ───
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.softWhite,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.borderSubtle),
                          ),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4),
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              labelStyle: GoogleFonts.inter(
                                  color: AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w500),
                              border: InputBorder.none,
                            ),
                            items: [
                              'DRAFT',
                              'PUBLISHED',
                              'ONGOING',
                              'COMPLETED',
                              'CANCELLED',
                            ]
                                .map((v) => DropdownMenuItem<String>(
                                      value: v,
                                      child: Text(v,
                                          style: GoogleFonts.inter(
                                              fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (v) => setSheet(
                                () => status = v!),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.darkText),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Toggles ───
                        _toggleTile(
                          icon: Icons.videocam_outlined,
                          title: 'Virtual Event',
                          subtitle:
                              'This event will be held online',
                          value: isVirtual,
                          onChanged: (v) => setSheet(
                              () => isVirtual = v),
                        ),
                        const SizedBox(height: 10),
                        _toggleTile(
                          icon: Icons.star_outline,
                          title: 'Mark as Important',
                          subtitle:
                              'Highlight this event for all alumni',
                          value: isImportant,
                          onChanged: (v) => setSheet(
                              () => isImportant = v),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
      BuildContext ctx, DateTime? initial) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.brandRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brandRed),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !ctx.mounted) return null;

    final time = await showTimePicker(
      context: ctx,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.brandRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brandRed),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day,
        time.hour, time.minute);
  }

  Future<void> _confirmDelete(
      String eventId, String title) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Event',
      message:
          'Are you sure you want to permanently delete "$title"? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete_outline,
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();
      _showSnackBar('Event deleted', isError: false);
    } catch (e) {
      await _showAlert(
        title: 'Delete Failed',
        message:
            'Could not delete this event. Please check your connection and try again.',
        icon: Icons.cloud_off_outlined,
        color: Colors.red,
      );
    }
  }

  Future<void> _updateStatus(
      String eventId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Status updated to $newStatus',
          isError: false);
    } catch (e) {
      _showSnackBar('Failed to update status: $e',
          isError: true);
    }
  }

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════

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
                                  '/user_verification_moderation'),
                          _sidebarItem('Event Planning',
                              route: '/event_planning',
                              isActive: true),
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
                              ? _adminName[0].toUpperCase()
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
                            Text(
                                (_userRole ?? 'admin')
                                    .toUpperCase(),
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
                          Text('Event Planning',
                              style:
                                  GoogleFonts.cormorantGaramond(
                                fontSize: 32,
                                fontWeight: FontWeight.w400,
                                color: AppColors.darkText,
                              )),
                          Text(
                              'Coordinate and track all alumni gatherings.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                      if (_canManage)
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showEventForm(),
                          icon: const Icon(Icons.add,
                              size: 18),
                          label: Text('Create New Event',
                              style: GoogleFonts.inter(
                                  fontWeight:
                                      FontWeight.w600)),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.brandRed,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14),
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

                // ─── Search + filters ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      32, 12, 32, 12),
                  child: Column(children: [
                    TextField(
                      style:
                          GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search events...',
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
                          _searchQuery = v.toLowerCase()),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip('All', null),
                        const SizedBox(width: 8),
                        _filterChip('Draft', 'DRAFT'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Published', 'PUBLISHED'),
                        const SizedBox(width: 8),
                        _filterChip('Ongoing', 'ONGOING'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Completed', 'COMPLETED'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Cancelled', 'CANCELLED'),
                      ]),
                    ),
                  ]),
                ),

                // ─── Event list ───
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .orderBy('startDate',
                            descending: true)
                        .snapshots(),
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
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red),
                              const SizedBox(height: 12),
                              Text(
                                  'Error loading events',
                                  style:
                                      GoogleFonts.inter(
                                          color:
                                              Colors.red,
                                          fontWeight:
                                              FontWeight
                                                  .w600)),
                              Text(
                                  '${snapshot.error}',
                                  style:
                                      GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors
                                              .mutedText)),
                            ],
                          ),
                        );
                      }

                      var docs =
                          snapshot.data?.docs ?? [];

                      if (_statusFilter != null) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          return data['status']
                                  ?.toString()
                                  .toUpperCase() ==
                              _statusFilter;
                        }).toList();
                      }

                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          final title = data['title']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          final location =
                              data['location']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';
                          final desc =
                              data['description']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';
                          return title.contains(
                                  _searchQuery) ||
                              location.contains(
                                  _searchQuery) ||
                              desc.contains(_searchQuery);
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
                                      .event_busy_outlined,
                                  size: 72,
                                  color: AppColors
                                      .borderSubtle),
                              const SizedBox(height: 16),
                              Text('No events found',
                                  style: GoogleFonts
                                      .cormorantGaramond(
                                          fontSize: 22,
                                          color: AppColors
                                              .darkText)),
                              const SizedBox(height: 8),
                              Text(
                                  _statusFilter != null
                                      ? 'No $_statusFilter events yet'
                                      : 'No events match your search',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors
                                          .mutedText)),
                              if (_canManage &&
                                  _statusFilter == null &&
                                  _searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showEventForm(),
                                  icon: const Icon(
                                      Icons.add,
                                      color: AppColors
                                          .brandRed),
                                  label: Text(
                                      'Create your first event',
                                      style: GoogleFonts
                                          .inter(
                                              color: AppColors
                                                  .brandRed,
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding:
                            const EdgeInsets.all(32),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data()
                              as Map<String, dynamic>;
                          return _eventCard(
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

  // ══════════════════════════════════════════════
  //  EVENT CARD — RSVP is its own section, NOT in the top Row
  // ══════════════════════════════════════════════

  Widget _eventCard(
      String id, Map<String, dynamic> data) {
    final status =
        data['status']?.toString() ?? 'DRAFT';
    final title =
        data['title']?.toString() ?? 'Untitled Event';
    final description =
        data['description']?.toString() ?? '';
    final location =
        data['location']?.toString() ?? 'TBD';
    final capacity =
        data['capacity']?.toString() ?? '0';
    final isVirtual =
        data['isVirtual'] as bool? ?? false;
    final isImportant =
        data['isImportant'] as bool? ?? false;
    final startTs =
        data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final startDt = startTs?.toDate();
    final endDt = endTs?.toDate();
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'DRAFT'
              ? AppColors.borderSubtle
              : _statusColor(status).withOpacity(0.3),
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
          // ─── Top row: icon + title + status badge ───
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor(status)
                      .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_outlined,
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
                            color: AppColors.darkText)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.mutedText),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color:
                                    AppColors.mutedText),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ),
              ),

              // ─── Status badge / dropdown ───
              if (_canManage)
                PopupMenuButton<String>(
                  tooltip: 'Change status',
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status)
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(6),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(status,
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      _statusColor(status),
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down,
                              size: 14,
                              color:
                                  _statusColor(status)),
                        ]),
                  ),
                  onSelected: (v) =>
                      _updateStatus(id, v),
                  itemBuilder: (_) => [
                    'DRAFT',
                    'PUBLISHED',
                    'ONGOING',
                    'COMPLETED',
                    'CANCELLED'
                  ]
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _statusColor(s),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(s,
                                  style: GoogleFonts.inter(
                                      fontSize: 13)),
                            ]),
                          ))
                      .toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status)
                        .withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                  child: Text(status,
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status),
                          letterSpacing: 0.5)),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── Description ───
          if (description.isNotEmpty)
            Text(description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.5)),

          const SizedBox(height: 10),

          // ─── Info chips ───
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (startDt != null)
                _chip(Icons.calendar_today_outlined,
                    DateFormat('MMM dd, yyyy')
                        .format(startDt)),
              if (startDt != null)
                _chip(
                  Icons.access_time_outlined,
                  endDt != null
                      ? '${DateFormat('hh:mm a').format(startDt)} – ${DateFormat('hh:mm a').format(endDt)}'
                      : DateFormat('hh:mm a')
                          .format(startDt),
                ),
              _chip(Icons.people_outline,
                  '$capacity attendees'),
              if (isVirtual)
                _chip(Icons.videocam_outlined,
                    'Virtual',
                    color: Colors.blue),
              if (isImportant)
                _chip(Icons.star_outline, 'Important',
                    color: Colors.orange.shade700),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 10),

          // ─── RSVP row — its own separate section ───
          if (status != 'CANCELLED' &&
              status != 'COMPLETED' &&
              currentUid.isNotEmpty)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(id)
                  .collection('rsvps')
                  .doc(currentUid)
                  .snapshots(),
              builder: (context, rsvpSnap) {
                final rsvpData = rsvpSnap.data?.data()
                    as Map<String, dynamic>?;
                final rsvpStatus =
                    rsvpData?['status']?.toString();

                return Row(
                  children: [
                    Text('RSVP:',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedText,
                            letterSpacing: 0.5)),
                    const SizedBox(width: 10),
                    ...[
                      (
                        'Going',
                        'going',
                        Colors.green,
                        Icons.check_circle_outline
                      ),
                      (
                        'Maybe',
                        'maybe',
                        Colors.orange,
                        Icons.help_outline
                      ),
                      (
                        'No',
                        'not_going',
                        Colors.red,
                        Icons.cancel_outlined
                      ),
                    ].map((opt) {
                      final label = opt.$1;
                      final value = opt.$2;
                      final color = opt.$3;
                      final icon = opt.$4;
                      final isSelected =
                          rsvpStatus == value;

                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () async {
                            final rsvpRef =
                                FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(id)
                                    .collection('rsvps')
                                    .doc(currentUid);
                            if (isSelected) {
                              await rsvpRef.delete();
                            } else {
                              await rsvpRef.set({
                                'uid': currentUid,
                                'status': value,
                                'rsvpAt': FieldValue
                                    .serverTimestamp(),
                              });
                              _showSnackBar(
                                  'RSVP: $label',
                                  isError: false);
                            }
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.12)
                                  : AppColors.softWhite,
                              borderRadius:
                                  BorderRadius.circular(
                                      16),
                              border: Border.all(
                                  color: isSelected
                                      ? color
                                          .withOpacity(0.4)
                                      : AppColors
                                          .borderSubtle),
                            ),
                            child: Row(children: [
                              Icon(icon,
                                  size: 12,
                                  color: isSelected
                                      ? color
                                      : AppColors.mutedText),
                              const SizedBox(width: 4),
                              Text(label,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? color
                                          : AppColors
                                              .mutedText)),
                            ]),
                          ),
                        ),
                      );
                    }),

                    // ─── Going count ───
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .doc(id)
                          .collection('rsvps')
                          .where('status',
                              isEqualTo: 'going')
                          .snapshots(),
                      builder: (context, goingSnap) {
                        final count =
                            goingSnap.data?.docs.length ??
                                0;
                        if (count == 0) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(
                              left: 8),
                          child: Row(children: [
                            Container(
                                width: 1,
                                height: 14,
                                color: AppColors
                                    .borderSubtle),
                            const SizedBox(width: 8),
                            Text('$count going',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight:
                                        FontWeight.w700)),
                          ]),
                        );
                      },
                    ),
                  ],
                );
              },
            ),

          if (status == 'CANCELLED')
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.block,
                    size: 12, color: Colors.red),
                const SizedBox(width: 6),
                Text('This event has been cancelled',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w600)),
              ]),
            ),

          if (status == 'COMPLETED')
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        Colors.green.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 12, color: Colors.green),
                const SizedBox(width: 6),
                Text('This event has ended',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600)),
              ]),
            ),

          // ─── Admin actions ───
          if (_canManage) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                _actionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppColors.mutedText,
                  onTap: () => _showEventForm(
                      eventId: id, initialData: data),
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
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  SIDEBAR HELPERS
  // ══════════════════════════════════════════════

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
                color:
                    AppColors.mutedText.withOpacity(0.7))),
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

  // ══════════════════════════════════════════════
  //  UI HELPERS
  // ══════════════════════════════════════════════

  Widget _chip(IconData icon, String label,
      {Color? color}) {
    final c = color ?? AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
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
                fontSize: 11,
                color: c,
                fontWeight: FontWeight.w500)),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                : AppColors.borderSubtle,
          ),
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

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? AppColors.brandRed.withOpacity(0.4)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  AppColors.brandRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.brandRed,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value != null
                      ? DateFormat(
                              'EEE, MMM dd yyyy • hh:mm a')
                          .format(value)
                      : 'Tap to set',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: value != null
                        ? AppColors.darkText
                        : AppColors.mutedText,
                    fontWeight: value != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close,
                  size: 16, color: AppColors.mutedText),
            )
          else
            Icon(
              value != null
                  ? Icons.edit_outlined
                  : Icons.add_circle_outline,
              color: AppColors.brandRed,
              size: 18,
            ),
        ]),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: AppColors.brandRed, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedText)),
        value: value,
        activeThumbColor: AppColors.brandRed,
        onChanged: onChanged,
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
            color: AppColors.brandRed,
            fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(
            color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                color: AppColors.mutedText, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.brandRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Colors.red, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.softWhite,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}