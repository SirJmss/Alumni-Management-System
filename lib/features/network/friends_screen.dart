import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

// AlumniSearchScreen is in the communication feature folder.
// AlumniPublicProfileScreen is the single canonical definition.
import 'package:alumni/features/communication/alumni_search_screen.dart';
import 'package:alumni/features/profile/presentation/screens/alumni_public_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FriendsScreen
// ─────────────────────────────────────────────────────────────────────────────
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Null-safe: guard against accessing before auth state emits
  final String _currentUid =
      FirebaseAuth.instance.currentUser?.uid ?? '';

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
    if (_currentUid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Not authenticated',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text('Please sign in to view your network.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text('Friends & Network',
            style: GoogleFonts.cormorantGaramond(fontSize: 26)),
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
          labelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500),
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
          _ConnectionsTab(currentUid: _currentUid),
          _RequestsTab(currentUid: _currentUid),
          _FollowingTab(currentUid: _currentUid),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ConnectionsTab extends StatelessWidget {
  final String currentUid;
  const _ConnectionsTab({required this.currentUid});

  Future<void> _unfriend(BuildContext context, String otherUid) async {
    if (otherUid.isEmpty || otherUid == currentUid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Remove Connection',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove this connection? They won\'t be notified.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db.collection('users').doc(currentUid).get(),
        db.collection('users').doc(otherUid).get(),
      ]);

      final myCount =
          (results[0].data()?['connectionsCount'] as num?)?.toInt() ?? 0;
      final theirCount =
          (results[1].data()?['connectionsCount'] as num?)?.toInt() ?? 0;

      final wb = db.batch();

      wb.delete(db
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(otherUid));
      wb.delete(db
          .collection('users')
          .doc(otherUid)
          .collection('connections')
          .doc(currentUid));

      if (myCount > 0) {
        wb.update(db.collection('users').doc(currentUid),
            {'connectionsCount': FieldValue.increment(-1)});
      }
      if (theirCount > 0) {
        wb.update(db.collection('users').doc(otherUid),
            {'connectionsCount': FieldValue.increment(-1)});
      }

      await wb.commit();

      if (context.mounted) {
        _showSnack(context, 'Connection removed', Colors.grey.shade700);
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showSnack(context, _firestoreErrorMessage(e), Colors.red.shade700);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Failed to remove connection.', Colors.red.shade700);
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
        if (snapshot.hasError) {
          return _ErrorState(
            message: _firestoreErrorMessage(snapshot.error),
            onRetry: () {},
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            title: 'No connections yet',
            subtitle: 'Search for alumni and send connection requests',
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final uid = docs[index].id;
            if (uid.isEmpty) return const SizedBox.shrink();

            return _AlumniListTile(
              uid: uid,
              currentUid: currentUid,
              trailing: (_) => _SmallOutlinedButton(
                label: 'Remove',
                onPressed: () => _unfriend(context, uid),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Requests Tab — incoming + outgoing
// ─────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatefulWidget {
  final String currentUid;
  const _RequestsTab({required this.currentUid});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  bool _showIncoming = true;

  // ─── Accept ──────────────────────────────────────────────────────────────
  Future<void> _acceptRequest(String fromUid) async {
    if (fromUid.isEmpty || fromUid == widget.currentUid) return;

    try {
      final db = FirebaseFirestore.instance;

      // Guard: check if already connected
      final existingSnap = await db
          .collection('users')
          .doc(widget.currentUid)
          .collection('connections')
          .doc(fromUid)
          .get();

      if (existingSnap.exists) {
        // Stale request — clean it up silently
        await db
            .collection('friend_requests')
            .doc('${fromUid}_${widget.currentUid}')
            .delete();
        if (!mounted) return;
        _showSnack(context, 'You\'re already connected!',
            Colors.orange.shade700);
        return;
      }

      // Confirm the request doc still exists
      final reqSnap = await db
          .collection('friend_requests')
          .doc('${fromUid}_${widget.currentUid}')
          .get();
      if (!reqSnap.exists) {
        if (!mounted) return;
        _showSnack(context, 'Request no longer available.',
            Colors.orange.shade700);
        return;
      }

      final now = FieldValue.serverTimestamp();
      final wb = db.batch();

      wb.set(
        db
            .collection('users')
            .doc(widget.currentUid)
            .collection('connections')
            .doc(fromUid),
        {'connectedAt': now, 'uid': fromUid},
      );
      wb.set(
        db
            .collection('users')
            .doc(fromUid)
            .collection('connections')
            .doc(widget.currentUid),
        {'connectedAt': now, 'uid': widget.currentUid},
      );
      wb.delete(db
          .collection('friend_requests')
          .doc('${fromUid}_${widget.currentUid}'));
      wb.update(db.collection('users').doc(widget.currentUid),
          {'connectionsCount': FieldValue.increment(1)});
      wb.update(db.collection('users').doc(fromUid),
          {'connectionsCount': FieldValue.increment(1)});

      await wb.commit();

      if (!mounted) return;
      _showSnack(context, 'Connection accepted!', Colors.green.shade700);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showSnack(context, _firestoreErrorMessage(e), Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, 'Failed to accept request.', Colors.red.shade700);
    }
  }

  // ─── Decline ─────────────────────────────────────────────────────────────
  Future<void> _declineRequest(String fromUid) async {
    if (fromUid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Decline Request',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Decline this connection request?',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Decline',
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
          .collection('friend_requests')
          .doc('${fromUid}_${widget.currentUid}')
          .delete();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showSnack(context, _firestoreErrorMessage(e), Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, 'Failed to decline request.', Colors.red.shade700);
    }
  }

  // ─── Cancel outgoing ─────────────────────────────────────────────────────
  Future<void> _cancelRequest(String toUid) async {
    if (toUid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Cancel Request',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Cancel your pending connection request?',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel Request',
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
          .collection('friend_requests')
          .doc('${widget.currentUid}_$toUid')
          .delete();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showSnack(context, _firestoreErrorMessage(e), Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, 'Failed to cancel request.', Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _ToggleButton(
                label: 'Received',
                active: _showIncoming,
                onTap: () => setState(() => _showIncoming = true),
              ),
              const SizedBox(width: 10),
              _ToggleButton(
                label: 'Sent',
                active: !_showIncoming,
                onTap: () => setState(() => _showIncoming = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child:
              _showIncoming ? _incomingRequests() : _outgoingRequests(),
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
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: _firestoreErrorMessage(snapshot.error),
            onRetry: () => setState(() {}),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'Connection requests you receive will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final fromUid = data['fromUid']?.toString() ?? '';
            if (fromUid.isEmpty) return const SizedBox.shrink();

            return _AlumniListTile(
              uid: fromUid,
              currentUid: widget.currentUid,
              trailing: (_) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accept
                  Material(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _acceptRequest(fromUid),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Decline
                  Material(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _declineRequest(fromUid),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.cancel_outlined,
                            color: Colors.red, size: 22),
                      ),
                    ),
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
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: _firestoreErrorMessage(snapshot.error),
            onRetry: () => setState(() {}),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.send_outlined,
            title: 'No sent requests',
            subtitle: 'Requests you send to other alumni will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final toUid = data['toUid']?.toString() ?? '';
            if (toUid.isEmpty) return const SizedBox.shrink();

            return _AlumniListTile(
              uid: toUid,
              currentUid: widget.currentUid,
              trailing: (_) => _SmallOutlinedButton(
                label: 'Cancel',
                onPressed: () => _cancelRequest(toUid),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Following Tab
// ─────────────────────────────────────────────────────────────────────────────
class _FollowingTab extends StatelessWidget {
  final String currentUid;
  const _FollowingTab({required this.currentUid});

  Future<void> _unfollow(BuildContext context, String otherUid) async {
    if (otherUid.isEmpty || otherUid == currentUid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Unfollow',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Stop following this person?',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Following',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unfollow',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db.collection('users').doc(currentUid).get(),
        db.collection('users').doc(otherUid).get(),
      ]);

      final myFollowingCount =
          (results[0].data()?['followingCount'] as num?)?.toInt() ?? 0;
      final theirFollowersCount =
          (results[1].data()?['followersCount'] as num?)?.toInt() ?? 0;

      final wb = db.batch();

      wb.delete(db
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(otherUid));
      wb.delete(db
          .collection('users')
          .doc(otherUid)
          .collection('followers')
          .doc(currentUid));

      if (myFollowingCount > 0) {
        wb.update(db.collection('users').doc(currentUid),
            {'followingCount': FieldValue.increment(-1)});
      }
      if (theirFollowersCount > 0) {
        wb.update(db.collection('users').doc(otherUid),
            {'followersCount': FieldValue.increment(-1)});
      }

      await wb.commit();

      if (context.mounted) {
        _showSnack(context, 'Unfollowed', Colors.grey.shade700);
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showSnack(context, _firestoreErrorMessage(e), Colors.red.shade700);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Failed to unfollow.', Colors.red.shade700);
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
        if (snapshot.hasError) {
          return _ErrorState(
            message: _firestoreErrorMessage(snapshot.error),
            onRetry: () {},
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState(
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
              const Divider(height: 1, color: AppColors.borderSubtle),
          itemBuilder: (context, index) {
            final uid = docs[index].id;
            if (uid.isEmpty) return const SizedBox.shrink();

            return _AlumniListTile(
              uid: uid,
              currentUid: currentUid,
              trailing: (_) => _SmallOutlinedButton(
                label: 'Unfollow',
                onPressed: () => _unfollow(context, uid),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlumniListTile — streams live user data, navigates to public profile
// ─────────────────────────────────────────────────────────────────────────────
class _AlumniListTile extends StatelessWidget {
  final String uid;
  final String currentUid;
  final Widget Function(String name) trailing;

  const _AlumniListTile({
    required this.uid,
    required this.currentUid,
    required this.trailing,
  });

  void _openProfile(BuildContext context) {
    if (uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlumniPublicProfileScreen(uid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.red.shade50,
              child: const Icon(Icons.error_outline,
                  color: Colors.red, size: 22),
            ),
            title: Text('Could not load user',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.mutedText)),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const _TileSkeleton();
        }

        if (!snapshot.data!.exists) {
          return ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade100,
              child: const Icon(Icons.person_off_outlined,
                  color: Colors.grey, size: 22),
            ),
            title: Text('User not found',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.mutedText)),
          );
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};

        final name = data['name']?.toString().trim().isNotEmpty == true
            ? data['name'].toString().trim()
            : 'Unknown User';

        final avatarUrl =
            data['profilePictureUrl']?.toString() ?? '';

        final headline =
            data['headline']?.toString().trim().isNotEmpty == true
                ? data['headline'].toString().trim()
                : data['role']?.toString().trim() ?? '';

        final batchYear = data['batch']?.toString() ?? '';

        final subtitleParts = <String>[
          if (headline.isNotEmpty) headline,
          if (batchYear.isNotEmpty) 'Batch $batchYear',
        ];
        final subtitle = subtitleParts.join(' · ');

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: GestureDetector(
            onTap: () => _openProfile(context),
            child: Hero(
              tag: 'alumni_avatar_$uid',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.borderSubtle,
                child: avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          width: 52,
                          height: 52,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey.shade100),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: AppColors.brandRed),
                        ),
                      )
                    : const Icon(Icons.person, color: AppColors.brandRed),
              ),
            ),
          ),
          title: Text(name,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: subtitle.isNotEmpty
              ? Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: trailing(name),
          onTap: () => _openProfile(context),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SmallOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SmallOutlinedButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mutedText,
        side: const BorderSide(color: AppColors.borderSubtle),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.brandRed : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.brandRed
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
          radius: 26, backgroundColor: Colors.grey.shade200),
      title: Container(
        height: 13,
        width: 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          height: 11,
          width: 90,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(title,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 24, color: AppColors.darkText),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.mutedText),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, color: AppColors.darkText),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Try again', style: GoogleFonts.inter()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandRed,
                  side: const BorderSide(color: AppColors.brandRed),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
          color: AppColors.brandRed, strokeWidth: 2.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

void _showSnack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}

/// Converts FirebaseException / raw errors into human-readable messages.
String _firestoreErrorMessage(Object? error) {
  if (error == null) return 'Unknown error';
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied.\nAdd: allow read: if request.auth != null;\nto your Firestore security rules.';
      case 'unavailable':
        return 'Service temporarily unavailable. Check your internet connection.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'unauthenticated':
        return 'You must be signed in to view this.';
      default:
        return 'Firestore error (${error.code}): ${error.message ?? ''}';
    }
  }
  return error.toString();
}