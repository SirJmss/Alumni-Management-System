import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/profile/presentation/screens/alumni_public_profile_screen.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlumniSearchScreen
//
// CHANGES vs original:
//  - Removed the duplicate AlumniPublicProfileScreen class that was defined
//    inside this file (it is now imported from alumni_public_profile_screen.dart)
//  - currentUid is null-safe: uses ?. and shows auth-guard UI instead of
//    force-unwrapping with ! (which throws if called before auth state emits)
//  - Search now filters client-side on lowercased name AND batch year
//  - Added debounce to avoid firing a Firestore read on every keystroke
//  - Loading and empty states are distinguished (no query vs no results)
//  - Error handling added to search + chat creation
//  - _getOrCreateChat validates UIDs before touching Firestore
//  - Navigator uses push instead of pushReplacement so the back button works
// ─────────────────────────────────────────────────────────────────────────────
class AlumniSearchScreen extends StatefulWidget {
  const AlumniSearchScreen({super.key});

  @override
  State<AlumniSearchScreen> createState() => _AlumniSearchScreenState();
}

class _AlumniSearchScreenState extends State<AlumniSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  String? _startingChatFor;
  String? _errorMessage;

  // Null-safe: guard against calling this before FirebaseAuth emits
  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  // Simple debounce — avoids Firestore read on every keystroke
  DateTime _lastSearchTime = DateTime(0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _errorMessage = null;
        });
      }
      return;
    }

    // Debounce: skip if another call will follow within 300 ms
    _lastSearchTime = DateTime.now();
    final thisCallTime = _lastSearchTime;
    await Future.delayed(const Duration(milliseconds: 300));
    if (_lastSearchTime != thisCallTime) return;

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // Guard: must be authenticated to read Firestore
      if (_currentUid.isEmpty) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _errorMessage = 'You must be signed in to search.';
          });
        }
        return;
      }

      final q = trimmed.toLowerCase();

      // Fetch all users (up to 500) and filter client-side.
      // For larger datasets, replace with a server-side full-text solution
      // such as Algolia or a Cloud Function with a search index.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(500)
          .get();

      final filtered = snapshot.docs
          .where((d) => d.id != _currentUid)
          .where((d) {
            final data = d.data();
            // Match on name
            final name = data['name']?.toString().toLowerCase() ?? '';
            // Also match on batch year so "2020" finds batch alumni
            final batch = data['batch']?.toString().toLowerCase() ?? '';
            // Also match on headline / role
            final headline =
                data['headline']?.toString().toLowerCase() ?? '';
            final role = data['role']?.toString().toLowerCase() ?? '';
            return name.contains(q) ||
                batch.contains(q) ||
                headline.contains(q) ||
                role.contains(q);
          })
          .map((d) => {'uid': d.id, ...d.data()})
          .toList()
        // Sort by relevance: exact name-start matches first
        ..sort((a, b) {
          final aName = (a['name']?.toString().toLowerCase() ?? '');
          final bName = (b['name']?.toString().toLowerCase() ?? '');
          final aStarts = aName.startsWith(q) ? 0 : 1;
          final bStarts = bName.startsWith(q) ? 0 : 1;
          if (aStarts != bStarts) return aStarts - bStarts;
          return aName.compareTo(bName);
        });

      if (mounted) {
        setState(() {
          _results = filtered;
          _isSearching = false;
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = _friendlyFirestoreError(e);
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Search failed. Please try again.';
        });
      }
    }
  }

  // ─── Chat helpers ─────────────────────────────────────────────────────────

  Future<String> _getOrCreateChat(String otherUid) async {
    if (_currentUid.isEmpty) throw Exception('Not authenticated.');
    if (otherUid.isEmpty) throw Exception('Invalid user ID.');
    if (otherUid == _currentUid) throw Exception('Cannot chat with yourself.');

    // Look for existing chat that contains both UIDs
    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('memberIds', arrayContains: _currentUid)
        .get();

    for (final doc in existing.docs) {
      final members =
          List<String>.from(doc.data()['memberIds'] ?? []);
      if (members.contains(otherUid)) return doc.id;
    }

    // Create new chat
    final ref = await FirebaseFirestore.instance.collection('chats').add({
      'memberIds': [_currentUid, otherUid],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {_currentUid: 0, otherUid: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> _startChat(
      String otherUid, String otherName, String otherAvatarUrl) async {
    if (otherUid.isEmpty) return;
    if (_currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please sign in to start a chat.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _startingChatFor = otherUid);
    try {
      final chatId = await _getOrCreateChat(otherUid);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUid: otherUid,
            otherName: otherName.isNotEmpty ? otherName : 'User',
            otherAvatarUrl: otherAvatarUrl,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyFirestoreError(e)),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _startingChatFor = null);
    }
  }

  // ─── Error message helper ─────────────────────────────────────────────────
  String _friendlyFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Check your Firestore security rules.';
      case 'unavailable':
        return 'Service unavailable. Check your internet connection.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'Error (${e.code}): ${e.message ?? ''}';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Auth guard — if somehow unauthenticated, show safe message
    if (_currentUid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          title: Text('Search Alumni',
              style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Please sign in to search alumni.',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.mutedText)),
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
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by name, batch, role…',
            hintStyle:
                GoogleFonts.inter(color: AppColors.mutedText, fontSize: 15),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          style: GoogleFonts.inter(fontSize: 15),
          onChanged: _search,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _results = [];
                  _errorMessage = null;
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.brandRed));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Something went wrong',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _search(_searchController.text),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Retry', style: GoogleFonts.inter()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandRed,
                  side: const BorderSide(color: AppColors.brandRed),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return _EmptyState(hasQuery: _searchController.text.isNotEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.borderSubtle),
      itemBuilder: (context, index) {
        final user = _results[index];
        final uid = user['uid']?.toString() ?? '';
        if (uid.isEmpty) return const SizedBox.shrink();

        final name =
            user['name']?.toString().trim().isNotEmpty == true
                ? user['name'].toString().trim()
                : 'Unknown User';
        final avatarUrl =
            user['profilePictureUrl']?.toString() ?? '';
        final headline =
            user['headline']?.toString().trim().isNotEmpty == true
                ? user['headline'].toString().trim()
                : user['role']?.toString().trim() ?? '';
        final batchYear = user['batch']?.toString() ?? '';
        final subtitleParts = <String>[
          if (headline.isNotEmpty) headline,
          if (batchYear.isNotEmpty) 'Batch $batchYear',
        ];
        final subtitle = subtitleParts.join(' · ');

        final isStarting = _startingChatFor == uid;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: GestureDetector(
            onTap: () => _openProfile(context, uid),
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
                      fontSize: 13, color: AppColors.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: isStarting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.brandRed))
              : IconButton(
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: AppColors.brandRed),
                  tooltip: 'Message $name',
                  onPressed: () => _startChat(uid, name, avatarUrl),
                ),
          onTap: () => _openProfile(context, uid),
        );
      },
    );
  }

  void _openProfile(BuildContext context, String uid) {
    if (uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlumniPublicProfileScreen(uid: uid),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No alumni found' : 'Search for alumni',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 24, color: AppColors.darkText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different name, batch year, or role'
                  : 'Type a name to find and connect with alumni',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}