import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_screen.dart';
import 'add_event_screen.dart'; // ← Add this import (adjust path if needed)

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Events',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.search, color: Colors.black),
          ),
        ],
      ),
      floatingActionButton: _canAddEvent
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEventScreen()),
                );
              },
              backgroundColor: const Color(0xFFE64646),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Event',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE64646)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No upcoming events yet',
                    style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final eventDoc = events[index];
              final event = eventDoc.data() as Map<String, dynamic>;
              final eventId = eventDoc.id;

              final startDate = event['startDate'] as Timestamp?;
              final dateStr = startDate != null
                  ? DateFormat('MMM dd, yyyy • hh:mm a').format(startDate.toDate())
                  : 'Date not set';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventScreen(
                          event: {
                            ...event,
                            'id': eventId,
                          },
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE64646).withOpacity(0.2),
                                child: const Icon(Icons.school, color: Color(0xFFE64646), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'St. Cecilia’s Alumni',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      dateStr,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.more_vert, color: Colors.black54),
                            ],
                          ),
                        ),

                        // Gradient post area
                        Container(
                          height: MediaQuery.of(context).size.width,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF5E7C),
                                Color(0xFFFF8C61),
                                Color(0xFFF9D423),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                event['title'] ?? 'Event Title',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                        // Content below gradient
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['description'] ?? 'No description available.',
                                style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    event['location'] ?? 'Location not set',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Action bar
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
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Icon(Icons.favorite_border, color: Colors.black87, size: 26);
                                          }
                                          final likeCount = snapshot.data!.docs.length;
                                          final isLiked = currentUserUid != null &&
                                              snapshot.data!.docs.any((doc) => doc.id == currentUserUid);

                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () async {
                                                  final uid = currentUserUid;
                                                  if (uid == null) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Please sign in to like')),
                                                    );
                                                    return;
                                                  }

                                                  final likeRef = FirebaseFirestore.instance
                                                      .collection('events')
                                                      .doc(eventId)
                                                      .collection('likes')
                                                      .doc(uid);
                                                  final doc = await likeRef.get();
                                                  if (doc.exists) {
                                                    await likeRef.delete();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Removed like')),
                                                    );
                                                  } else {
                                                    await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Like added')),
                                                    );
                                                  }
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  child: Icon(
                                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                                    color: isLiked ? Colors.red : Colors.black87,
                                                    size: 26,
                                                  ),
                                                ),
                                              ),
                                              if (likeCount > 0) ...[
                                                const SizedBox(width: 4),
                                                Text('$likeCount', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                              ]
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
                                                Icon(Icons.chat_bubble_outline, color: Colors.black87, size: 26),
                                                const SizedBox(width: 4),
                                                Text('$count', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                              ],
                                            );
                                          },
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Icon(Icons.send_outlined, color: Colors.black87, size: 26),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.bookmark_border, color: Colors.black87, size: 28),
                                ],
                              ),

                              const SizedBox(height: 8),

                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(eventId)
                                    .collection('likes')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final likeCount = snapshot.data?.docs.length ?? 0;
                                  final label = likeCount == 1 ? 'like' : 'likes';
                                  return Text(
                                    '$likeCount $label',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  );
                                },
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