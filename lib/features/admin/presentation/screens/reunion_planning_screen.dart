import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class ReunionAndEventsScreen extends StatefulWidget {
  const ReunionAndEventsScreen({super.key});

  @override
  State<ReunionAndEventsScreen> createState() =>
      _ReunionAndEventsScreenState();
}

class _ReunionAndEventsScreenState
    extends State<ReunionAndEventsScreen> {
  String? _statusFilter;
  String? _typeFilter;
  String _searchQuery = '';
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';

  final _typeOptions = [
    'batch-reunion',
    'grand-homecoming',
    'decade-reunion',
    'class-reunion',
    'other',
  ];

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
        .collection('events');

    if (_statusFilter != null) {
      query =
          query.where('status', isEqualTo: _statusFilter);
    }
    if (_typeFilter != null) {
      query =
          query.where('type', isEqualTo: _typeFilter);
    } else if (_statusFilter == null) {
      // Default: show only reunion types
      query = query.where('type', whereIn: [
        'batch-reunion',
        'grand-homecoming',
        'decade-reunion',
        'class-reunion',
      ]);
    }

    return query
        .orderBy('startDate', descending: true)
        .snapshots();
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

  Future<void> _publishEvent(String id) async {
    final confirm = await _confirmDialog(
      title: 'Publish Event',
      message:
          'This event will become visible to all alumni.',
      confirmText: 'Publish',
      confirmColor: Colors.green,
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(id)
          .update({
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Event published!', isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _updateStatus(
      String id, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(id)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Status updated to $status',
          isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(
      String id, String title) async {
    final confirm = await _confirmDialog(
      title: 'Delete Event',
      message:
          'Delete "$title"? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppColors.brandRed,
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(id)
          .delete();
      _showSnackBar('Event deleted', isError: false);
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

  void _showEventForm({
    String? eventId,
    Map<String, dynamic>? initialData,
  }) {
    final isEdit = eventId != null;
    final titleCtrl = TextEditingController(
        text: initialData?['title']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text: initialData?['description']?.toString() ??
            '');
    final locationCtrl = TextEditingController(
        text:
            initialData?['location']?.toString() ?? '');
    final batchCtrl = TextEditingController(
        text:
            initialData?['batchYear']?.toString() ?? '');
    final capacityCtrl = TextEditingController(
        text: initialData?['capacity']?.toString() ?? '');
    String type =
        initialData?['type']?.toString() ??
            'batch-reunion';
    String status =
        initialData?['status']?.toString() ?? 'draft';
    DateTime? startDate =
        (initialData?['startDate'] as Timestamp?)
            ?.toDate();
    DateTime? endDate =
        (initialData?['endDate'] as Timestamp?)?.toDate();
    bool isVirtual =
        initialData?['isVirtual'] as bool? ?? false;
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
                      Text(
                        isEdit
                            ? 'Edit Event'
                            : 'New Reunion / Event',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.w600),
                      ),
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
                                if (startDate == null) {
                                  _showSnackBar(
                                      'Start date is required',
                                      isError: true);
                                  return;
                                }
                                if (endDate != null &&
                                    endDate!.isBefore(
                                        startDate!)) {
                                  _showSnackBar(
                                      'End date cannot be before start',
                                      isError: true);
                                  return;
                                }

                                setSheet(() =>
                                    isSubmitting = true);

                                final data =
                                    <String, dynamic>{
                                  'title': t,
                                  'description':
                                      descCtrl.text.trim(),
                                  'location':
                                      locationCtrl.text
                                          .trim(),
                                  'type': type,
                                  'status': status,
                                  'isVirtual': isVirtual,
                                  'startDate':
                                      Timestamp.fromDate(
                                          startDate!),
                                  'endDate': endDate != null
                                      ? Timestamp.fromDate(
                                          endDate!)
                                      : null,
                                  'updatedAt': FieldValue
                                      .serverTimestamp(),
                                };

                                if (batchCtrl.text
                                    .trim()
                                    .isNotEmpty) {
                                  data['batchYear'] =
                                      batchCtrl.text.trim();
                                }
                                if (capacityCtrl.text
                                    .trim()
                                    .isNotEmpty) {
                                  data['capacity'] =
                                      int.tryParse(
                                              capacityCtrl
                                                  .text
                                                  .trim()) ??
                                          0;
                                }

                                if (!isEdit) {
                                  data['createdAt'] =
                                      FieldValue
                                          .serverTimestamp();
                                  data['createdBy'] =
                                      FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid;
                                  data['registeredCount'] =
                                      0;
                                }

                                try {
                                  if (isEdit) {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'events')
                                        .doc(eventId)
                                        .update(data);
                                  } else {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'events')
                                        .add(data);
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _showSnackBar(
                                      isEdit
                                          ? 'Event updated!'
                                          : 'Event created!',
                                      isError: false,
                                    );
                                  }
                                } catch (e) {
                                  setSheet(() =>
                                      isSubmitting = false);
                                  _showSnackBar('Error: $e',
                                      isError: true);
                                }
                              },
                        child: Text(
                          isSubmitting
                              ? 'Saving...'
                              : isEdit
                                  ? 'Save'
                                  : 'Create',
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
                      _field(titleCtrl, 'Event Title',
                          'e.g. Grand Alumni Homecoming 2026',
                          validator: true),
                      const SizedBox(height: 16),
                      _field(descCtrl, 'Description',
                          'Describe the event...',
                          maxLines: 4),
                      const SizedBox(height: 16),
                      _field(locationCtrl, 'Location',
                          'Venue, address or online link',
                          prefixIcon:
                              Icons.location_on_outlined),
                      const SizedBox(height: 16),
                      _field(batchCtrl, 'Batch / Year',
                          'e.g. Batch 2015 (optional)',
                          prefixIcon:
                              Icons.school_outlined),
                      const SizedBox(height: 16),
                      _field(
                          capacityCtrl,
                          'Capacity',
                          'Max attendees (optional)',
                          prefixIcon: Icons.people_outline,
                          keyboardType:
                              TextInputType.number),
                      const SizedBox(height: 16),

                      // ─── Type dropdown ───
                      _dropdownTile(
                        label: 'Event Type',
                        value: type,
                        items: _typeOptions,
                        onChanged: (v) =>
                            setSheet(() => type = v!),
                      ),
                      const SizedBox(height: 10),

                      // ─── Status dropdown ───
                      _dropdownTile(
                        label: 'Status',
                        value: status,
                        items: [
                          'draft',
                          'published',
                          'ongoing',
                          'completed',
                          'cancelled'
                        ],
                        onChanged: (v) =>
                            setSheet(() => status = v!),
                      ),
                      const SizedBox(height: 16),

                      // ─── Virtual toggle ───
                      _toggleTile(
                        icon: Icons.videocam_outlined,
                        title: 'Virtual Event',
                        subtitle:
                            'This event will be held online',
                        value: isVirtual,
                        onChanged: (v) => setSheet(
                            () => isVirtual = v),
                      ),
                      const SizedBox(height: 16),

                      // ─── Start date ───
                      _dateTile(
                        label: 'Start Date & Time *',
                        value: startDate,
                        onTap: () async {
                          final p = await _pickDateTime(
                              startDate);
                          if (p != null) {
                            setSheet(() => startDate = p);
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
                          final p = await _pickDateTime(
                              endDate);
                          if (p != null) {
                            setSheet(() => endDate = p);
                          }
                        },
                        onClear: endDate != null
                            ? () => setSheet(
                                () => endDate = null)
                            : null,
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

  Future<DateTime?> _pickDateTime(
      DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
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
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.brandRed),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day,
        time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 1100;

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
                              route: '/reunions_events',
                              isActive: true),
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
                          Text('Reunions & Events',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      fontSize: 32,
                                      fontWeight:
                                          FontWeight.w400,
                                      color:
                                          AppColors.darkText)),
                          Text(
                              'Manage alumni gatherings, batch reunions and homecomings.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showEventForm(),
                        icon: const Icon(Icons.add,
                            size: 18),
                        label: Text(
                            'New Reunion / Event',
                            style: GoogleFonts.inter(
                                fontWeight:
                                    FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
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
                      style: GoogleFonts.inter(
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Search events, locations...',
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

                    // ─── Status chips ───
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        Text('Status: ',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.mutedText,
                                fontWeight:
                                    FontWeight.w600)),
                        const SizedBox(width: 6),
                        _chip('All', null,
                            _statusFilter == null),
                        const SizedBox(width: 6),
                        _chip('Draft', 'draft',
                            _statusFilter == 'draft',
                            isStatus: true),
                        const SizedBox(width: 6),
                        _chip('Published', 'published',
                            _statusFilter == 'published',
                            isStatus: true),
                        const SizedBox(width: 6),
                        _chip('Ongoing', 'ongoing',
                            _statusFilter == 'ongoing',
                            isStatus: true),
                        const SizedBox(width: 6),
                        _chip('Completed', 'completed',
                            _statusFilter == 'completed',
                            isStatus: true),
                        const SizedBox(width: 6),
                        _chip('Cancelled', 'cancelled',
                            _statusFilter == 'cancelled',
                            isStatus: true),
                      ]),
                    ),
                    const SizedBox(height: 6),

                    // ─── Type chips ───
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        Text('Type: ',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.mutedText,
                                fontWeight:
                                    FontWeight.w600)),
                        const SizedBox(width: 6),
                        _chip('All', null,
                            _typeFilter == null,
                            isType: true),
                        const SizedBox(width: 6),
                        _chip('Batch Reunion',
                            'batch-reunion',
                            _typeFilter == 'batch-reunion',
                            isType: true),
                        const SizedBox(width: 6),
                        _chip('Grand Homecoming',
                            'grand-homecoming',
                            _typeFilter ==
                                'grand-homecoming',
                            isType: true),
                        const SizedBox(width: 6),
                        _chip('Decade Reunion',
                            'decade-reunion',
                            _typeFilter ==
                                'decade-reunion',
                            isType: true),
                        const SizedBox(width: 6),
                        _chip('Class Reunion',
                            'class-reunion',
                            _typeFilter == 'class-reunion',
                            isType: true),
                        const SizedBox(width: 6),
                        _chip('Other', 'other',
                            _typeFilter == 'other',
                            isType: true),
                      ]),
                    ),
                  ]),
                ),

                // ─── Events list ───
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
                          final location =
                              data['location']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';
                          final batch = data['batchYear']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          return title.contains(
                                  _searchQuery) ||
                              location.contains(
                                  _searchQuery) ||
                              batch
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
                                      .celebration_outlined,
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
                                  'Create one or adjust filters',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors
                                          .mutedText)),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(32),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isNarrow
                              ? 1
                              : (screenWidth < 1600
                                  ? 2
                                  : 3),
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data()
                              as Map<String, dynamic>;
                          return _eventCard(doc.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ─── Right sidebar ───
          if (!isNarrow)
            Container(
              width: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    left: BorderSide(
                        color: AppColors.borderSubtle,
                        width: 0.5)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Career Pulse',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText)),
                    const SizedBox(height: 16),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('stats')
                          .doc('career_pulse')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData ||
                            !snapshot.data!.exists) {
                          return Text(
                              'Career stats unavailable',
                              style: GoogleFonts.inter(
                                  color:
                                      AppColors.mutedText,
                                  fontSize: 13));
                        }
                        final d = snapshot.data!.data()
                            as Map<String, dynamic>;
                        return Container(
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.brandRed
                                .withOpacity(0.04),
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
                              Text(
                                '${d['percentage'] ?? '48'}%',
                                style: GoogleFonts
                                    .cormorantGaramond(
                                        fontSize: 48,
                                        fontWeight:
                                            FontWeight.w300,
                                        color: AppColors
                                            .brandRed),
                              ),
                              Text(
                                d['title'] ??
                                    'Alumni moving to senior roles',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        AppColors.mutedText),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                d['description'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color:
                                        AppColors.mutedText,
                                    height: 1.5),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    Text('Active Chapters',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText)),
                    const SizedBox(height: 16),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chapters')
                          .orderBy('memberCount',
                              descending: true)
                          .limit(6)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return Text(
                              'No chapters found',
                              style: GoogleFonts.inter(
                                  color:
                                      AppColors.mutedText,
                                  fontSize: 13));
                        }
                        return Column(
                          children: snapshot.data!.docs
                              .map((doc) {
                            final d = doc.data()
                                as Map<String, dynamic>;
                            final city = d['city']
                                    ?.toString() ??
                                d['name']?.toString() ??
                                '—';
                            final count =
                                d['memberCount'] ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 8),
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.softWhite,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                    color: AppColors
                                        .borderSubtle),
                              ),
                              child: Row(children: [
                                const Icon(
                                    Icons.location_on,
                                    color: AppColors.brandRed,
                                    size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(city,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight
                                                  .w600)),
                                ),
                                Text('$count',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: AppColors
                                            .brandRed)),
                              ]),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventCard(String id, Map<String, dynamic> data) {
    final title =
        data['title']?.toString() ?? 'Untitled';
    final description =
        data['description']?.toString() ?? '';
    final location =
        data['location']?.toString() ?? 'TBD';
    final type =
        data['type']?.toString() ?? 'other';
    final status =
        data['status']?.toString() ?? 'draft';
    final batchYear =
        data['batchYear']?.toString() ?? '';
    final capacity = data['capacity'];
    final isVirtual =
        data['isVirtual'] as bool? ?? false;
    final startTs =
        data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final startDt = startTs?.toDate();
    final endDt = endTs?.toDate();
    final isReunion = type.contains('reunion') ||
        type.contains('homecoming');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'published'
              ? Colors.blue.withOpacity(0.3)
              : status == 'ongoing'
                  ? Colors.green.withOpacity(0.3)
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
          // ─── Top row ───
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isReunion
                      ? AppColors.brandRed
                          .withOpacity(0.08)
                      : Colors.blue.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  isReunion
                      ? Icons.celebration_outlined
                      : Icons.event_outlined,
                  color: isReunion
                      ? AppColors.brandRed
                      : Colors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (batchYear.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(batchYear,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.brandRed,
                              fontWeight:
                                  FontWeight.w600)),
                    ],
                  ],
                ),
              ),

              // ─── Status badge with dropdown ───
              PopupMenuButton<String>(
                tooltip: 'Change status',
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                child: _statusBadge(status),
                onSelected: (v) =>
                    _updateStatus(id, v),
                itemBuilder: (_) => [
                  'draft',
                  'published',
                  'ongoing',
                  'completed',
                  'cancelled'
                ]
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _statusColorStr(s),
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
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (description.isNotEmpty)
            Text(description,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

          const SizedBox(height: 10),

          // ─── Info chips ───
          Wrap(spacing: 4, runSpacing: 4, children: [
            _infoChip(Icons.location_on_outlined,
                location),
            if (startDt != null)
              _infoChip(Icons.calendar_today_outlined,
                  DateFormat('MMM dd, yyyy')
                      .format(startDt)),
            if (startDt != null)
              _infoChip(
                  Icons.access_time_outlined,
                  endDt != null
                      ? '${DateFormat('hh:mm a').format(startDt)} – ${DateFormat('hh:mm a').format(endDt)}'
                      : DateFormat('hh:mm a')
                          .format(startDt)),
            if (capacity != null)
              _infoChip(Icons.people_outline,
                  '$capacity max'),
            if (isVirtual)
              _infoChip(
                  Icons.videocam_outlined, 'Virtual',
                  color: Colors.blue),
            _infoChip(Icons.category_outlined,
                type.replaceAll('-', ' ')),
          ]),

          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 4),

          // ─── Actions ───
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'draft')
                _actionBtn(
                  icon: Icons.publish_outlined,
                  label: 'Publish',
                  color: Colors.green,
                  onTap: () => _publishEvent(id),
                ),
              if (status == 'draft')
                const SizedBox(width: 6),
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: AppColors.mutedText,
                onTap: () => _showEventForm(
                    eventId: id, initialData: data),
              ),
              const SizedBox(width: 6),
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

  Widget _statusBadge(String status) {
    final color = _statusColorStr(status);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(status.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5)),
        const SizedBox(width: 2),
        Icon(Icons.arrow_drop_down, size: 14, color: color),
      ]),
    );
  }

  Color _statusColorStr(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.blue;
      case 'ongoing':
        return Colors.green;
      case 'completed':
        return AppColors.mutedText;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _infoChip(IconData icon, String label,
      {Color? color}) {
    final c = color ?? AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: c)),
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
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }

  Widget _chip(String label, String? value,
      bool isSelected,
      {bool isStatus = false, bool isType = false}) {
    return GestureDetector(
      onTap: () => setState(() {
        if (isStatus) _statusFilter = value;
        if (isType) _typeFilter = value;
        if (!isStatus && !isType) {
          _statusFilter = null;
          _typeFilter = null;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandRed
              : AppColors.softWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? AppColors.brandRed
                  : AppColors.borderSubtle),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppColors.mutedText)),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label,
      String hint, {
      int maxLines = 1,
      bool validator = false,
      IconData? prefixIcon,
      TextInputType? keyboardType,
    }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
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

  Widget _dropdownTile({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
              color: AppColors.brandRed,
              fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
        items: items
            .map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(v.replaceAll('-', ' '),
                      style: GoogleFonts.inter(
                          fontSize: 14)),
                ))
            .toList(),
        onChanged: onChanged,
        style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.darkText),
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
        activeColor: AppColors.brandRed,
        onChanged: onChanged,
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
              color: AppColors.brandRed.withOpacity(0.08),
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