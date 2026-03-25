import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // email OR student ID
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  bool _staySignedIn = false;
  bool _useStudentId = false; // toggle between email / student ID login
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  LOOK UP EMAIL FROM STUDENT ID
  // ══════════════════════════════════════════

  /// Queries Firestore for a user whose studentId matches
  /// the provided value. Returns the email string or null.
  Future<String?> _resolveEmailFromStudentId(
      String studentId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('studentId', isEqualTo: studentId.trim())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      return data['email']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════
  //  FORGOT PASSWORD
  // ══════════════════════════════════════════

  Future<void> _forgotPassword() async {
    // If using student ID, we need to resolve the email first
    String email = _identifierCtrl.text.trim();

    if (_useStudentId) {
      if (email.isEmpty) {
        setState(() =>
            _identifierError = 'Enter your Student ID first');
        return;
      }
      setState(() => _isLoading = true);
      final resolved = await _resolveEmailFromStudentId(email);
      setState(() => _isLoading = false);
      if (resolved == null) {
        setState(() => _identifierError =
            'No account found with this Student ID');
        return;
      }
      email = resolved;
    } else {
      if (email.isEmpty) {
        setState(() =>
            _identifierError = 'Enter your email first to reset password');
        return;
      }
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
          .hasMatch(email)) {
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
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════
  //  LOGIN
  // ══════════════════════════════════════════

  Future<void> _login() async {
    setState(() {
      _identifierError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String email = _identifierCtrl.text.trim();

      // ─── Resolve Student ID → email ───
      if (_useStudentId) {
        final resolved =
            await _resolveEmailFromStudentId(email);
        if (resolved == null) {
          setState(() {
            _identifierError =
                'No account found with this Student ID';
            _isLoading = false;
          });
          return;
        }
        email = resolved;
      }

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: _passwordCtrl.text.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception('No user returned');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        _showSnackBar('User profile not found.',
            isError: true);
        return;
      }

      final data = doc.data()!;
      final status = data['status']?.toString();
      final role =
          data['role']?.toString().toLowerCase() ?? 'alumni';

      // ─── Web restriction ───
      if (kIsWeb) {
        final allowedRoles = [
          'admin',
          'registrar',
          'moderator',
          'staff'
        ];
        if (!allowedRoles.contains(role)) {
          await FirebaseAuth.instance.signOut();
          _showSnackBar(
            'Web access is restricted to admin staff only. Please use the mobile app.',
            isError: true,
          );
          return;
        }
      }

      // ─── Pending account ───
      if (status == 'pending' ||
          status == 'pending_review') {
        await FirebaseAuth.instance.signOut();
        _showSnackBar(
          'Your account is pending approval. Please wait for committee review.',
          isError: true,
        );
        return;
      }

      // ─── Suspended account ───
      if (status == 'suspended' || status == 'denied') {
        await FirebaseAuth.instance.signOut();
        _showSnackBar(
          'Your account has been suspended. Please contact support.',
          isError: true,
        );
        return;
      }

      // ─── Update last login ───
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
        Navigator.pushReplacementNamed(
            context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          setState(() => _identifierError =
              _useStudentId
                  ? 'No account found with this Student ID'
                  : 'No account found with this email');
          break;
        case 'wrong-password':
          setState(
              () => _passwordError = 'Incorrect password');
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
          _showSnackBar(
              'Too many attempts. Please try again later.',
              isError: true);
          break;
        default:
          _showSnackBar(
              e.message ?? 'Login failed', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 640;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Row(
        children: [
          // ─── Left panel (desktop only) ───
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
                      opacity:
                          const AlwaysStoppedAnimation(0.25),
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
                          // ─── Back ───
                          GestureDetector(
                            onTap: () =>
                                Navigator.pop(context),
                            child: MouseRegion(
                              cursor:
                                  SystemMouseCursors.click,
                              child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons
                                            .arrow_back_ios_new_rounded,
                                        color: Colors.white38,
                                        size: 12),
                                    const SizedBox(width: 6),
                                    Text('Back',
                                        style:
                                            GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors
                                                    .white38)),
                                  ]),
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
                                  fontWeight:
                                      FontWeight.w700),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome\nBack.',
                            style:
                                GoogleFonts.cormorantGaramond(
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
                                fontWeight:
                                    FontWeight.w300,
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

          // ─── Right panel (form) ───
          Container(
            width: isMobile ? w : 480,
            color: Colors.white,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 28 : 48,
                    vertical: 40),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      GestureDetector(
                        onTap: () =>
                            Navigator.pop(context),
                        child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons
                                      .arrow_back_ios_new_rounded,
                                  size: 12,
                                  color:
                                      AppColors.mutedText),
                              const SizedBox(width: 6),
                              Text('Back',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors
                                          .mutedText)),
                            ]),
                      ),
                      const SizedBox(height: 32),
                      Text('ALUMNI',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  fontSize: 20,
                                  letterSpacing: 6,
                                  color: AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w400)),
                      const SizedBox(height: 32),
                    ] else ...[
                      const SizedBox(height: 40),
                    ],

                    // ─── Header ───
                    Text('Sign In',
                        style:
                            GoogleFonts.cormorantGaramond(
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

                    // ─── Login method toggle ───
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.borderSubtle),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_useStudentId) {
                                setState(() {
                                  _useStudentId = false;
                                  _identifierCtrl.clear();
                                  _identifierError = null;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              decoration: BoxDecoration(
                                color: !_useStudentId
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(7),
                                boxShadow: !_useStudentId
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(
                                                  0.06),
                                          blurRadius: 6,
                                          offset:
                                              const Offset(
                                                  0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: !_useStudentId
                                        ? AppColors.brandRed
                                        : AppColors
                                            .mutedText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Email',
                                      style:
                                          GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight:
                                            !_useStudentId
                                                ? FontWeight
                                                    .w700
                                                : FontWeight
                                                    .w400,
                                        color:
                                            !_useStudentId
                                                ? AppColors
                                                    .brandRed
                                                : AppColors
                                                    .mutedText,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!_useStudentId) {
                                setState(() {
                                  _useStudentId = true;
                                  _identifierCtrl.clear();
                                  _identifierError = null;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              decoration: BoxDecoration(
                                color: _useStudentId
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(7),
                                boxShadow: _useStudentId
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(
                                                  0.06),
                                          blurRadius: 6,
                                          offset:
                                              const Offset(
                                                  0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 14,
                                    color: _useStudentId
                                        ? AppColors.brandRed
                                        : AppColors
                                            .mutedText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Student ID',
                                      style:
                                          GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight:
                                            _useStudentId
                                                ? FontWeight
                                                    .w700
                                                : FontWeight
                                                    .w400,
                                        color: _useStudentId
                                            ? AppColors
                                                .brandRed
                                            : AppColors
                                                .mutedText,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ─── Email or Student ID ───
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

                          // ─── Password ───
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              _label('PASSWORD'),
                              GestureDetector(
                                onTap: _forgotPassword,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors
                                      .click,
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
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.darkText),
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() =>
                                    _passwordError = null);
                              }
                            },
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _login();
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

                          // ─── Stay signed in ───
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
                                        : AppColors
                                            .borderSubtle,
                                    width: 1.5,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                          4),
                                ),
                                child: _staySignedIn
                                    ? const Icon(Icons.check,
                                        color: Colors.white,
                                        size: 12)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Stay signed in',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        AppColors.mutedText),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 32),

                          // ─── Submit ───
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _login,
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.brandRed,
                                foregroundColor:
                                    Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            6)),
                                disabledBackgroundColor:
                                    AppColors.brandRed
                                        .withOpacity(0.6),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                  : Text('SIGN IN',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w700,
                                          letterSpacing: 2)),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ─── Register link ───
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Don\'t have an account? ',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors
                                            .mutedText)),
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.pushNamed(
                                          context,
                                          '/register'),
                                  child: MouseRegion(
                                    cursor:
                                        SystemMouseCursors
                                            .click,
                                    child: Text('Apply Now',
                                        style:
                                            GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors
                                              .brandRed,
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

  // ─── Email field ───
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
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                .hasMatch(v!.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ─── Student ID field ───
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

  // ══════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════

  Widget _label(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedText));
  }

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
      fillColor: AppColors.softWhite,
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