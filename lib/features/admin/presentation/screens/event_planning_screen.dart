import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ── Design tokens (matching job board) ──────────────────────────────────────
const _kBg       = Color(0xFFF8F9FB);
const _kBorder   = Color(0xFFEEF0F4);
const _kCardBg   = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────
// EVENT STATUS HELPER
// ─────────────────────────────────────────────────────────────────────────────

class _EventStatus {
  static const draft     = 'DRAFT';
  static const published = 'PUBLISHED';
  static const ongoing   = 'ONGOING';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';

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
      default:         return const Color(0xFF9CA3AF);
    }
  }

  static IconData icon(String status) {
    switch (status.toUpperCase()) {
      case published:  return Icons.schedule_outlined;
      case ongoing:    return Icons.play_circle_outline;
      case completed:  return Icons.check_circle_outline;
      case cancelled:  return Icons.cancel_outlined;
      default:         return Icons.edit_outlined;
    }
  }

  static String? timeLabel(DateTime? startDate, DateTime? endDate) {
    if (startDate == null) return null;
    final now = DateTime.now();
    if (endDate != null && now.isAfter(endDate)) {
      final diff = now.difference(endDate);
      return diff.inDays == 0 ? 'Ended today' : 'Ended ${diff.inDays}d ago';
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
  String  _adminName   = 'Admin';
  String  _searchQuery = '';
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _userRole  = d['role']?.toString()     ?? 'alumni';
          _adminName = d['name']?.toString()     ??
                       d['fullName']?.toString() ??
                       user.displayName          ?? 'Admin';
        });
      }
    } catch (e) { debugPrint('Role load error: $e'); }
  }

  bool get _canManage => _userRole == 'admin' || _userRole == 'moderator';
  bool get _hasAccess => _canManage;

  // ══════════════════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════════════════

  Future<void> _showAlert({
    required String title, required String message,
    IconData icon = Icons.info_outline, Color color = AppColors.brandRed,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 380,
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText, height: 1.5)),
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
                child: Text('Got it', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<bool?> _showConfirm({
    required String title, required String message,
    required String confirmLabel, Color confirmColor = Colors.red,
    IconData icon = Icons.warning_amber_outlined,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 380,
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(icon, color: confirmColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedText,
                    side: const BorderSide(color: _kBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor, foregroundColor: Colors.white,
                    elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(confirmLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: GoogleFonts.inter(color: Colors.white))),
        ]),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: Duration(seconds: isError ? 4 : 2),
      ));
  }

  // ══════════════════════════════════════════════════════
  //  DATE / TIME PICKER
  // ══════════════════════════════════════════════════════

  Future<DateTime?> _pickDateTime(BuildContext ctx, DateTime? initial) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2035),
      builder: (context, child) => _redTheme(child!),
    );
    if (date == null || !ctx.mounted) return null;
    final time = await showTimePicker(
      context: ctx,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.now(),
      builder: (context, child) => _redTheme(child!),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _redTheme(Widget child) => Theme(
    data: ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(primary: AppColors.brandRed),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.brandRed)),
    ),
    child: child,
  );

  // ══════════════════════════════════════════════════════
  //  FIRESTORE ACTIONS
  // ══════════════════════════════════════════════════════

  Future<void> _deleteEvent(String id, String title) async {
    final ok = await _showConfirm(
      title: 'Delete Event', message: 'Permanently delete "$title"? This cannot be undone.',
      confirmLabel: 'Delete', confirmColor: Colors.red, icon: Icons.delete_outline,
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('events').doc(id).delete();
      _snack('Event deleted', isError: false);
    } catch (_) {
      await _showAlert(
        title: 'Delete Failed',
        message: 'Could not delete this event. Check your connection and try again.',
        icon: Icons.cloud_off_outlined, color: Colors.red,
      );
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(id).update({
        'status': status, 'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Status updated to $status', isError: false);
    } catch (e) { _snack('Failed to update status: $e', isError: true); }
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

    DateTime? startDate   = (data?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate     = (data?['endDate']   as Timestamp?)?.toDate();
    String    status      = data?['status']?.toString()     ?? 'DRAFT';
    bool      isImportant = data?['isImportant'] as bool?   ?? false;
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
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.brandRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_outlined, color: AppColors.brandRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isEdit ? 'Edit Event' : 'Create Event',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.darkText)),
                    Text(isEdit ? 'Update event details' : 'Fields marked * are required',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
                  ])),
                  if (!isSubmitting)
                    Material(
                      color: _kBg, borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, border: Border.all(color: _kBorder)),
                          child: const Icon(Icons.close, size: 16, color: AppColors.mutedText),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  // Save button
                  GestureDetector(
                    onTap: isSubmitting ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      if (startDate == null) {
                        await _showAlert(title: 'Start Date Required',
                            message: 'Please set a start date and time before saving.',
                            icon: Icons.calendar_today_outlined, color: Colors.orange);
                        return;
                      }
                      if (!isEdit && startDate!.isBefore(
                          DateTime.now().subtract(const Duration(minutes: 5)))) {
                        await _showAlert(title: 'Invalid Date',
                            message: 'Start date cannot be in the past.',
                            icon: Icons.history, color: Colors.orange);
                        return;
                      }
                      if (endDate != null && endDate!.isBefore(startDate!)) {
                        await _showAlert(title: 'Invalid End Date',
                            message: 'End date must be after the start date.',
                            icon: Icons.event_busy_outlined, color: Colors.orange);
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
                          await FirebaseFirestore.instance.collection('events').doc(eventId).update(payload);
                        } else {
                          payload['createdAt']    = FieldValue.serverTimestamp();
                          payload['createdBy']    = FirebaseAuth.instance.currentUser?.uid ?? '';
                          payload['createdByRole']= _userRole ?? '';
                          payload['likesCount']   = 0;
                          await FirebaseFirestore.instance.collection('events').add(payload);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack(isEdit ? 'Event updated!' : 'Event created!', isError: false);
                        }
                      } catch (e) {
                        setSheet(() => isSubmitting = false);
                        if (ctx.mounted) {
                          await _showAlert(title: 'Save Failed',
                              message: 'Something went wrong. Please check your connection.',
                              icon: Icons.cloud_off_outlined, color: Colors.red);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSubmitting ? AppColors.brandRed.withOpacity(0.5) : AppColors.brandRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save Changes' : 'Create Event',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _kBorder),

              // Form
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Status info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.withOpacity(0.2)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.auto_awesome_outlined, size: 14, color: Colors.purple.shade400),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            'Status auto-updates to Ongoing / Completed based on dates. Draft and Cancelled are always manually set.',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.purple.shade600, height: 1.5),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      _FormSectionLabel('Event Details'),
                      const SizedBox(height: 12),

                      _formField(controller: titleCtrl, label: 'Event Title *',
                          hint: 'e.g. Grand Alumni Homecoming 2026',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Title is required';
                            if (v.trim().length < 5) return 'At least 5 characters';
                            if (v.trim().length > 150) return 'Max 150 characters';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      _formField(controller: descCtrl, label: 'Description *',
                          hint: 'What is this event about?', maxLines: 4,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Description is required';
                            if (v.trim().length < 10) return 'At least 10 characters';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      _formField(controller: locationCtrl, label: 'Location *',
                          hint: 'e.g. College Gymnasium, Cebu City',
                          prefixIcon: Icons.location_on_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Location is required';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      _formField(controller: capacityCtrl, label: 'Capacity *',
                          hint: 'Max attendees (0 = unlimited)',
                          prefixIcon: Icons.people_outline,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required (use 0 for unlimited)';
                            final n = int.tryParse(v.trim());
                            if (n == null) return 'Must be a whole number';
                            if (n < 0)     return 'Cannot be negative';
                            return null;
                          }),

                      const SizedBox(height: 24),
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
                        label: 'End Date & Time (optional)',
                        value: endDate,
                        onTap: () async {
                          final p = await _pickDateTime(ctx, endDate);
                          if (p != null) setSheet(() => endDate = p);
                        },
                        onClear: endDate != null ? () => setSheet(() => endDate = null) : null,
                      ),

                      const SizedBox(height: 24),
                      _FormSectionLabel('Settings'),
                      const SizedBox(height: 12),

                      // Status dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: InputDecoration(
                            labelText: 'Manual Status Override',
                            labelStyle: GoogleFonts.inter(
                                color: AppColors.brandRed, fontWeight: FontWeight.w500),
                            border: InputBorder.none,
                          ),
                          items: ['DRAFT', 'PUBLISHED', 'ONGOING', 'COMPLETED', 'CANCELLED']
                              .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Row(children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                          color: _EventStatus.color(v), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(v, style: GoogleFonts.inter(fontSize: 14)),
                                  ])))
                              .toList(),
                          onChanged: (v) { if (v != null) setSheet(() => status = v); },
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Important toggle
                      Container(
                        decoration: BoxDecoration(
                          color: isImportant ? Colors.amber.withOpacity(0.06) : _kBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isImportant ? Colors.amber.withOpacity(0.35) : _kBorder),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brandRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.star_outline,
                                color: AppColors.brandRed, size: 20),
                          ),
                          title: Text('Mark as Important',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                          subtitle: Text('Highlight this event for all alumni',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
                          value: isImportant,
                          activeColor: AppColors.brandRed,
                          onChanged: (v) => setSheet(() => isImportant = v),
                        ),
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
    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
              decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 40, color: AppColors.brandRed)),
          const SizedBox(height: 24),
          Text('Access Denied',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.darkText)),
          const SizedBox(height: 12),
          Text(
            'Your role (${_userRole?.toUpperCase() ?? 'UNKNOWN'}) does not have\npermission to access this page.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText, height: 1.6),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/admin_dashboard', (r) => false),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back to Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildSidebar(),
        Expanded(
          child: Column(children: [
            _buildTopBar(),
            _buildSearchFilterBar(),
            Expanded(child: _buildEventList()),
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
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALUMNI',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, letterSpacing: 6,
                    color: AppColors.brandRed, fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('ARCHIVE PORTAL',
                style: GoogleFonts.inter(fontSize: 9, letterSpacing: 2,
                    color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(height: 1, color: _kBorder),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _navSection('NETWORK', [
                _navItem(Icons.dashboard_outlined, 'Overview', route: '/admin_dashboard'),
              ]),
              const SizedBox(height: 20),
              _navSection('ENGAGEMENT', [
                _navItem(Icons.emoji_events_outlined, 'Career Milestones', route: '/career_milestones'),
              ]),
              const SizedBox(height: 20),
              _navSection('ADMIN FEATURES', [
                _navItem(Icons.verified_user_outlined, 'User Verification',
                    route: '/user_verification_moderation'),
                _navItem(Icons.event_outlined, 'Event Planning',
                    route: '/event_planning', isActive: true),
                _navItem(Icons.work_outline, 'Job Board Management',
                    route: '/job_board_management'),
                _navItem(Icons.bar_chart_outlined, 'Growth Metrics', route: '/growth_metrics'),
                _navItem(Icons.campaign_outlined, 'Announcements',
                    route: '/announcement_management'),
              ]),
            ]),
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brandRed.withOpacity(0.1),
              child: Text(
                _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                style: GoogleFonts.cormorantGaramond(
                    color: AppColors.brandRed, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_adminName,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text((_userRole ?? 'admin').toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, color: AppColors.mutedText)),
            ])),
            IconButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              },
              icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.mutedText),
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
            style: GoogleFonts.inter(fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700,
                color: AppColors.mutedText.withOpacity(0.6))),
      ),
      ...items,
    ]);
  }

  Widget _navItem(IconData icon, String label, {String? route, bool isActive = false}) {
    return Material(
      color: isActive ? AppColors.brandRed.withOpacity(0.07) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: route != null && !isActive ? () => Navigator.pushNamed(context, route) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(icon, size: 17,
                color: isActive ? AppColors.brandRed : AppColors.mutedText),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isActive ? AppColors.brandRed : AppColors.darkText,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
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
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Event Planning',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.darkText)),
          const SizedBox(height: 2),
          Text('Coordinate and track all alumni gatherings.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText)),
        ]),
        const Spacer(),
        if (_canManage)
          ElevatedButton.icon(
            onPressed: () => _openEventForm(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('New Event',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed, foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ]),
    );
  }

  // ── Search + filter bar ──────────────────────────────────────────────────

  static const _filters = <String?, String>{
    null: 'All', 'DRAFT': 'Draft', 'PUBLISHED': 'Published',
    'ONGOING': 'Ongoing', 'COMPLETED': 'Completed', 'CANCELLED': 'Cancelled',
  };

  Widget _buildSearchFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(children: [
        const Divider(height: 1, color: _kBorder),
        const SizedBox(height: 14),
        TextField(
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
          decoration: InputDecoration(
            hintText: 'Search events by title, location, or description…',
            hintStyle: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedText, size: 20),
            filled: true, fillColor: _kBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.entries.map((e) {
              final isSelected = _statusFilter == e.key;
              final color = e.key != null ? _EventStatus.color(e.key!) : AppColors.mutedText;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected ? color : _kBorder,
                          width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (e.key != null) ...[
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: isSelected ? color : AppColors.mutedText,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(e.value,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  // ── Event list ────────────────────────────────────────────────────────────

  Widget _buildEventList() {
    return StreamBuilder<QuerySnapshot>(
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
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Error loading events',
                style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${snap.error}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText)),
          ]));
        }

        var docs = snap.data?.docs ?? [];

        if (_statusFilter != null) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final resolved = _EventStatus.resolve(
              stored:    data['status']?.toString()                 ?? 'DRAFT',
              startDate: (data['startDate'] as Timestamp?)?.toDate(),
              endDate:   (data['endDate']   as Timestamp?)?.toDate(),
            );
            return resolved == _statusFilter;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['title']?.toString().toLowerCase()       ?? '').contains(_searchQuery) ||
                   (data['location']?.toString().toLowerCase()    ?? '').contains(_searchQuery) ||
                   (data['description']?.toString().toLowerCase() ?? '').contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: AppColors.borderSubtle.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.event_busy_outlined, size: 38, color: AppColors.mutedText)),
              const SizedBox(height: 20),
              Text(_statusFilter != null || _searchQuery.isNotEmpty
                  ? 'No matching events' : 'No events yet',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 26, fontWeight: FontWeight.w400, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text(
                _statusFilter != null || _searchQuery.isNotEmpty
                    ? 'Try adjusting your search or filters.'
                    : 'Create your first event to get started.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
              ),
              if (_canManage && _statusFilter == null && _searchQuery.isEmpty) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _openEventForm(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Create Event',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandRed, foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ]),
          ));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _EventCard(
              id:            doc.id,
              data:          data,
              canManage:     _canManage,
              onEdit:        () => _openEventForm(eventId: doc.id, data: data),
              onDelete:      () => _deleteEvent(doc.id, data['title']?.toString() ?? ''),
              onStatusChange: (s) => _updateStatus(doc.id, s),
              onSnack:       _snack,
            );
          },
        );
      },
    );
  }

  // ── Form helpers ─────────────────────────────────────────────────────────

  Widget _formField({
    required TextEditingController controller,
    required String label, required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller, maxLines: maxLines, keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        labelStyle: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.w500),
        hintStyle:  GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.mutedText, size: 18) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        filled: true, fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EVENT CARD
