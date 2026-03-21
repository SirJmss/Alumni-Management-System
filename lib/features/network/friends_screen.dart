import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/communication/alumni_search_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Friends & Network',
          style: GoogleFonts.cormorantGaramond(fontSize: 26),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find alumni',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AlumniSearchScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brandRed,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.brandRed,
          indicatorWeight: 2,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Connections'),
            Tab(text: 'Requests'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConnectionsTab(currentUid: currentUid),
          _RequestsTab(currentUid: currentUid),
          _FollowingTab(currentUid: currentUid),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Connections Tab — people who accepted your request
// ─────────────────────────────────────────────
class _ConnectionsTab extends StatelessWidget {
  final String currentUid;
  const _ConnectionsTab({required this.currentUid});

  Future<void> _unfriend(BuildContext context, String otherUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Unfriend',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove this connection?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unfriend',
                style: GoogleFonts.inter(color: AppColors.brandRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(otherUid));

      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .collection('connections')
          .doc(currentUid));

      batch.update(
          FirebaseFirestore.instance.collection('users').doc(currentUid),
          {'connectionsCount': FieldValue.increment(-1)});

      batch.update(
          FirebaseFirestore.instance.collection('users').doc(otherUid),
          {'connectionsCount': FieldValue.increment(-1)});

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Connection removed'),
              backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .orderBy('connectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.people_outline,
            title: 'No connections yet',
            subtitle: 'Search for alumni and send friend requests',
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final uid = docs[index].id;
            return _AlumniListTile(
              uid: uid,
              currentUid: currentUid,
              trailing: (name) => OutlinedButton(
                onPressed: () => _unfriend(context, uid),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Unfriend',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Requests Tab — incoming + outgoing
// ─────────────────────────────────────────────
class _RequestsTab extends StatefulWidget {
  final String currentUid;
  const _RequestsTab({required this.currentUid});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  bool _showIncoming = true;

  Future<void> _acceptRequest(String fromUid) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      // Add to both connections subcollections
      batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.currentUid)
              .collection('connections')
              .doc(fromUid),
          {'connectedAt': now});

      batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(fromUid)
              .collection('connections')
              .doc(widget.currentUid),
          {'connectedAt': now});

      // Delete the request
      batch.delete(FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${fromUid}_${widget.currentUid}'));

      // Increment counts
      batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.currentUid),
          {'connectionsCount': FieldValue.increment(1)});

      batch.update(
          FirebaseFirestore.instance.collection('users').doc(fromUid),
          {'connectionsCount': FieldValue.increment(1)});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Connection accepted!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _declineRequest(String fromUid) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc('${fromUid}_${widget.currentUid}')
        .delete();
  }

  Future<void> _cancelRequest(String toUid) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc('${widget.currentUid}_$toUid')
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle incoming / outgoing
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showIncoming = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _showIncoming
                          ? AppColors.brandRed
                          : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Received',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _showIncoming
                            ? Colors.white
                            : AppColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showIncoming = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_showIncoming
                          ? AppColors.brandRed
                          : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Sent',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_showIncoming
                            ? Colors.white
                            : AppColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _showIncoming
              ? _incomingRequests()
              : _outgoingRequests(),
        ),
      ],
    );
  }

  Widget _incomingRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUid', isEqualTo: widget.currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'Friend requests you receive will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final fromUid =
                (doc.data() as Map<String, dynamic>)['fromUid']?.toString() ??
                    '';

            return _AlumniListTile(
              uid: fromUid,
              currentUid: widget.currentUid,
              trailing: (name) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.green),
                    tooltip: 'Accept',
                    onPressed: () => _acceptRequest(fromUid),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined,
                        color: Colors.red),
                    tooltip: 'Decline',
                    onPressed: () => _declineRequest(fromUid),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _outgoingRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromUid', isEqualTo: widget.currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.send_outlined,
            title: 'No sent requests',
            subtitle: 'Requests you send to alumni will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final toUid =
                (doc.data() as Map<String, dynamic>)['toUid']?.toString() ??
                    '';

            return _AlumniListTile(
              uid: toUid,
              currentUid: widget.currentUid,
              trailing: (name) => OutlinedButton(
                onPressed: () => _cancelRequest(toUid),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Following Tab
// ─────────────────────────────────────────────
class _FollowingTab extends StatelessWidget {
  final String currentUid;
  const _FollowingTab({required this.currentUid});

  Future<void> _unfollow(BuildContext context, String otherUid) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(otherUid));

      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .collection('followers')
          .doc(currentUid));

      batch.update(
          FirebaseFirestore.instance.collection('users').doc(otherUid),
          {'followersCount': FieldValue.increment(-1)});

      batch.update(
          FirebaseFirestore.instance.collection('users').doc(currentUid),
          {'followingCount': FieldValue.increment(-1)});

      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .orderBy('followedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.person_add_outlined,
            title: 'Not following anyone',
            subtitle: 'Follow alumni to stay updated with their activity',
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final uid = docs[index].id;
            return _AlumniListTile(
              uid: uid,
              currentUid: currentUid,
              trailing: (name) => OutlinedButton(
                onPressed: () => _unfollow(context, uid),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Unfollow',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Reusable alumni list tile
// ─────────────────────────────────────────────
class _AlumniListTile extends StatelessWidget {
  final String uid;
  final String currentUid;
  final Widget Function(String name) trailing;

  const _AlumniListTile({
    required this.uid,
    required this.currentUid,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Container(
              height: 13,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name']?.toString() ?? 'Unknown';
        final avatarUrl = data['profilePictureUrl']?.toString() ?? '';
        final headline = data['headline']?.toString() ?? data['role']?.toString() ?? '';
        final hasAvatar = avatarUrl.isNotEmpty;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlumniPublicProfileScreen(uid: uid),
              ),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.borderSubtle,
              child: hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: 52,
                        height: 52,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            color: AppColors.brandRed),
                      ),
                    )
                  : const Icon(Icons.person, color: AppColors.brandRed),
            ),
          ),
          title: Text(
            name,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: headline.isNotEmpty
              ? Text(
                  headline,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: trailing(name),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlumniPublicProfileScreen(uid: uid),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Shared empty state widget
// ─────────────────────────────────────────────
Widget _emptyState({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24, color: AppColors.darkText),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style:
                GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}