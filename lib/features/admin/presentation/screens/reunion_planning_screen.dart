import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class ReunionAndEventsScreen extends StatefulWidget {
  const ReunionAndEventsScreen({super.key});

  @override
  State<ReunionAndEventsScreen> createState() => _ReunionAndEventsScreenState();
}

class _ReunionAndEventsScreenState extends State<ReunionAndEventsScreen> {
  String? selectedFilterType;
  String? selectedValue;

  final statusOptions = ['All', 'draft', 'published', 'ongoing', 'completed', 'cancelled'];
  final reunionTypeOptions = ['All', 'batch-reunion', 'grand-homecoming', 'decade-reunion', 'class-reunion'];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 1100;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: SafeArea(
        top: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar (collapsed on narrow screens)
            if (!isNarrow)
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSidebarSection('NETWORK', [
                              _SidebarItem(label: 'Overview', route: '/overview'),
                              _SidebarItem(label: 'Chapter Management', route: '/chapter_management'),
                            ]),
                            const SizedBox(height: 32),
                            _buildSidebarSection('ENGAGEMENT', [
                              _SidebarItem(label: 'Reunions & Events', isActive: true, route: '/reunions_events'),
                              _SidebarItem(label: 'Career Milestones', route: '/career_milestones'),
                            ]),
                            const SizedBox(height: 32),
                            _buildSidebarSection('ADMIN FEATURES', [
                              _SidebarItem(label: 'User Verification & Moderation', route: '/user_verification_moderation'),
                              _SidebarItem(label: 'Event Planning', route: '/event_planning'),
                              _SidebarItem(label: 'Job Board Management', route: '/job_board_management'),
                              _SidebarItem(label: 'Growth Metrics', route: '/growth_metrics'),
                              _SidebarItem(label: 'Announcement Management', route: '/announcement_management'),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.borderSubtle.withOpacity(0.3))),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.brandRed,
                                child: Text('A', style: GoogleFonts.cormorantGaramond(color: Colors.white, fontSize: 14)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Registrar Admin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text('NETWORK OVERSEER', style: GoogleFonts.inter(fontSize: 9, color: AppColors.mutedText)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) Navigator.pushReplacementNamed(context, '/');
                            },
                            child: Text(
                              'DISCONNECT',
                              style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Main content ────────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero banner – smaller, perfectly centered, no top sticking
                    Padding(
                      padding: const EdgeInsets.only(top: 24), // safe space from top bar
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                        child: Container(
                          height: 480, // reduced height for better balance
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF0F172A).withOpacity(0.94),
                                const Color(0xFF1E293B).withOpacity(0.84),
                                const Color(0xFF334155).withOpacity(0.70),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 60),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandRed.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(60),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.brandRed.withOpacity(0.45),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'LIVE FROM CAMPUS',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  Text(
                                    'Grand Alumni Reunions 2025',
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 64,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      height: 1.08,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Exclusive gatherings • Batch celebrations • Decade homecomings • Flagship events',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      color: Colors.white.withOpacity(0.92),
                                      letterSpacing: 0.6,
                                      height: 1.45,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 56),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FilledButton(
                                        onPressed: () => _showEventForm(),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.brandRed,
                                          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 22),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
                                        ),
                                        child: Text(
                                          'CREATE NEW EVENT',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 40),
                                      OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Colors.white, width: 2.5),
                                          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 22),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
                                        ),
                                        child: Text(
                                          'VIEW SCHEDULE',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Content below hero ──────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(80, 80, 80, 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private & Major Events',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Exclusively for alumni • Batch reunions, homecomings & flagship gatherings',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 64),

                          Wrap(
                            spacing: 48,
                            runSpacing: 28,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DropdownButton<String?>(
                                value: selectedFilterType,
                                hint: Text(
                                  'Filter by...',
                                  style: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 17),
                                ),
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('All Events')),
                                  DropdownMenuItem(value: 'status', child: Text('Status')),
                                  DropdownMenuItem(value: 'reunionType', child: Text('Reunion Type')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedFilterType = value;
                                    selectedValue = null;
                                  });
                                },
                              ),
                              if (selectedFilterType != null)
                                DropdownButton<String>(
                                  value: selectedValue,
                                  hint: Text(
                                    selectedFilterType == 'status' ? 'Select Status' : 'Select Type',
                                    style: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 17),
                                  ),
                                  underline: const SizedBox(),
                                  items: (selectedFilterType == 'status' ? statusOptions : reunionTypeOptions)
                                      .map((v) => DropdownMenuItem(
                                            value: v == 'All' ? null : v,
                                            child: Text(v),
                                          ))
                                      .toList(),
                                  onChanged: (value) => setState(() => selectedValue = value),
                                ),
                              FilledButton.icon(
                                icon: const Icon(Icons.add, size: 22),
                                label: const Text('New Reunion / Event'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brandRed,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                ),
                                onPressed: () => _showEventForm(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Events grid ────────────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 80),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _getFilteredEvents(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 240),
                              child: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 240),
                              child: Center(
                                child: Text(
                                  'Error loading events — please try again',
                                  style: GoogleFonts.inter(color: Colors.red, fontSize: 20),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          if (docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 240),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.celebration_outlined, size: 160, color: Colors.grey[300]),
                                    const SizedBox(height: 56),
                                    Text(
                                      'No events match your filter',
                                      style: GoogleFonts.inter(fontSize: 28, color: AppColors.darkText),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Create one or adjust the filter above',
                                      style: GoogleFonts.inter(fontSize: 18, color: AppColors.mutedText),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 120),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isNarrow ? 1 : (size.width < 1400 ? 2 : 3),
                              childAspectRatio: 0.88,
                              crossAxisSpacing: 56,
                              mainAxisSpacing: 72,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final id = docs[index].id;
                              final title = data['title'] ?? 'Untitled Event';
                              final desc = data['description'] ?? '';
                              final location = data['location'] ?? 'Virtual / Campus';
                              final start = (data['startDate'] as Timestamp?)?.toDate();
                              final status = (data['status'] as String?)?.toLowerCase() ?? 'draft';
                              final type = data['type'] as String?;
                              final isReunion = type?.contains('reunion') ?? false;

                              return Card(
                                elevation: 10,
                                shadowColor: Colors.black.withOpacity(0.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                      child: Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: isReunion ? AppColors.brandRed.withOpacity(0.08) : Colors.blue.withOpacity(0.08),
                                        child: Center(
                                          child: Icon(
                                            isReunion ? Icons.celebration : Icons.event,
                                            size: 90,
                                            color: isReunion ? AppColors.brandRed.withOpacity(0.6) : Colors.blue.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(36),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.cormorantGaramond(
                                                    fontSize: 32,
                                                    height: 1.1,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                              if (isReunion)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 20),
                                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.brandRed.withOpacity(0.14),
                                                    borderRadius: BorderRadius.circular(50),
                                                  ),
                                                  child: Text(
                                                    'REUNION',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: AppColors.brandRed,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 28),
                                          Text(
                                            desc.isEmpty ? 'No description provided' : desc,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              height: 1.65,
                                              color: AppColors.mutedText,
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Wrap(
                                            spacing: 28,
                                            runSpacing: 16,
                                            children: [
                                              _StatusBadge(status: status),
                                              if (start != null)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.calendar_today, size: 20, color: AppColors.mutedText),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      DateFormat('MMM dd, yyyy • h:mm a').format(start),
                                                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
                                                    ),
                                                  ],
                                                ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.location_on, size: 20, color: AppColors.mutedText),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    location,
                                                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 40),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: FilledButton(
                                                  onPressed: () {},
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: AppColors.brandRed,
                                                    padding: const EdgeInsets.symmetric(vertical: 22),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                                  ),
                                                  child: Text(
                                                    'SECURE ACCESS',
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 17,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 28),
                                                onPressed: () => _showEventForm(eventId: id, initialData: data),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 28, color: Colors.redAccent),
                                                onPressed: () => _confirmDelete(id, title),
                                              ),
                                              if (status == 'draft')
                                                IconButton(
                                                  icon: const Icon(Icons.publish, color: Colors.blue, size: 28),
                                                  onPressed: () => _publishEvent(id),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 160),
                  ],
                ),
              ),
            ),

            // Right sidebar ─────────────────────────────────────────────────────────────
            if (!isNarrow)
              Container(
                width: 380,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(72, 88, 72, 72),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Career Pulse',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 40,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 32),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('stats').doc('career_pulse').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                            return Text(
                              'Career stats currently unavailable',
                              style: GoogleFonts.inter(fontSize: 18, color: Colors.grey),
                            );
                          }

                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          final percentage = data['percentage']?.toString() ?? '48';
                          final title = data['title'] ?? 'CLASS OF \'12 MOVING TO PRINCIPAL ROLES';
                          final description = data['description'] ?? 'Based on your network — several Senior Partner roles have opened in Zurich and nearby regions.';

                          return Container(
                            padding: const EdgeInsets.all(44),
                            decoration: BoxDecoration(
                              color: AppColors.brandRed.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$percentage%',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 88,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.brandRed,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  description,
                                  style: GoogleFonts.inter(fontSize: 17, color: AppColors.mutedText),
                                ),
                                const SizedBox(height: 36),
                                TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    'VIEW INSIGHTS →',
                                    style: GoogleFonts.inter(
                                      color: AppColors.brandRed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 100),

                      Text(
                        'Active Chapters',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 40,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 32),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chapters')
                            .orderBy('memberCount', descending: true)
                            .limit(8)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Unable to load active chapters right now',
                              style: GoogleFonts.inter(fontSize: 18, color: Colors.grey),
                            );
                          }

                          final chapters = snapshot.data?.docs ?? [];

                          if (chapters.isEmpty) {
                            return Text(
                              'No active chapters found at the moment.',
                              style: GoogleFonts.inter(fontSize: 18, color: AppColors.mutedText),
                            );
                          }

                          return Column(
                            children: chapters.asMap().entries.map((entry) {
                              final index = entry.key;
                              final doc = entry.value;
                              final data = doc.data() as Map<String, dynamic>;
                              final city = data['city'] ?? data['name'] ?? 'Unknown City';
                              final count = (data['memberCount'] ?? 0).toString();

                              return Column(
                                children: [
                                  _ChapterListItem(city: city, count: int.tryParse(count) ?? 0),
                                  if (index < chapters.length - 1) const Divider(height: 64),
                                ],
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
      ),
    );
  }

  Widget _ChapterListItem({required String city, required int count}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.location_on, color: AppColors.brandRed, size: 36),
      title: Text(
        city,
        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      trailing: Text(
        '$count',
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.brandRed,
        ),
      ),
    );
  }

  Widget _buildSidebarSection(String title, List<Widget> items) {
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

  Widget _SidebarItem({required String label, bool isActive = false, String? route}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null
            ? () {
                Navigator.pushNamed(context, route);
              }
            : null,
        child: MouseRegion(
          cursor: route != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: isActive ? AppColors.brandRed : AppColors.darkText,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredEvents() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('events');

    if (selectedFilterType == 'status' && selectedValue != null) {
      query = query.where('status', isEqualTo: selectedValue);
    } else if (selectedFilterType == 'reunionType' && selectedValue != null) {
      query = query.where('type', isEqualTo: selectedValue);
    } else {
      query = query.where('type', whereIn: ['batch-reunion', 'grand-homecoming', 'decade-reunion', 'class-reunion']);
    }

    return query.orderBy('startDate', descending: true).snapshots();
  }

  Widget _StatusBadge({required String status}) {
    Color color;
    switch (status.toLowerCase()) {
      case 'published':
        color = Colors.blue;
        break;
      case 'ongoing':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(70),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 14, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _publishEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text('Publish Event'),
        content: const Text('Are you sure you want to publish this event?\nIt will become visible to alumni.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event published successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error publishing: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEventForm({String? eventId, Map<String, dynamic>? initialData}) {
    final isEdit = eventId != null;
    final titleCtrl = TextEditingController(text: initialData?['title'] ?? '');
    final descCtrl = TextEditingController(text: initialData?['description'] ?? '');
    final locationCtrl = TextEditingController(text: initialData?['location'] ?? '');
    final batchCtrl = TextEditingController(text: initialData?['batchYear'] ?? '');
    String selectedType = initialData?['type'] ?? 'batch-reunion';

    DateTime? startDate = (initialData?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (initialData?['endDate'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
          title: Text(isEdit ? 'Edit Reunion/Event' : 'Create New Reunion/Event'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 580,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: descCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location / Platform'),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: batchCtrl,
                    decoration: const InputDecoration(labelText: 'Batch / Year (e.g. Batch 2015)'),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Event Type'),
                    items: const [
                      DropdownMenuItem(value: 'batch-reunion', child: Text('Batch Reunion')),
                      DropdownMenuItem(value: 'grand-homecoming', child: Text('Grand Homecoming')),
                      DropdownMenuItem(value: 'decade-reunion', child: Text('Decade Reunion')),
                      DropdownMenuItem(value: 'class-reunion', child: Text('Class Reunion')),
                      DropdownMenuItem(value: 'other', child: Text('Other Major Event')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 40),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      startDate == null ? 'Start Date & Time *' : DateFormat('MMM dd, yyyy • h:mm a').format(startDate!),
                      style: GoogleFonts.inter(fontSize: 17),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 32),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startDate ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      endDate == null ? 'End Date & Time (optional)' : DateFormat('MMM dd, yyyy • h:mm a').format(endDate!),
                      style: GoogleFonts.inter(fontSize: 17),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 32),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now().add(const Duration(hours: 2)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endDate ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || startDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and start date are required')),
                  );
                  return;
                }

                final data = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'batchYear': batchCtrl.text.trim().isNotEmpty ? batchCtrl.text.trim() : null,
                  'type': selectedType,
                  'startDate': Timestamp.fromDate(startDate!),
                  if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (!isEdit) ...{
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid,
                    'status': 'draft',
                    'registeredCount': 0,
                  },
                };

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance.collection('events').doc(eventId).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('events').add(data);
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Event updated' : 'Event created (draft)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving event: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting event: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}