// ═════════════════════════════════════════════════════════════════════════════

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
    final storedStatus = data['status']?.toString()       ?? 'DRAFT';
    final startDate    = (data['startDate'] as Timestamp?)?.toDate();
    final endDate      = (data['endDate']   as Timestamp?)?.toDate();
    final title        = data['title']?.toString()        ?? 'Untitled Event';
    final description  = data['description']?.toString()  ?? '';
    final location     = data['location']?.toString()     ?? 'TBD';
    final capacity     = data['capacity']?.toString()     ?? '0';
    final isImportant  = data['isImportant'] as bool?     ?? false;
    final currentUid   = FirebaseAuth.instance.currentUser?.uid ?? '';

    final status      = _EventStatus.resolve(stored: storedStatus, startDate: startDate, endDate: endDate);
    final statusColor = _EventStatus.color(status);
    final timeLabel   = _EventStatus.timeLabel(startDate, endDate);
    final isOngoing   = status == 'ONGOING';

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'DRAFT' ? _kBorder : statusColor.withOpacity(0.25),
          width: isOngoing ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isOngoing ? 0.06 : 0.03),
          blurRadius: isOngoing ? 14 : 8,
          offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status accent bar (top border line — same as job board approved header)
        if (isOngoing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(children: [
              Icon(Icons.play_circle_outline, size: 13, color: statusColor),
              const SizedBox(width: 6),
              Text('HAPPENING NOW',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: statusColor, letterSpacing: 1)),
              const Spacer(),
              if (startDate != null)
                Text('Started ${DateFormat('MMM dd, yyyy').format(startDate)}',
                    style: GoogleFonts.inter(fontSize: 10, color: statusColor.withOpacity(0.7))),
            ]),
          )
        else
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Title row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_EventStatus.icon(status), color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.darkText, height: 1.25))),
                  if (isImportant) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withOpacity(0.35)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded, size: 10, color: Colors.amber.shade700),
                        const SizedBox(width: 3),
                        Text('Important',
                            style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: Colors.amber.shade700, letterSpacing: 0.3)),
                      ]),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.mutedText),
                  const SizedBox(width: 3),
                  Expanded(child: Text(location,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              const SizedBox(width: 10),
              // Status badge / dropdown
              if (canManage)
                _StatusDropdown(status: status, color: statusColor, onSelect: onStatusChange)
              else
                _StatusBadge(status: status, color: statusColor),
            ]),

            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText, height: 1.55)),
            ],

            const SizedBox(height: 14),

            // Info chips
            Wrap(spacing: 6, runSpacing: 8, children: [
              if (startDate != null)
                _InfoChip(icon: Icons.calendar_today_outlined,
                    label: DateFormat('EEE, MMM d, yyyy').format(startDate)),
              if (startDate != null)
                _InfoChip(
                  icon: Icons.access_time_outlined,
                  label: endDate != null
                      ? '${DateFormat('h:mm a').format(startDate)} – ${DateFormat('h:mm a').format(endDate)}'
                      : DateFormat('h:mm a').format(startDate),
                ),
              _InfoChip(
                icon: Icons.people_outline,
                label: int.tryParse(capacity) == 0 ? 'Unlimited' : '$capacity capacity',
              ),
              if (timeLabel != null)
                _InfoChip(
                  icon: isOngoing ? Icons.radio_button_checked : Icons.schedule_outlined,
                  label: timeLabel,
                  color: isOngoing ? const Color(0xFF10B981) : AppColors.brandRed,
                  highlighted: true,
                ),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 12),

            // RSVP
            if (status != 'CANCELLED' && status != 'COMPLETED' && currentUid.isNotEmpty)
              _RsvpRow(eventId: id, currentUid: currentUid, onSnack: onSnack),

            if (status == 'CANCELLED')
              _StatusNote(icon: Icons.block, color: Colors.red, label: 'This event has been cancelled.'),

            if (status == 'COMPLETED')
              _StatusNote(icon: Icons.check_circle_outline, color: const Color(0xFF10B981),
                  label: 'This event has ended.'),

            // Admin actions
            if (canManage) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _IconActionBtn(
                  icon: Icons.edit_outlined, color: AppColors.mutedText,
                  tooltip: 'Edit event', onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _IconActionBtn(
                  icon: Icons.delete_outline, color: const Color(0xFFDC2626),
                  tooltip: 'Delete event', onTap: onDelete,
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

  const _RsvpRow({required this.eventId, required this.currentUid, required this.onSnack});

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
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
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
                      'uid': currentUid, 'status': opt.value,
                      'rsvpAt': FieldValue.serverTimestamp(),
                    });
                    onSnack('RSVP: ${opt.label}', isError: false);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? opt.color.withOpacity(0.10) : _kBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isSelected ? opt.color.withOpacity(0.4) : _kBorder),
                  ),
                  child: Row(children: [
                    Icon(opt.icon, size: 12,
                        color: isSelected ? opt.color : AppColors.mutedText),
                    const SizedBox(width: 4),
                    Text(opt.label,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
            builder: (_, s) {
              final count = s.data?.docs.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Row(children: [
                Container(width: 1, height: 14, color: _kBorder),
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

// ═════════════════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color  color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status, style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
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
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(status, style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 14, color: color),
        ]),
      ),
      onSelected: onSelect,
      itemBuilder: (_) => ['DRAFT', 'PUBLISHED', 'ONGOING', 'COMPLETED', 'CANCELLED']
          .map((s) => PopupMenuItem(
            value: s,
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _EventStatus.color(s), shape: BoxShape.circle)),
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
  const _InfoChip({required this.icon, required this.label,
      this.color, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? c.withOpacity(0.09) : _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlighted ? c.withOpacity(0.3) : _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;
  const _IconActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});

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
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _FormSectionLabel extends StatelessWidget {
  final String text;
  const _FormSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14, color: AppColors.brandRed,
          margin: const EdgeInsets.only(right: 10)),
      Text(text, style: GoogleFonts.inter(
          fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w800,
          color: AppColors.brandRed)),
    ]);
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
    return Material(
      color: value != null ? AppColors.brandRed.withOpacity(0.03) : _kBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: value != null ? AppColors.brandRed.withOpacity(0.4) : _kBorder),
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
              Text(label, style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.w500)),
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: AppColors.mutedText),
                  ),
                ),
              )
            else
              Icon(value != null ? Icons.edit_outlined : Icons.add_circle_outline,
                  color: AppColors.brandRed, size: 18),
          ]),
        ),
      ),
    );
  }
}