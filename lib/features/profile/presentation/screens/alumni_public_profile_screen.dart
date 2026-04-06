// ─────────────────────────────────────────────────────────────────────────────
// AlumniPublicProfileScreen
// FILE: lib/features/profile/presentation/screens/alumni_public_profile_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlumniPublicProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class AlumniPublicProfileScreen extends StatefulWidget {
  final String uid;
  const AlumniPublicProfileScreen({super.key, required this.uid});

  @override
  State<AlumniPublicProfileScreen> createState() =>
      _AlumniPublicProfileScreenState();
}

class _AlumniPublicProfileScreenState
    extends State<AlumniPublicProfileScreen> {
  final _db = FirebaseFirestore.instance;

  late final String _currentUid;

  bool _connectLoading = false;
  bool _followLoading = false;

  bool _isConnected = false;
  bool _requestPending = false;
  bool _requestReceived = false;
  bool _isFollowing = false;
  bool _relationshipReady = false;

  bool get _isOwnProfile =>
      _currentUid.isNotEmpty && _currentUid == widget.uid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // ─── Guard ────────────────────────────────────────────────────────────────
  bool _canAct(String action) {
    if (_currentUid.isEmpty) {
      _showSnack('Sign in to $action', Colors.orange.shade700);
      return false;
    }
    if (_isOwnProfile) return false;
    return true;
  }

  // ─── Connection dispatcher ────────────────────────────────────────────────
  Future<void> _handleConnect() async {
    if (!_canAct('connect') || _connectLoading) return;
    setState(() => _connectLoading = true);
    try {
      if (_isConnected) {
        await _unfriend();
      } else if (_requestPending) {
        await _cancelRequest();
      } else if (_requestReceived) {
        await _acceptRequest();
      } else {
        await _sendRequest();
      }
    } catch (e) {
      _showSnack(_friendlyError(e), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  // ─── Send request ─────────────────────────────────────────────────────────
  // FIX: The old code used .get() on the friend_requests doc for pre-flight
  // checks. The Firestore rule's `allow get` requires resource.data.fromUid or
  // resource.data.toUid — but resource is NULL when the document doesn't exist,
  // which causes permission-denied on pre-flight reads of non-existent docs.
  //
  // FIX: Replaced individual .get() pre-flight checks with a single
  // .collection().where().limit(1).get() list query, which uses the `allow list`
  // rule (open to all authenticated users) instead of `allow get`.
  // This avoids the resource=null crash entirely.
  Future<void> _sendRequest() async {
    // Check for existing outgoing request via list query (avoids get rule)
    final outSnap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: _currentUid)
        .where('toUid', isEqualTo: widget.uid)
        .limit(1)
        .get();
    if (outSnap.docs.isNotEmpty) {
      _showSnack('Request already sent.', Colors.orange.shade700);
      return;
    }

    // Check for existing incoming request
    final inSnap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: widget.uid)
        .where('toUid', isEqualTo: _currentUid)
        .limit(1)
        .get();
    if (inSnap.docs.isNotEmpty) {
      _showSnack('They already sent you a request — accept it instead.',
          Colors.orange.shade700);
      return;
    }

    // Check if already connected
    final connDoc = await _db
        .collection('users')
        .doc(_currentUid)
        .collection('connections')
        .doc(widget.uid)
        .get();
    if (connDoc.exists) {
      _showSnack('You are already connected.', Colors.green.shade700);
      return;
    }

    await _db
        .collection('friend_requests')
        .doc('${_currentUid}_${widget.uid}')
        .set({
      'fromUid': _currentUid,
      'toUid': widget.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _showSnack('Connection request sent!', Colors.green.shade700);
  }

  // ─── Cancel request ───────────────────────────────────────────────────────
  Future<void> _cancelRequest() async {
    final ok = await _confirm(
      title: 'Cancel Request',
      body: 'Withdraw your pending connection request?',
      confirmLabel: 'Withdraw',
    );
    if (ok != true) return;

    await _db
        .collection('friend_requests')
        .doc('${_currentUid}_${widget.uid}')
        .delete();

    _showSnack('Request withdrawn', Colors.grey.shade700);
  }

  // ─── Accept request ───────────────────────────────────────────────────────
  // FIX: Same as sendRequest — use list query instead of .get() on the
  // friend_requests doc to avoid the resource=null permission-denied error.
  Future<void> _acceptRequest() async {
    final reqSnap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: widget.uid)
        .where('toUid', isEqualTo: _currentUid)
        .limit(1)
        .get();

    if (reqSnap.docs.isEmpty) {
      _showSnack('Request no longer available.', Colors.orange.shade700);
      return;
    }

    final reqDocId = reqSnap.docs.first.id;

    final existingConn = await _db
        .collection('users')
        .doc(_currentUid)
        .collection('connections')
        .doc(widget.uid)
        .get();
    if (existingConn.exists) {
      await _db.collection('friend_requests').doc(reqDocId).delete();
      _showSnack('Already connected!', Colors.green.shade700);
      return;
    }

    final now = FieldValue.serverTimestamp();
    final wb = _db.batch();

    wb.set(
      _db.collection('users').doc(_currentUid).collection('connections').doc(widget.uid),
      {'connectedAt': now, 'uid': widget.uid},
    );
    wb.set(
      _db.collection('users').doc(widget.uid).collection('connections').doc(_currentUid),
      {'connectedAt': now, 'uid': _currentUid},
    );
    wb.delete(_db.collection('friend_requests').doc(reqDocId));
    wb.update(_db.collection('users').doc(_currentUid),
        {'connectionsCount': FieldValue.increment(1)});
    wb.update(_db.collection('users').doc(widget.uid),
        {'connectionsCount': FieldValue.increment(1)});

    await wb.commit();
    _showSnack('Connected!', Colors.green.shade700);
  }

  // ─── Unfriend ─────────────────────────────────────────────────────────────
  Future<void> _unfriend() async {
    final ok = await _confirm(
      title: 'Remove Connection',
      body: "Remove this person from your connections? They won't be notified.",
      confirmLabel: 'Remove',
    );
    if (ok != true) return;

    final results = await Future.wait([
      _db.collection('users').doc(_currentUid).get(),
      _db.collection('users').doc(widget.uid).get(),
    ]);

    final myCount = _safeInt(results[0].data()?['connectionsCount']);
    final theirCount = _safeInt(results[1].data()?['connectionsCount']);

    final wb = _db.batch();
    wb.delete(_db.collection('users').doc(_currentUid).collection('connections').doc(widget.uid));
    wb.delete(_db.collection('users').doc(widget.uid).collection('connections').doc(_currentUid));

    if (myCount > 0) {
      wb.update(_db.collection('users').doc(_currentUid),
          {'connectionsCount': FieldValue.increment(-1)});
    }
    if (theirCount > 0) {
      wb.update(_db.collection('users').doc(widget.uid),
          {'connectionsCount': FieldValue.increment(-1)});
    }

    await wb.commit();
    _showSnack('Connection removed', Colors.grey.shade700);
  }

  // ─── Follow / Unfollow ────────────────────────────────────────────────────
  Future<void> _handleFollow() async {
    if (!_canAct('follow') || _followLoading) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await _unfollowUser();
      } else {
        await _followUser();
      }
    } catch (e) {
      _showSnack(_friendlyError(e), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _followUser() async {
    final existingFollow = await _db
        .collection('users')
        .doc(_currentUid)
        .collection('following')
        .doc(widget.uid)
        .get();
    if (existingFollow.exists) {
      _showSnack('Already following.', Colors.orange.shade700);
      return;
    }

    final now = FieldValue.serverTimestamp();
    final wb = _db.batch();

    wb.set(
      _db.collection('users').doc(_currentUid).collection('following').doc(widget.uid),
      {'followedAt': now, 'uid': widget.uid},
    );
    wb.set(
      _db.collection('users').doc(widget.uid).collection('followers').doc(_currentUid),
      {'followedAt': now, 'uid': _currentUid},
    );
    wb.update(_db.collection('users').doc(_currentUid),
        {'followingCount': FieldValue.increment(1)});
    wb.update(_db.collection('users').doc(widget.uid),
        {'followersCount': FieldValue.increment(1)});

    await wb.commit();
    _showSnack('Following!', Colors.green.shade700);
  }

  Future<void> _unfollowUser() async {
    final results = await Future.wait([
      _db.collection('users').doc(_currentUid).get(),
      _db.collection('users').doc(widget.uid).get(),
    ]);

    final myFollowingCount = _safeInt(results[0].data()?['followingCount']);
    final theirFollowersCount = _safeInt(results[1].data()?['followersCount']);

    final wb = _db.batch();
    wb.delete(_db.collection('users').doc(_currentUid).collection('following').doc(widget.uid));
    wb.delete(_db.collection('users').doc(widget.uid).collection('followers').doc(_currentUid));

    if (myFollowingCount > 0) {
      wb.update(_db.collection('users').doc(_currentUid),
          {'followingCount': FieldValue.increment(-1)});
    }
    if (theirFollowersCount > 0) {
      wb.update(_db.collection('users').doc(widget.uid),
          {'followersCount': FieldValue.increment(-1)});
    }

    await wb.commit();
    _showSnack('Unfollowed', Colors.grey.shade700);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    if (!mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(body, style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: GoogleFonts.inter(
                    color: AppColors.brandRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Permission denied. Check your Firestore security rules.';
        case 'unavailable':
          return 'Service unavailable. Check your internet connection.';
        case 'not-found':
          return 'Data not found.';
        case 'unauthenticated':
          return 'Please sign in to perform this action.';
        default:
          return 'Error (${e.code}): ${e.message ?? ''}';
      }
    }
    return e.toString();
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.uid.trim().isEmpty) {
      return Scaffold(
        appBar: _simpleAppBar('Profile'),
        body: const Center(child: Text('Invalid user ID.')),
      );
    }
    if (_currentUid.isEmpty) {
      return Scaffold(
        appBar: _simpleAppBar('Profile'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Sign in to view profiles',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: _db.collection('users').doc(widget.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _buildErrorScaffold(snapshot.error);
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScaffold();
              }
              if (!snapshot.hasData ||
                  snapshot.data == null ||
                  !snapshot.data!.exists) {
                return _buildNotFoundScaffold();
              }
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              return _buildProfileScaffold(data);
            },
          ),
          _RelationshipWatcher(
            currentUid: _currentUid,
            otherUid: widget.uid,
            onChanged: ({
              required bool connected,
              required bool pendingOut,
              required bool pendingIn,
              required bool following,
              required bool ready,
            }) {
              if (!mounted) return;
              setState(() {
                _isConnected = connected;
                _requestPending = pendingOut;
                _requestReceived = pendingIn;
                _isFollowing = following;
                _relationshipReady = ready;
              });
            },
          ),
        ],
      ),
    );
  }

  // ─── Scaffold variants ────────────────────────────────────────────────────
  AppBar _simpleAppBar(String title) => AppBar(
        title: Text(title, style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        foregroundColor: AppColors.darkText,
      );

  Widget _buildLoadingScaffold() => Scaffold(
        backgroundColor: AppColors.softWhite,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            foregroundColor: AppColors.darkText,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(background: _defaultCover()),
          ),
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2.5),
            ),
          ),
        ]),
      );

  Widget _buildErrorScaffold(Object? error) => Scaffold(
        backgroundColor: AppColors.softWhite,
        appBar: _simpleAppBar('Profile'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Could not load profile',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 22, color: AppColors.darkText)),
                const SizedBox(height: 8),
                Text(
                  error is FirebaseException && error.code == 'permission-denied'
                      ? 'Permission denied.\nEnsure your Firestore rules allow authenticated reads on /users/{userId}.'
                      : _friendlyError(error ?? 'Unknown error'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildNotFoundScaffold() => Scaffold(
        backgroundColor: AppColors.softWhite,
        appBar: _simpleAppBar('Profile'),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Profile not found',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text('This account may have been deleted.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText)),
          ]),
        ),
      );

  // ─── Main profile scaffold ────────────────────────────────────────────────
  Widget _buildProfileScaffold(Map<String, dynamic> data) {
    // ── Read all fields from the real Firestore schema ──
    final firstName = _safe(data, 'firstName');
    final lastName = _safe(data, 'lastName');
    // 'name' is the full display name; fall back to firstName+lastName
    final name = _safe(
      data,
      'name',
      fallback: [firstName, lastName]
              .where((s) => s.isNotEmpty)
              .join(' ')
              .trim()
              .isNotEmpty
          ? [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim()
          : 'Unknown User',
    );

    // Resolve URLs from multiple possible keys & ignore obvious invalid values
    String resolveUrl(List<String> keys) {
      for (final k in keys) {
        final raw = data[k]?.toString().trim() ?? '';
        if (raw.isNotEmpty &&
            raw.toLowerCase() != 'null' &&
            raw.toLowerCase() != 'undefined') {
          return raw;
        }
      }
      return '';
    }

    final avatarUrl =
        resolveUrl(['profilePictureUrl', 'photoURL', 'avatarUrl']);
    final coverUrl =
        resolveUrl(['coverPhotoUrl', 'coverPictureUrl', 'cover']);
    final headline = _safe(data, 'headline', fallback: _safe(data, 'role'));
    final about = _safe(data, 'about'); // real field name (not 'bio')
    final location = _safe(data, 'location');
    final role = _safe(data, 'role');
    final status = _safe(data, 'status');
    final phone = _safe(data, 'phone_number');    // real field name

    // experience & education are arrays of maps
    final experience = _safeList(data, 'experience');
    final education = _safeList(data, 'education');

    final connectionsCount = _safeInt(data['connectionsCount']);
    final followersCount = _safeInt(data['followersCount']);
    final followingCount = _safeInt(data['followingCount']);

    // Connect button state
    final String connectLabel;
    final Color connectBg;
    final IconData connectIcon;
    final bool connectOutlined;

    if (_isConnected) {
      connectLabel = 'Connected';
      connectBg = Colors.green.shade600;
      connectIcon = Icons.how_to_reg_rounded;
      connectOutlined = true;
    } else if (_requestPending) {
      connectLabel = 'Pending…';
      connectBg = Colors.orange.shade700;
      connectIcon = Icons.schedule_rounded;
      connectOutlined = true;
    } else if (_requestReceived) {
      connectLabel = 'Accept';
      connectBg = Colors.blue.shade700;
      connectIcon = Icons.person_add_alt_1_rounded;
      connectOutlined = false;
    } else {
      connectLabel = 'Connect';
      connectBg = AppColors.brandRed;
      connectIcon = Icons.person_add_alt_1_rounded;
      connectOutlined = false;
    }

    // Layout constants (mirror own-profile screen)
    const double avatarRadius = 52.0;
    const double avatarBorder = 4.0;
    const double coverHeight = 210.0;
    const double avatarTotal = avatarRadius + avatarBorder;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // ── Cover + App Bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: coverHeight,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.cardWhite,
            foregroundColor: AppColors.darkText,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _defaultCover(),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.35),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _defaultCover(),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + Action Buttons ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar — slightly overlaps cover, consistent with own profile
                      Transform.translate(
                        offset: const Offset(0, -avatarTotal * 0.6),
                        child: Hero(
                          tag: 'alumni_avatar_${widget.uid}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.softWhite,
                                  width: avatarBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              color: AppColors.cardWhite,
                            ),
                            child: CircleAvatar(
                              radius: avatarRadius,
                              backgroundColor: AppColors.borderSubtle,
                              child: avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        width: avatarRadius * 2,
                                        height: avatarRadius * 2,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            Container(color: Colors.grey.shade100),
                                        errorWidget: (_, __, ___) => const Icon(
                                            Icons.person,
                                            size: 52,
                                            color: AppColors.brandRed),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 52,
                                      color: AppColors.brandRed,
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Action buttons — shown only when not own profile
                      if (!_isOwnProfile)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: !_relationshipReady
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.brandRed),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ActionButton(
                                      label:
                                          _isFollowing ? 'Following' : 'Follow',
                                      icon: _isFollowing
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_rounded,
                                      color: _isFollowing
                                          ? Colors.blue.shade700
                                          : AppColors.mutedText,
                                      outlined: true,
                                      loading: _followLoading,
                                      onPressed: _handleFollow,
                                    ),
                                    const SizedBox(width: 8),
                                    _ActionButton(
                                      label: connectLabel,
                                      icon: connectIcon,
                                      color: connectBg,
                                      outlined: connectOutlined,
                                      loading: _connectLoading,
                                      onPressed: _handleConnect,
                                    ),
                                  ],
                                ),
                        ),
                    ],
                  ),
                ),

                // Extra spacing to account for avatar overlap
                const SizedBox(height: avatarTotal * 0.6),

                // ── Name + Role + Verification Badge ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + verified badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (status == 'verified') ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Verified Alumni',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.brandRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.brandRed.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_rounded,
                                        size: 12, color: AppColors.brandRed),
                                    const SizedBox(width: 3),
                                    Text('Verified',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.brandRed)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(headline,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.darkText.withOpacity(0.75))),
                      ],

                      const SizedBox(height: 8),

                      // Meta chips row
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (location.isNotEmpty)
                            _MetaChip(
                                icon: Icons.location_on_outlined,
                                text: location),
                          if (role.isNotEmpty)
                            _MetaChip(
                                icon: Icons.school_outlined,
                                text: role[0].toUpperCase() + role.substring(1)),
                          if (phone.isNotEmpty)
                            _MetaChip(
                                icon: Icons.phone_outlined, text: phone),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── Stats Row ──────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _StatItem(count: connectionsCount, label: 'Connections'),
                      _StatDivider(),
                      _StatItem(count: followersCount, label: 'Followers'),
                      _StatDivider(),
                      _StatItem(count: followingCount, label: 'Following'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── About ──────────────────────────────────────────────────
                if (about.isNotEmpty) ...[
                  _ProfileCard(
                    title: 'About',
                    icon: Icons.person_outline_rounded,
                    child: Text(
                      about,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.darkText.withOpacity(0.85),
                          height: 1.65),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Experience ─────────────────────────────────────────────
                if (experience.isNotEmpty) ...[
                  _ProfileCard(
                    title: 'Experience',
                    icon: Icons.work_outline_rounded,
                    child: Column(
                      children: experience.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final exp = entry.value;
                        return Column(
                          children: [
                            if (idx > 0) ...[
                              const SizedBox(height: 4),
                              Divider(
                                  height: 24,
                                  color: AppColors.borderSubtle
                                      .withOpacity(0.6)),
                            ],
                            _ExperienceItem(exp: exp),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Education ──────────────────────────────────────────────
                if (education.isNotEmpty) ...[
                  _ProfileCard(
                    title: 'Education',
                    icon: Icons.school_outlined,
                    child: Column(
                      children: education.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final edu = entry.value;
                        return Column(
                          children: [
                            if (idx > 0) ...[
                              const SizedBox(height: 4),
                              Divider(
                                  height: 24,
                                  color: AppColors.borderSubtle
                                      .withOpacity(0.6)),
                            ],
                            _EducationItem(edu: edu),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Career Milestones ──────────────────────────────────────
                _CareerSection(uid: widget.uid),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Static helpers ───────────────────────────────────────────────────────
  static String _safe(Map<String, dynamic> data, String key,
      {String fallback = ''}) {
    final v = data[key]?.toString().trim();
    return (v != null && v.isNotEmpty) ? v : fallback;
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _safeList(
      Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _defaultCover() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B0000), Color(0xFFB22222), Color(0xFFCC4444)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _RelationshipWatcher — stream subscriptions, zero layout impact
// ─────────────────────────────────────────────────────────────────────────────
class _RelationshipWatcher extends StatefulWidget {
  final String currentUid;
  final String otherUid;
  final void Function({
    required bool connected,
    required bool pendingOut,
    required bool pendingIn,
    required bool following,
    required bool ready,
  }) onChanged;

  const _RelationshipWatcher({
    required this.currentUid,
    required this.otherUid,
    required this.onChanged,
  });

  @override
  State<_RelationshipWatcher> createState() => _RelationshipWatcherState();
}

class _RelationshipWatcherState extends State<_RelationshipWatcher> {
  final _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _connSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _outSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _followSub;

  bool _connReady = false;
  bool _outReady = false;
  bool _inReady = false;
  bool _followReady = false;

  bool _connected = false;
  bool _pendingOut = false;
  bool _pendingIn = false;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_RelationshipWatcher old) {
    super.didUpdateWidget(old);
    if (old.currentUid != widget.currentUid ||
        old.otherUid != widget.otherUid) {
      _unsubscribe();
      _resetState();
      _subscribe();
    }
  }

  void _resetState() {
    _connReady = false;
    _outReady = false;
    _inReady = false;
    _followReady = false;
    _connected = false;
    _pendingOut = false;
    _pendingIn = false;
    _following = false;
  }

  void _subscribe() {
    if (widget.currentUid.isEmpty || widget.otherUid.isEmpty) return;

    _connSub = _db
        .collection('users')
        .doc(widget.currentUid)
        .collection('connections')
        .doc(widget.otherUid)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> s) {
      _connected = s.exists;
      _connReady = true;
      _notify();
    }, onError: (_) {
      _connReady = true;
      _notify();
    });

    // Use list queries for friend_requests to align with Firestore rules.
    _outSub = _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: widget.currentUid)
        .where('toUid', isEqualTo: widget.otherUid)
        .limit(1)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> s) {
      _pendingOut = s.docs.isNotEmpty;
      _outReady = true;
      _notify();
    }, onError: (_) {
      _outReady = true;
      _notify();
    });

    _inSub = _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: widget.otherUid)
        .where('toUid', isEqualTo: widget.currentUid)
        .limit(1)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> s) {
      _pendingIn = s.docs.isNotEmpty;
      _inReady = true;
      _notify();
    }, onError: (_) {
      _inReady = true;
      _notify();
    });

    _followSub = _db
        .collection('users')
        .doc(widget.currentUid)
        .collection('following')
        .doc(widget.otherUid)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> s) {
      _following = s.exists;
      _followReady = true;
      _notify();
    }, onError: (_) {
      _followReady = true;
      _notify();
    });
  }

  void _notify() {
    if (!mounted) return;
    widget.onChanged(
      connected: _connected,
      pendingOut: _pendingOut,
      pendingIn: _pendingIn,
      following: _following,
      ready: _connReady && _outReady && _inReady && _followReady,
    );
  }

  void _unsubscribe() {
    _connSub?.cancel();
    _outSub?.cancel();
    _inSub?.cancel();
    _followSub?.cancel();
    _connSub = null;
    _outSub = null;
    _inSub = null;
    _followSub = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// _CareerSection
// ─────────────────────────────────────────────────────────────────────────────
class _CareerSection extends StatelessWidget {
  final String uid;
  const _CareerSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('career_milestones')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('_CareerSection error: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: [
            _ProfileCard(
              title: 'Career Milestones',
              icon: Icons.emoji_events_outlined,
              child: Column(
                children: docs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final d = entry.value.data() as Map<String, dynamic>? ?? {};
                  final title = d['title']?.toString() ?? '';
                  final company = d['company']?.toString() ?? '';
                  final year = d['year']?.toString() ?? '';
                  if (title.isEmpty && company.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      if (idx > 0)
                        Divider(
                            height: 24,
                            color: AppColors.borderSubtle.withOpacity(0.6)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _IconBox(icon: Icons.work_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title.isNotEmpty)
                                  Text(title,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkText)),
                                if (company.isNotEmpty)
                                  Text(company,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.brandRed,
                                          fontWeight: FontWeight.w500)),
                                if (year.isNotEmpty)
                                  Text(year,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.mutedText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExperienceItem — renders one experience map from the experience array
// ─────────────────────────────────────────────────────────────────────────────
class _ExperienceItem extends StatelessWidget {
  final Map<String, dynamic> exp;
  const _ExperienceItem({required this.exp});

  @override
  Widget build(BuildContext context) {
    final title = exp['title']?.toString() ?? '';
    final company = exp['company']?.toString() ?? '';
    final location = exp['location']?.toString() ?? '';
    final description = exp['description']?.toString() ?? '';
    final start = exp['start'];
    final end = exp['end'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconBox(icon: Icons.work_outline_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
              if (company.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(company,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 3),
              Text(
                _formatPeriod(start, end),
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.mutedText),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(location,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.mutedText)),
                  ),
                ]),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.darkText.withOpacity(0.8),
                        height: 1.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    if (end == null) return '$s – Present';
    return '$s – ${_formatDate(end)}';
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    DateTime? d = v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v.toString());
    return d != null ? DateFormat('MMM yyyy').format(d) : '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EducationItem — renders one education map
// ─────────────────────────────────────────────────────────────────────────────
class _EducationItem extends StatelessWidget {
  final Map<String, dynamic> edu;
  const _EducationItem({required this.edu});

  @override
  Widget build(BuildContext context) {
    final degree = edu['degree']?.toString() ?? '';
    final school = edu['school']?.toString() ?? '';
    final fieldOfStudy = edu['fieldOfStudy']?.toString() ?? '';
    final grade = edu['grade']?.toString() ?? '';
    final start = edu['start'];
    final end = edu['end'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconBox(icon: Icons.school_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (degree.isNotEmpty)
                Text(degree,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
              if (school.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(school,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 3),
              Text(
                _formatPeriod(start, end),
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText),
              ),
              if (fieldOfStudy.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(fieldOfStudy,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.mutedText)),
              ],
              if (grade.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.military_tech_outlined,
                          size: 12, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(grade,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    if (end == null) return s.isNotEmpty ? '$s – Present' : '';
    final e = _formatDate(end);
    return (s.isNotEmpty || e.isNotEmpty) ? '$s – $e' : '';
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    DateTime? d = v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v.toString());
    return d != null ? DateFormat('MMM yyyy').format(d) : '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable design widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Elevated card section with icon + title header
class _ProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _ProfileCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: AppColors.brandRed),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Inline icon + text metadata chip
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
      ],
    );
  }
}

/// Stats card cell
class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  const _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(_fmt(count),
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 32,
        width: 1,
        color: AppColors.borderSubtle);
  }
}

/// Coloured icon box used in experience/education/milestone rows
class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.brandRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.brandRed, size: 20),
    );
  }
}

/// Connect/Follow action button
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool loading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.outlined,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);

    final Widget content = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? color : Colors.white,
            ),
          )
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ]);

    return outlined
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: padding,
              shape: shape,
            ),
            onPressed: loading ? null : onPressed,
            child: content,
          )
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: padding,
              shape: shape,
            ),
            onPressed: loading ? null : onPressed,
            child: content,
          );
  }
}