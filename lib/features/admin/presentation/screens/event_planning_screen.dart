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
  String _searchQuery = '';
  String? _statusFilter; // null = all

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
          _userRole =
              doc.data()?['role']?.toString() ?? 'alumni';
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

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ─── Create / Edit event sheet ───
  void _showEventForm({
    String? eventId,
    Map<String, dynamic>? initialData,
  }) {
    final isEdit = eventId != null;
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(
        text: initialData?['title'] ?? '');
    final descCtrl = TextEditingController(
        text: initialData?['description'] ?? '');
    final locationCtrl = TextEditingController(
        text: initialData?['location'] ?? '');
    final capacityCtrl = TextEditingController(
        text:
            initialData?['capacity']?.toString() ?? '');

    DateTime? startDate =
        (initialData?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate =
        (initialData?['endDate'] as Timestamp?)?.toDate();
    String status =
        initialData?['status'] ?? 'DRAFT';
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
        builder: (ctx, setSheet) => DraggableScrollableSheet(
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
                  margin:
                      const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        isEdit
                            ? 'Edit Event'
                            : 'Create Event',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!
                                    .validate()) return;
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

                                final data = {
                                  'title':
                                      titleCtrl.text.trim(),
                                  'description':
                                      descCtrl.text.trim(),
                                  'location':
                                      locationCtrl.text.trim(),
                                  'capacity': int.tryParse(
                                          capacityCtrl.text
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
                                        .collection('events')
                                        .doc(eventId)
                                        .update(data);
                                  } else {
                                    data['createdAt'] =
                                        FieldValue
                                            .serverTimestamp();
                                    data['createdBy'] =
                                        FirebaseAuth.instance
                                            .currentUser
                                            ?.uid;
                                    data['createdByRole'] =
                                        _userRole;
                                    await FirebaseFirestore
                                        .instance
                                        .collection('events')
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
                                  if (ctx.mounted) {
                                    _showSnackBar('Error: $e',
                                        isError: true);
                                  }
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
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // ─── Title ───
                        _formField(
                          controller: titleCtrl,
                          label: 'Event Title',
                          hint:
                              'e.g. Grand Alumni Homecoming 2026',
                          validator: (v) =>
                              v?.trim().isEmpty == true
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // ─── Description ───
                        _formField(
                          controller: descCtrl,
                          label: 'Description',
                          hint:
                              'What is this event about?',
                          maxLines: 4,
                          validator: (v) =>
                              v?.trim().isEmpty == true
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // ─── Location ───
                        _formField(
                          controller: locationCtrl,
                          label: 'Location',
                          hint:
                              'e.g. College Gym / Online',
                          prefixIcon:
                              Icons.location_on_outlined,
                          validator: (v) =>
                              v?.trim().isEmpty == true
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // ─── Capacity ───
                        _formField(
                          controller: capacityCtrl,
                          label: 'Capacity',
                          hint: 'Max attendees (0 = unlimited)',
                          prefixIcon: Icons.people_outline,
                          keyboardType:
                              TextInputType.number,
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty)
                              return 'Required';
                            if (int.tryParse(v.trim()) ==
                                null)
                              return 'Must be a number';
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
                                    context, startDate);
                            if (picked != null) {
                              setSheet(
                                  () => startDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // ─── End date ───
                        _dateTile(
                          label: 'End Date & Time (optional)',
                          value: endDate,
                          onTap: () async {
                            final picked =
                                await _pickDateTime(
                                    context, endDate);
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

                        // ─── Status dropdown ───
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
                          child: DropdownButtonFormField<String>(
                            value: status,
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
                              'CANCELLED'
                            ]
                                .map((v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v,
                                        style: GoogleFonts
                                            .inter(
                                                fontSize:
                                                    14))))
                                .toList(),
                            onChanged: (v) => setSheet(
                                () => status = v!),
                            style:
                                GoogleFonts.inter(
                                    fontSize: 14,
                                    color:
                                        AppColors.darkText),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Toggles ───
                        _toggleTile(
                          icon: Icons.videocam_outlined,
                          title: 'Virtual Event',
                          subtitle:
                              'This event will be online',
                          value: isVirtual,
                          onChanged: (v) =>
                              setSheet(() => isVirtual = v),
                        ),
                        const SizedBox(height: 10),
                        _toggleTile(
                          icon: Icons.star_outline,
                          title: 'Mark as Important',
                          subtitle:
                              'Highlight for all alumni',
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
      BuildContext context, DateTime? initial) async {
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
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brandRed),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;

    return DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _confirmDelete(
      String eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Event',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text(
            'Are you sure you want to delete "$title"? This cannot be undone.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
          .collection('events')
          .doc(eventId)
          .delete();
      _showSnackBar('Event deleted', isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _updateStatus(
      String eventId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Logo ───
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALUMNI',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        letterSpacing: 6,
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ARCHIVE PORTAL',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Nav ───
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
                            route: '/chapter_management'),
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
                      _sidebarSection('ADMIN FEATURES', [
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

              // ─── Footer ───
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: AppColors.borderSubtle
                              .withOpacity(0.3))),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppColors.brandRed,
                          child: Text(
                            'A',
                            style:
                                GoogleFonts.cormorantGaramond(
                                    color: Colors.white,
                                    fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Registrar Admin',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.bold)),
                            Text('NETWORK OVERSEER',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color:
                                        AppColors.mutedText)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance
                            .signOut();
                        if (mounted) {
                          Navigator.pushReplacementNamed(
                              context, '/login');
                        }
                      },
                      child: Text(
                        'DISCONNECT',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
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
                        Text(
                          'Event Planning',
                          style:
                              GoogleFonts.cormorantGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            color: AppColors.darkText,
                          ),
                        ),
                        Text(
                          'Coordinate and track all alumni gatherings.',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.mutedText),
                        ),
                      ],
                    ),
                    if (_canManage)
                      ElevatedButton.icon(
                        onPressed: () => _showEventForm(),
                        icon: const Icon(Icons.add,
                            size: 18),
                        label: Text('Create New Event',
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
                child: Column(
                  children: [
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
                      child: Row(
                        children: [
                          _filterChip('All', null),
                          const SizedBox(width: 8),
                          _filterChip('Draft', 'DRAFT'),
                          const SizedBox(width: 8),
                          _filterChip(
                              'Published', 'PUBLISHED'),
                          const SizedBox(width: 8),
                          _filterChip(
                              'Ongoing', 'ONGOING'),
                          const SizedBox(width: 8),
                          _filterChip(
                              'Completed', 'COMPLETED'),
                          const SizedBox(width: 8),
                          _filterChip(
                              'Cancelled', 'CANCELLED'),
                        ],
                      ),
                    ),
                  ],
                ),
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
                        child: Text(
                            'Error: ${snapshot.error}',
                            style: GoogleFonts.inter(
                                color: Colors.red)),
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
                        final location = data['location']
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        return title.contains(
                                _searchQuery) ||
                            location
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
                                Icons.event_busy_outlined,
                                size: 72,
                                color:
                                    AppColors.borderSubtle),
                            const SizedBox(height: 16),
                            Text('No events found',
                                style: GoogleFonts
                                    .cormorantGaramond(
                                        fontSize: 22,
                                        color: AppColors
                                            .darkText)),
                            const SizedBox(height: 8),
                            if (_canManage)
                              TextButton.icon(
                                onPressed: () =>
                                    _showEventForm(),
                                icon: const Icon(Icons.add,
                                    color:
                                        AppColors.brandRed),
                                label: Text(
                                    'Create first event',
                                    style: GoogleFonts.inter(
                                        color: AppColors
                                            .brandRed)),
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
                        return _eventCard(doc.id, data);
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

// ─── Sidebar helpers ───
Widget _sidebarSection(String title, List<Widget> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
          color: AppColors.mutedText.withOpacity(0.7),
        ),
      ),
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
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: isActive
                ? AppColors.brandRed
                : AppColors.darkText,
            fontWeight: isActive
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}
  Widget _eventCard(String id, Map<String, dynamic> data) {
    final status =
        data['status']?.toString() ?? 'DRAFT';
    final title =
        data['title']?.toString() ?? 'Untitled Event';
    final description =
        data['description']?.toString() ?? '';
    final location =
        data['location']?.toString() ?? 'TBD';
    final capacity = data['capacity']?.toString() ?? '0';
    final isVirtual =
        data['isVirtual'] as bool? ?? false;
    final isImportant =
        data['isImportant'] as bool? ?? false;
    final startTs =
        data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final startDt = startTs?.toDate();
    final endDt = endTs?.toDate();

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
          // ─── Top row ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor(status)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_outlined,
                    color: _statusColor(status), size: 24),
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
                                color: AppColors.mutedText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ),
              ),

              // ─── Status badge + dropdown ───
              if (_canManage)
                PopupMenuButton<String>(
                  tooltip: 'Change status',
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
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
                          Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(status),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down,
                              size: 14,
                              color: _statusColor(status)),
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── Description ───
          if (description.isNotEmpty)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  height: 1.5),
            ),

          const SizedBox(height: 10),

          // ─── Info chips ───
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (startDt != null)
                _chip(
                  Icons.calendar_today_outlined,
                  DateFormat('MMM dd, yyyy').format(startDt),
                ),
              if (startDt != null)
                _chip(
                  Icons.access_time_outlined,
                  endDt != null
                      ? '${DateFormat('hh:mm a').format(startDt)} – ${DateFormat('hh:mm a').format(endDt)}'
                      : DateFormat('hh:mm a').format(startDt),
                ),
              _chip(Icons.people_outline,
                  '$capacity attendees'),
              if (isVirtual)
                _chip(Icons.videocam_outlined, 'Virtual',
                    color: Colors.blue),
              if (isImportant)
                _chip(Icons.star_outline, 'Important',
                    color: Colors.orange.shade700),
            ],
          ),

          if (_canManage) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSubtle),
            const SizedBox(height: 4),

            // ─── Actions ───
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
                  onTap: () => _confirmDelete(id, title),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : AppColors.mutedText,
          ),
        ),
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
        child: Row(
          children: [
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
          ],
        ),
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
                fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
        value: value,
        activeColor: AppColors.brandRed,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
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