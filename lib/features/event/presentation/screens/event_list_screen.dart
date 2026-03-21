import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'event_screen.dart';
import 'add_event_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  String? _userRole;
  String _filter = 'upcoming'; // upcoming, past, all

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
              doc.data()?['role'] as String? ?? 'alumni';
        });
      }
    } catch (_) {}
  }

  bool get _canAddEvent =>
      _userRole == 'admin' ||
      _userRole == 'moderator' ||
      _userRole == 'staff' ||
      _userRole == 'registrar';

  @override
  Widget build(BuildContext context) {
    final currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
        title: Text('Events',
            style: GoogleFonts.cormorantGaramond(fontSize: 26)),
        centerTitle: true,
        actions: [
          if (_canAddEvent)
            IconButton(
              icon: const Icon(Icons.add,
                  color: AppColors.brandRed),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddEventScreen()),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                _filterChip('Past', 'past'),
                const SizedBox(width: 8),
                _filterChip('All', 'all'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .orderBy('startDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.brandRed));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red)),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return _emptyState();
          }

          final now = DateTime.now();
          var docs = snapshot.data!.docs;

          // ─── Filter ───
          if (_filter == 'upcoming') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final ts = data['startDate'] as Timestamp?;
              return ts != null &&
                  ts.toDate().isAfter(now);
            }).toList();
          } else if (_filter == 'past') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final ts = data['startDate'] as Timestamp?;
              return ts != null &&
                  ts.toDate().isBefore(now);
            }).toList();
          }

          if (docs.isEmpty) {
            return _emptyState(
                message: _filter == 'upcoming'
                    ? 'No upcoming events'
                    : 'No past events');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final eventDoc = docs[index];
              final event =
                  eventDoc.data() as Map<String, dynamic>;
              final eventId = eventDoc.id;

              final startTs =
                  event['startDate'] as Timestamp?;
              final dt = startTs?.toDate();
              final datePart = dt != null
                  ? DateFormat('MMM dd, yyyy').format(dt)
                  : 'TBD';
              final timePart = dt != null
                  ? DateFormat('hh:mm a').format(dt)
                  : 'TBD';
              final isPast =
                  dt != null && dt.isBefore(now);

              final title =
                  event['title']?.toString() ?? 'Untitled';
              final location =
                  event['location']?.toString() ?? 'TBD';
              final description =
                  event['description']?.toString() ?? '';
              final heroImageUrl =
                  event['heroImageUrl']?.toString() ?? '';
              final isVirtual =
                  event['isVirtual'] as bool? ?? false;
              final isImportant =
                  event['isImportant'] as bool? ?? false;
              final type =
                  event['type']?.toString() ?? 'Campus Event';

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventScreen(
                        event: {...event, 'id': eventId}),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isImportant
                          ? AppColors.brandRed
                              .withOpacity(0.3)
                          : AppColors.borderSubtle,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ─── Image ───
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Stack(
                          children: [
                            heroImageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: heroImageUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        Container(
                                          height: 180,
                                          color: AppColors
                                              .borderSubtle,
                                          child: const Center(
                                            child:
                                                CircularProgressIndicator(
                                                    color: AppColors
                                                        .brandRed,
                                                    strokeWidth:
                                                        2),
                                          ),
                                        ),
                                    errorWidget: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  )
                                : _imagePlaceholder(),

                            // ─── Gradient overlay ───
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black
                                          .withOpacity(0.55),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ─── Badges ───
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Row(children: [
                                _badge(type.toUpperCase(),
                                    AppColors.brandRed),
                                if (isVirtual) ...[
                                  const SizedBox(width: 6),
                                  _badge('VIRTUAL',
                                      Colors.blue.shade600),
                                ],
                                if (isImportant) ...[
                                  const SizedBox(width: 6),
                                  _badge(
                                      '★ IMPORTANT',
                                      Colors.orange
                                          .shade700),
                                ],
                              ]),
                            ),

                            if (isPast)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withOpacity(0.3),
                                    borderRadius:
                                        const BorderRadius
                                            .vertical(
                                            top: Radius
                                                .circular(16)),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius
                                                .circular(8),
                                      ),
                                      child: Text('PAST EVENT',
                                          style: GoogleFonts
                                              .inter(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w700,
                                            letterSpacing: 1,
                                          )),
                                    ),
                                  ),
                                ),
                              ),

                            // ─── Title overlay ───
                            Positioned(
                              bottom: 12,
                              left: 16,
                              right: 16,
                              child: Text(
                                title,
                                style:
                                    GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                  shadows: const [
                                    Shadow(
                                        blurRadius: 8,
                                        color: Colors.black54)
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Info ───
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _infoChip(
                                    Icons.calendar_today_outlined,
                                    datePart),
                                _infoChip(
                                    Icons.access_time_outlined,
                                    timePart),
                                _infoChip(
                                    Icons.location_on_outlined,
                                    location),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(description,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.mutedText,
                                      height: 1.5),
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 12),

                            // ─── Like / Comment ───
                            Row(
                              children: [
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore
                                      .instance
                                      .collection('events')
                                      .doc(eventId)
                                      .collection('likes')
                                      .snapshots(),
                                  builder: (context, snap) {
                                    final count = snap
                                            .data?.docs.length ??
                                        0;
                                    final isLiked = currentUserUid !=
                                            null &&
                                        snap.data?.docs.any((d) =>
                                                d.id ==
                                                currentUserUid) ==
                                            true;
                                    return GestureDetector(
                                      onTap: () async {
                                        if (currentUserUid ==
                                            null) return;
                                        final ref =
                                            FirebaseFirestore
                                                .instance
                                                .collection('events')
                                                .doc(eventId)
                                                .collection('likes')
                                                .doc(currentUserUid);
                                        final doc =
                                            await ref.get();
                                        if (doc.exists) {
                                          await ref.delete();
                                        } else {
                                          await ref.set({
                                            'likedAt': FieldValue
                                                .serverTimestamp()
                                          });
                                        }
                                      },
                                      child: Row(children: [
                                        Icon(
                                          isLiked
                                              ? Icons.favorite
                                              : Icons
                                                  .favorite_border,
                                          color: isLiked
                                              ? AppColors
                                                  .brandRed
                                              : AppColors
                                                  .mutedText,
                                          size: 20,
                                        ),
                                        if (count > 0) ...[
                                          const SizedBox(
                                              width: 4),
                                          Text('$count',
                                              style:
                                                  GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: AppColors
                                                          .mutedText)),
                                        ],
                                      ]),
                                    );
                                  },
                                ),
                                const SizedBox(width: 20),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore
                                      .instance
                                      .collection('events')
                                      .doc(eventId)
                                      .collection('comments')
                                      .snapshots(),
                                  builder: (context, snap) {
                                    final count = snap
                                            .data?.docs.length ??
                                        0;
                                    return Row(children: [
                                      const Icon(
                                          Icons
                                              .chat_bubble_outline,
                                          color:
                                              AppColors.mutedText,
                                          size: 20),
                                      if (count > 0) ...[
                                        const SizedBox(width: 4),
                                        Text('$count',
                                            style:
                                                GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: AppColors
                                                        .mutedText)),
                                      ],
                                    ]);
                                  },
                                ),
                                const Spacer(),
                                Text('View details',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.brandRed,
                                        fontWeight:
                                            FontWeight.w600)),
                                const SizedBox(width: 4),
                                const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: AppColors.brandRed),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: AppColors.borderSubtle,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_outlined,
              size: 48, color: AppColors.mutedText),
          const SizedBox(height: 8),
          Text('No image',
              style: GoogleFonts.inter(
                  color: AppColors.mutedText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
      ]),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandRed
              : AppColors.cardWhite,
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
                  : AppColors.mutedText,
            )),
      ),
    );
  }

  Widget _emptyState({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_outlined,
              size: 72, color: AppColors.borderSubtle),
          const SizedBox(height: 16),
          Text(
            message ?? 'No events yet',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24, color: AppColors.darkText),
          ),
          const SizedBox(height: 8),
          Text(
            _canAddEvent
                ? 'Tap + to create the first event'
                : 'Check back later',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}