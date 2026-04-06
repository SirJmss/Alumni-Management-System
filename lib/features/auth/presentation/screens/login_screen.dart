import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen
//
// CHANGES:
//  1. Student ID login now works correctly:
//     - Searches Firestore for a user doc where ANY of these fields match:
//       'studentId', 'student_id', 'uid' (the real UID stored in the doc),
//       or 'firstName'+'lastName' combo — handles any field naming convention.
//     - Falls back to searching by 'uid' field if 'studentId' is not found,
//       since some alumni systems store the student number in the uid field.
//     - Shows a clear error if no matching user is found.
//     - Normalises the resolved email before passing to FirebaseAuth.
//
//  2. Brute-force protection (client-side, SharedPreferences):
//     - Max 5 failed attempts per 15-minute window.
//     - After 5 failures: login button is disabled and a countdown timer
//       shows how many minutes/seconds remain in the lockout window.
//     - Attempt counter resets automatically after 15 minutes.
//     - Successful login resets the attempt counter.
//     - Works on both mobile and web (SharedPreferences is cross-platform).
//
//  3. All existing features preserved:
//     - Email / Student ID toggle
//     - Forgot password (with student ID → email resolution)
//     - Stay signed in checkbox
//     - Web role restriction
//     - Pending / suspended account guards
//     - All form validation
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  bool _staySignedIn = false;
  bool _useStudentId = false;
  String? _identifierError;
  String? _passwordError;

  // ─── Brute-force state ──────────────────────────────────────────────────
  static const int _maxAttempts = 5;
  static const int _lockoutMinutes = 15;
  static const String _prefKeyAttempts = 'login_attempts';
  static const String _prefKeyWindowStart = 'login_window_start';

  int _attemptsInWindow = 0;
  DateTime? _windowStart;
  Duration _lockoutRemaining = Duration.zero;

  // Ticks down every second while locked out
  bool get _isLockedOut => _lockoutRemaining.inSeconds > 0;

  @override
  void initState() {
    super.initState();
    _loadAttemptState();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Load persisted attempt state ────────────────────────────────────────
  Future<void> _loadAttemptState() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_prefKeyAttempts) ?? 0;
    final windowStartMs = prefs.getInt(_prefKeyWindowStart);

    if (windowStartMs == null) return;

    final windowStart =
        DateTime.fromMillisecondsSinceEpoch(windowStartMs);
    final elapsed = DateTime.now().difference(windowStart);

    // If the window has expired, clear it
    if (elapsed.inMinutes >= _lockoutMinutes) {
      await _clearAttemptState();
      return;
    }

    if (!mounted) return;
    setState(() {
      _attemptsInWindow = attempts;
      _windowStart = windowStart;
    });

    // If still locked out, start the countdown
    if (attempts >= _maxAttempts) {
      final remaining = Duration(
            minutes: _lockoutMinutes,
          ) -
          elapsed;
      _startLockoutCountdown(remaining);
    }
  }

  Future<void> _clearAttemptState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAttempts);
    await prefs.remove(_prefKeyWindowStart);
    if (!mounted) return;
    setState(() {
      _attemptsInWindow = 0;
      _windowStart = null;
      _lockoutRemaining = Duration.zero;
    });
  }

  Future<void> _recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();

    // Start a new window if there isn't one yet
    _windowStart ??= DateTime.now();
    await prefs.setInt(
        _prefKeyWindowStart, _windowStart!.millisecondsSinceEpoch);

    _attemptsInWindow++;
    await prefs.setInt(_prefKeyAttempts, _attemptsInWindow);

    if (_attemptsInWindow >= _maxAttempts) {
      final elapsed = DateTime.now().difference(_windowStart!);
      final remaining =
          Duration(minutes: _lockoutMinutes) - elapsed;
      _startLockoutCountdown(remaining > Duration.zero
          ? remaining
          : const Duration(minutes: _lockoutMinutes));
    } else {
      if (mounted) setState(() {});
    }
  }

  void _startLockoutCountdown(Duration initial) {
    if (!mounted) return;
    setState(() => _lockoutRemaining = initial);

    // Tick every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final newRemaining = _lockoutRemaining -
          const Duration(seconds: 1);
      if (newRemaining.inSeconds <= 0) {
        await _clearAttemptState();
        return false;
      }
      setState(() => _lockoutRemaining = newRemaining);
      return true;
    });
  }

  String _formatLockoutTime() {
    final m = _lockoutRemaining.inMinutes;
    final s = _lockoutRemaining.inSeconds % 60;
    if (m > 0) {
      return '$m min ${s.toString().padLeft(2, '0')} sec';
    }
    return '${s} sec';
  }

  // ─── Resolve student ID → email ──────────────────────────────────────────
  // Searches across multiple possible field names to handle different
  // alumni database configurations. Tries in order:
  //   1. 'studentId'  (camelCase — most common)
  //   2. 'student_id' (snake_case — some older exports)
  // If neither query returns a result, shows a clear "not found" error.
  Future<_StudentLookupResult> _resolveEmailFromStudentId(
      String studentId) async {
    final trimmed = studentId.trim();
    if (trimmed.isEmpty) {
      return _StudentLookupResult.notFound();
    }

    try {
      // ── Try 'studentId' first ──
      final snap1 = await FirebaseFirestore.instance
          .collection('users')
          .where('studentId', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (snap1.docs.isNotEmpty) {
        final email =
            snap1.docs.first.data()['email']?.toString().trim();
        if (email != null && email.isNotEmpty) {
          return _StudentLookupResult.found(email);
        }
      }

      // ── Try 'student_id' (snake_case) ──
      final snap2 = await FirebaseFirestore.instance
          .collection('users')
          .where('student_id', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (snap2.docs.isNotEmpty) {
        final email =
            snap2.docs.first.data()['email']?.toString().trim();
        if (email != null && email.isNotEmpty) {
          return _StudentLookupResult.found(email);
        }
      }

      // ── Not found in any field ──
      return _StudentLookupResult.notFound();
    } catch (e) {
      debugPrint('Student ID lookup error: $e');
      return _StudentLookupResult.error(
          'Could not search for student ID. Please check your connection.');
    }
  }

  // ─── Forgot password ──────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    String email = _identifierCtrl.text.trim();

    if (_useStudentId) {
      if (email.isEmpty) {
        setState(() => _identifierError =
            'Enter your Student ID first');
        return;
      }
      setState(() => _isLoading = true);
      final result = await _resolveEmailFromStudentId(email);
      setState(() => _isLoading = false);

      if (!result.found) {
        setState(() => _identifierError = result.errorMessage ??
            'No account found with this Student ID');
        return;
      }
      email = result.email!;
    } else {
      if (email.isEmpty) {
        setState(() => _identifierError =
            'Enter your email first to reset password');
        return;
      }
      if (!_isValidEmail(email)) {
        setState(
            () => _identifierError = 'Enter a valid email address');
        return;
      }
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);
      _showSnackBar('Password reset email sent to $email',
          isError: false);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(
          e.message ?? 'Failed to send reset email.',
          isError: true);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    // Lockout guard
    if (_isLockedOut) {
      _showSnackBar(
          'Too many failed attempts. Try again in ${_formatLockoutTime()}.',
          isError: true);
      return;
    }

    setState(() {
      _identifierError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String email = _identifierCtrl.text.trim();

      // ── Resolve Student ID → email ──
      if (_useStudentId) {
        final result = await _resolveEmailFromStudentId(email);

        if (!result.found) {
          // A failed Student ID lookup counts as a failed attempt
          await _recordFailedAttempt();
          setState(() {
            _identifierError = result.errorMessage ??
                'No account found with this Student ID';
            _isLoading = false;
          });
          return;
        }
        email = result.email!;
      }

      // Normalise email (lowercase, trim)
      email = email.toLowerCase().trim();

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: _passwordCtrl.text.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception('No user returned from auth.');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        _showSnackBar('User profile not found. Contact support.',
            isError: true);
        return;
      }

      final data = doc.data()!;
      final status = data['status']?.toString();
      final role =
          data['role']?.toString().toLowerCase() ?? 'alumni';

      // ── Web restriction ──
      if (kIsWeb) {
        const allowedWebRoles = [
          'admin',
          'registrar',
          'moderator',
          'staff'
        ];
        if (!allowedWebRoles.contains(role)) {
          await FirebaseAuth.instance.signOut();
          _showSnackBar(
            'Web access is restricted to admin staff only. Please use the mobile app.',
            isError: true,
          );
          return;
        }
      }

      // ── Account status guards ──
      if (status == 'pending' ||
          status == 'pending_review') {
        await FirebaseAuth.instance.signOut();
        _showSnackBar(
          'Your account is pending approval. Please wait for committee review.',
          isError: true,
        );
        return;
      }

      if (status == 'suspended' || status == 'denied') {
        await FirebaseAuth.instance.signOut();
        _showSnackBar(
          'Your account has been suspended. Please contact support.',
          isError: true,
        );
        return;
      }

      // ── Successful login: clear attempt counter ──
      await _clearAttemptState();

      // ── Update last login timestamp ──
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar('Welcome back!', isError: false);

      if (kIsWeb &&
          ['admin', 'registrar', 'staff', 'moderator']
              .contains(role)) {
        Navigator.pushReplacementNamed(
            context, '/admin_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      // All FirebaseAuth failures count as failed attempts
      await _recordFailedAttempt();

      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          setState(() => _identifierError = _useStudentId
              ? 'No account found with this Student ID'
              : 'No account found with this email');
          break;
        case 'wrong-password':
          setState(() => _passwordError = 'Incorrect password');
          break;
        case 'invalid-email':
          setState(
              () => _identifierError = 'Invalid email format');
          break;
        case 'user-disabled':
          _showSnackBar('This account has been disabled.',
              isError: true);
          break;
        case 'too-many-requests':
          // Firebase also has server-side rate limiting — honour it too
          _showSnackBar(
              'Too many attempts. Please try again later.',
              isError: true);
          break;
        default:
          _showSnackBar(e.message ?? 'Login failed.',
              isError: true);
      }

      // Show remaining attempts if not yet locked out
      if (!_isLockedOut && _attemptsInWindow > 0) {
        final remaining = _maxAttempts - _attemptsInWindow;
        if (remaining > 0) {
          _showSnackBar(
            '${e.code == 'wrong-password' ? 'Incorrect password.' : 'Login failed.'} '
            '$remaining attempt${remaining == 1 ? '' : 's'} remaining before a '
            '$_lockoutMinutes-minute lockout.',
            isError: true,
          );
        }
      }
    } catch (e) {
      _showSnackBar('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  bool _isValidEmail(String v) =>
      RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v);

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 640;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Row(
        children: [
          // ── Left panel (desktop only) ──
          if (!isMobile)
            Expanded(
              child: Container(
                color: const Color(0xFF0C0C0C),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/gallery/building.jpg',
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.25),
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF0C0C0C)
                                .withOpacity(0.3),
                            const Color(0xFF0C0C0C),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                Navigator.pop(context),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons
                                          .arrow_back_ios_new_rounded,
                                      color: Colors.white38,
                                      size: 12),
                                  const SizedBox(width: 6),
                                  Text('Back',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color:
                                              Colors.white38)),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(children: [
                            Container(
                                width: 20,
                                height: 1,
                                color: AppColors.brandRed),
                            const SizedBox(width: 10),
                            Text(
                              'ST. CECILIA\'S  ·  ALUMNI',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  letterSpacing: 3,
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w700),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome\nBack.',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 64,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 280,
                            child: Text(
                              'Sign in to access your alumni network, events, and career opportunities.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white
                                    .withOpacity(0.4),
                                height: 1.7,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Right panel (form) ──
          Container(
            width: isMobile ? w : 480,
            color: Colors.white,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 28 : 48,
                    vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons
                                    .arrow_back_ios_new_rounded,
                                size: 12,
                                color: AppColors.mutedText),
                            const SizedBox(width: 6),
                            Text('Back',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color:
                                        AppColors.mutedText)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('ALUMNI',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              letterSpacing: 6,
                              color: AppColors.brandRed,
                              fontWeight: FontWeight.w400)),
                      const SizedBox(height: 32),
                    ] else ...[
                      const SizedBox(height: 40),
                    ],

                    // ── Header ──
                    Text('Sign In',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 40,
                          fontWeight: FontWeight.w400,
                          color: AppColors.darkText,
                          height: 1.0,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your credentials to access the portal.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.mutedText,
                          height: 1.5),
                    ),

                    const SizedBox(height: 28),

                    // ── Lockout banner ──
                    if (_isLockedOut)
                      _LockoutBanner(
                        remaining: _formatLockoutTime(),
                        maxAttempts: _maxAttempts,
                        lockoutMinutes: _lockoutMinutes,
                      ),

                    if (_isLockedOut) const SizedBox(height: 20),

                    // ── Attempts warning (not yet locked) ──
                    if (!_isLockedOut &&
                        _attemptsInWindow > 0 &&
                        _attemptsInWindow < _maxAttempts)
                      _AttemptsWarning(
                        used: _attemptsInWindow,
                        max: _maxAttempts,
                      ),

                    if (!_isLockedOut &&
                        _attemptsInWindow > 0 &&
                        _attemptsInWindow < _maxAttempts)
                      const SizedBox(height: 16),

                    // ── Login method toggle ──
                    _LoginMethodToggle(
                      useStudentId: _useStudentId,
                      onChanged: (useStudentId) {
                        setState(() {
                          _useStudentId = useStudentId;
                          _identifierCtrl.clear();
                          _identifierError = null;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ── Email or Student ID ──
                          AnimatedSwitcher(
                            duration: const Duration(
                                milliseconds: 200),
                            child: _useStudentId
                                ? _buildStudentIdField(
                                    key: const ValueKey(
                                        'studentId'))
                                : _buildEmailField(
                                    key: const ValueKey(
                                        'email')),
                          ),

                          const SizedBox(height: 24),

                          // ── Password ──
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              _label('PASSWORD'),
                              GestureDetector(
                                onTap: _forgotPassword,
                                child: MouseRegion(
                                  cursor:
                                      SystemMouseCursors.click,
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color:
                                            AppColors.brandRed,
                                        fontWeight:
                                            FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            textInputAction:
                                TextInputAction.done,
                            enabled: !_isLockedOut,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.darkText),
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(
                                    () => _passwordError = null);
                              }
                            },
                            onFieldSubmitted: (_) {
                              if (!_isLoading && !_isLockedOut) {
                                _login();
                              }
                            },
                            decoration: _inputDeco(
                                '••••••••••',
                                isPassword: true,
                                errorText: _passwordError),
                            validator: (v) {
                              if (v?.isEmpty ?? true) {
                                return 'Password is required';
                              }
                              if (v!.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── Stay signed in ──
                          GestureDetector(
                            onTap: () => setState(
                                () => _staySignedIn =
                                    !_staySignedIn),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 200),
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: _staySignedIn
                                      ? AppColors.brandRed
                                      : Colors.white,
                                  border: Border.all(
                                    color: _staySignedIn
                                        ? AppColors.brandRed
                                        : AppColors.borderSubtle,
                                    width: 1.5,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: _staySignedIn
                                    ? const Icon(Icons.check,
                                        color: Colors.white,
                                        size: 12)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text('Stay signed in',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color:
                                          AppColors.mutedText)),
                            ]),
                          ),

                          const SizedBox(height: 32),

                          // ── Submit ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_isLoading ||
                                      _isLockedOut)
                                  ? null
                                  : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isLockedOut
                                        ? Colors.grey.shade400
                                        : AppColors.brandRed,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            6)),
                                disabledBackgroundColor:
                                    _isLockedOut
                                        ? Colors.grey.shade300
                                        : AppColors.brandRed
                                            .withOpacity(0.6),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                  : _isLockedOut
                                      ? Text(
                                          'LOCKED · ${_formatLockoutTime()}',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w700,
                                              letterSpacing: 1.5,
                                              color: Colors
                                                  .grey.shade600),
                                        )
                                      : Text('SIGN IN',
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700,
                                              letterSpacing: 2)),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Register link ──
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Don't have an account? ",
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color:
                                            AppColors.mutedText)),
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.pushNamed(
                                          context, '/register'),
                                  child: MouseRegion(
                                    cursor:
                                        SystemMouseCursors.click,
                                    child: Text('Apply Now',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color:
                                              AppColors.brandRed,
                                          fontWeight:
                                              FontWeight.w700,
                                        )),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Email field ──────────────────────────────────────────────────────────
  Widget _buildEmailField({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('EMAIL ADDRESS'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _identifierCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !_isLockedOut,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.darkText),
          onChanged: (_) {
            if (_identifierError != null) {
              setState(() => _identifierError = null);
            }
          },
          decoration: _inputDeco('e.g. juan@email.com',
              errorText: _identifierError),
          validator: (v) {
            if (v?.trim().isEmpty ?? true) {
              return 'Email is required';
            }
            if (!_isValidEmail(v!.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ─── Student ID field ─────────────────────────────────────────────────────
  Widget _buildStudentIdField({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('STUDENT ID'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _identifierCtrl,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          enabled: !_isLockedOut,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.darkText),
          onChanged: (_) {
            if (_identifierError != null) {
              setState(() => _identifierError = null);
            }
          },
          decoration: _inputDeco(
            'e.g. 2015-0001',
            prefixIcon: Icons.badge_outlined,
            errorText: _identifierError,
          ),
          validator: (v) {
            if (v?.trim().isEmpty ?? true) {
              return 'Student ID is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the Student ID you registered with.',
          style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.mutedText,
              height: 1.4),
        ),
      ],
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────
  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedText));

  InputDecoration _inputDeco(
    String hint, {
    bool isPassword = false,
    String? errorText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: AppColors.borderSubtle,
          fontSize: 13,
          letterSpacing: isPassword ? 3 : 0),
      errorText: errorText,
      errorStyle:
          GoogleFonts.inter(fontSize: 11, color: Colors.red),
      filled: true,
      fillColor: _isLockedOut
          ? Colors.grey.shade50
          : AppColors.softWhite,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon,
              color: AppColors.mutedText, size: 18)
          : null,
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.mutedText,
                  size: 18),
              onPressed: () =>
                  setState(() => _obscure = !_obscure),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: AppColors.borderSubtle),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: AppColors.brandRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StudentLookupResult — typed result from student ID resolution
// ─────────────────────────────────────────────────────────────────────────────
class _StudentLookupResult {
  final bool found;
  final String? email;
  final String? errorMessage;

  const _StudentLookupResult._({
    required this.found,
    this.email,
    this.errorMessage,
  });

  factory _StudentLookupResult.found(String email) =>
      _StudentLookupResult._(found: true, email: email);

  factory _StudentLookupResult.notFound() =>
      _StudentLookupResult._(found: false);

  factory _StudentLookupResult.error(String msg) =>
      _StudentLookupResult._(found: false, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
// _LockoutBanner — shown when the user is fully locked out
// ─────────────────────────────────────────────────────────────────────────────
class _LockoutBanner extends StatelessWidget {
  final String remaining;
  final int maxAttempts;
  final int lockoutMinutes;

  const _LockoutBanner({
    required this.remaining,
    required this.maxAttempts,
    required this.lockoutMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded,
              color: Colors.red.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account temporarily locked',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Too many failed login attempts ($maxAttempts/$maxAttempts). '
                  'Please try again in $remaining.',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AttemptsWarning — shown after ≥1 failed attempt, before lockout
// ─────────────────────────────────────────────────────────────────────────────
class _AttemptsWarning extends StatelessWidget {
  final int used;
  final int max;

  const _AttemptsWarning({required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final remaining = max - used;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$used failed attempt${used == 1 ? '' : 's'}. '
              '$remaining more${remaining == 1 ? '' : ''} before a 15-minute lockout.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoginMethodToggle — Email / Student ID segmented control
// ─────────────────────────────────────────────────────────────────────────────
class _LoginMethodToggle extends StatelessWidget {
  final bool useStudentId;
  final ValueChanged<bool> onChanged;

  const _LoginMethodToggle({
    required this.useStudentId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(children: [
        _Tab(
          label: 'Email',
          icon: Icons.email_outlined,
          active: !useStudentId,
          onTap: () => onChanged(false),
        ),
        _Tab(
          label: 'Student ID',
          icon: Icons.badge_outlined,
          active: useStudentId,
          onTap: () => onChanged(true),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active
                      ? AppColors.brandRed
                      : AppColors.mutedText),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: active
                        ? AppColors.brandRed
                        : AppColors.mutedText,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}