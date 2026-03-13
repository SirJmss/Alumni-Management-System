import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'event_screen.dart';
import 'add_event_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  String? _userRole;

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
        setState(() {
          _userRole = doc.data()?['role'] as String? ?? 'alumni';
        });
      }
    } catch (_) {}
  }

  bool get _canAddEvent => _userRole == 'admin' || _userRole == 'moderator';

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    final backgroundCream = const Color(0xFFFAF7F2);
    final textDark = const Color(0xFF1A1C35);
    final textSecondary = const Color(0xFF5F6368);
    final primaryRed = const Color(0xFFB22222);

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(
          'Events',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: textDark,
            fontSize: 28,
          ),
        ),
        backgroundColor: backgroundCream,
        foregroundColor: textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textDark),
            onPressed: () {
              // TODO: add search later if needed
            },
          ),
        ],
      ),
      floatingActionButton: _canAddEvent
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEventScreen()),
              ),
              backgroundColor: primaryRed,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Event',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .orderBy('startDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Events stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Error loading events\n${snapshot.error.toString()}',
                  style: GoogleFonts.inter(color: Colors.red[700], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_outlined, size: 80, color: textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming events yet',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create one if you have permission!',
                    style: GoogleFonts.inter(color: textSecondary.withOpacity(0.8)),
                  ),
                ],
              ),
            );
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final eventDoc = events[index];
              final event = eventDoc.data() as Map<String, dynamic>;
              final eventId = eventDoc.id;

              final startTs = event['startDate'] as Timestamp?;
              String datePart = 'Date TBD';
              String timePart = 'Time TBD';

              if (startTs != null) {
                final dt = startTs.toDate();
                datePart = DateFormat('MMM dd, yyyy').format(dt);
                timePart = DateFormat('hh:mm a').format(dt);
              }

              final title = (event['title'] as String?)?.trim() ?? 'Untitled Event';
              final location = (event['location'] as String?)?.trim() ?? 'Location TBD';
              final description = (event['description'] as String?)?.trim() ?? '';

              // Image priority: use uploaded heroImageUrl if exists, else fallback
              String heroImageUrl = (event['heroImageUrl'] as String?)?.trim() ?? '';
              if (heroImageUrl.isEmpty) {
                // Use a consistent fallback (you can change seed or use random)
                heroImageUrl = 'https://picsum.photos/seed/event$index/600/400';
              }

              // Debug print – check this in console to see what URL is being used
              print('Event $eventId → displaying image: $heroImageUrl');

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventScreen(event: {...event, 'id': eventId}),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: heroImageUrl,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  print('Image load failed → $url | Error: $error');
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('No image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                fadeInDuration: const Duration(milliseconds: 400),
                              ),
                              // Gradient overlay
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.6)],
                                    ),
                                  ),
                                ),
                              ),
                              // Title overlay
                              Positioned(
                                bottom: 16,
                                left: 20,
                                right: 20,
                                child: Text(
                                  title,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.15,
                                    shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _ElegantChip(icon: Icons.calendar_today_outlined, label: datePart, color: textDark),
                                  _ElegantChip(icon: Icons.access_time_outlined, label: timePart, color: textDark),
                                  _ElegantChip(icon: Icons.location_on_outlined, label: location, color: textDark),
                                ],
                              ),

                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  description,
                                  style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: textSecondary),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('events')
                                            .doc(eventId)
                                            .collection('likes')
                                            .snapshots(),
                                        builder: (context, snap) {
                                          final likeCount = snap.data?.docs.length ?? 0;
                                          final isLiked = currentUserUid != null &&
                                              snap.data?.docs.any((d) => d.id == currentUserUid) == true;

                                          return GestureDetector(
                                            onTap: () async {
                                              if (currentUserUid == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Please sign in')),
                                                );
                                                return;
                                              }
                                              final ref = FirebaseFirestore.instance
                                                  .collection('events')
                                                  .doc(eventId)
                                                  .collection('likes')
                                                  .doc(currentUserUid);
                                              final doc = await ref.get();
                                              if (doc.exists) {
                                                await ref.delete();
                                              } else {
                                                await ref.set({'likedAt': FieldValue.serverTimestamp()});
                                              }
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                                  color: isLiked ? primaryRed : textSecondary,
                                                  size: 22,
                                                ),
                                                if (likeCount > 0)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 6),
                                                    child: Text(
                                                      '$likeCount',
                                                      style: GoogleFonts.inter(
                                                        color: textDark,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 36),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('events')
                                            .doc(eventId)
                                            .collection('comments')
                                            .snapshots(),
                                        builder: (context, snap) {
                                          final count = snap.data?.docs.length ?? 0;
                                          return Row(
                                            children: [
                                              Icon(Icons.chat_bubble_outline_rounded,
                                                  color: textSecondary, size: 22),
                                              if (count > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 6),
                                                  child: Text('$count', style: GoogleFonts.inter(color: textDark)),
                                                ),
                                            ],
                                          );
                                        },
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('events')
                                              .doc(eventId)
                                              .collection('comments')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            final count = snapshot.data?.docs.length ?? 0;
                                            return Row(
                                              children: [
                                                const Icon(Icons.chat_bubble_outline, color: Colors.black87, size: 26),
                                                const SizedBox(width: 4),
                                                Text('$count', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                              ],
                                            );
                                          },
                                        ),
                                      ),

                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Icon(Icons.send_outlined, color: Colors.black87, size: 26),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.bookmark_border, color: Colors.black87, size: 28),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ElegantChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ElegantChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}