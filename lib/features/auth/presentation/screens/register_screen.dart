import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/data/services/registry_service.dart';
import 'package:alumni/features/admin/data/models/alumni_registry_models.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;

  // ─── Account info ───
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // ─── Personal info ───
  final _batchCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agreeNda = false;
  bool _isLoading = false;

  // ─── Registry check state ───
  final _registryService = RegistryService();
  bool _isCheckingRegistry = false;
  MatchResult? _matchResult;
  bool _registryChecked = false;

  final _steps = ['Account', 'Personal Info', 'Review'];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _batchCtrl.dispose();
    _courseCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _occupationCtrl.dispose();
    _companyCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg,
      {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  VALIDATION
  // ══════════════════════════════════════════

  bool _validateStep0() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnackBar('First and last name are required',
          isError: true);
      return false;
    }
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(email)) {
      _showSnackBar('Enter a valid email address',
          isError: true);
      return false;
    }
    if (password.length < 8) {
      _showSnackBar(
          'Password must be at least 8 characters',
          isError: true);
      return false;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _showSnackBar(
          'Password must contain at least one uppercase letter',
          isError: true);
      return false;
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _showSnackBar(
          'Password must contain at least one number',
          isError: true);
      return false;
    }
    if (password != confirm) {
      _showSnackBar('Passwords do not match',
          isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    if (_batchCtrl.text.trim().isEmpty) {
      _showSnackBar('Batch year is required',
          isError: true);
      return false;
    }
    final batch = int.tryParse(_batchCtrl.text.trim());
    if (batch == null ||
        batch < 1950 ||
        batch > DateTime.now().year) {
      _showSnackBar(
          'Enter a valid batch year (e.g. 2015)',
          isError: true);
      return false;
    }
    if (_courseCtrl.text.trim().isEmpty) {
      _showSnackBar('Course / program is required',
          isError: true);
      return false;
    }
    return true;
  }

  // ══════════════════════════════════════════
  //  REGISTRY CHECK
  // ══════════════════════════════════════════

  Future<void> _checkRegistry() async {
    if (!_validateStep1()) return;

    setState(() {
      _isCheckingRegistry = true;
      _matchResult = null;
      _registryChecked = false;
    });

    try {
      final fullName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

      final result = await _registryService.checkUser(
        fullName: fullName,
        batch: _batchCtrl.text.trim(),
        course: _courseCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _matchResult = result;
          _registryChecked = true;
        });
      }
    } catch (e) {
      // ─── If registry is empty or error, allow to proceed ───
      if (mounted) {
        setState(() {
          _matchResult = const MatchResult(
              isMatch: false,
              confidence: 0,
              record: null);
          _registryChecked = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingRegistry = false);
      }
    }
  }

  // ══════════════════════════════════════════
  //  REGISTER
  // ══════════════════════════════════════════

  Future<void> _register() async {
    if (!_agreeNda) {
      _showSnackBar(
          'Please acknowledge the agreement to proceed',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception('No user returned');

      final fullName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';
      await user.updateDisplayName(fullName);

      // ─── Determine status based on registry match ───
      final isAutoVerified =
          _matchResult?.isMatch == true &&
              (_matchResult?.confidence ?? 0) >= 0.65;

      final userStatus =
          isAutoVerified ? 'active' : 'pending';
      final verificationStatus =
          isAutoVerified ? 'verified' : 'pending';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'name': fullName,
        'email': user.email?.trim().toLowerCase(),
        'phone': _phoneCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'batch': _batchCtrl.text.trim(),
        'batchYear': int.tryParse(_batchCtrl.text.trim()),
        'course': _courseCtrl.text.trim(),
        'occupation': _occupationCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
        'role': 'alumni',
        'status': userStatus,
        'verificationStatus': verificationStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        // ─── Registry match metadata ───
        if (isAutoVerified) ...{
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': 'system_auto',
          'registryMatchId':
              _matchResult?.record?.id ?? '',
          'matchConfidence':
              _matchResult?.confidence ?? 0,
        },
      });

      // ─── Mark registry record as matched ───
      if (isAutoVerified &&
          _matchResult?.record?.id.isNotEmpty == true) {
        await FirebaseFirestore.instance
            .collection('alumni_registry')
            .doc(_matchResult!.record!.id)
            .update({
          'isMatched': true,
          'matchedUserId': user.uid,
        });
      }

      if (!mounted) return;

      // ─── Show success dialog ───
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isAutoVerified
                    ? Colors.green.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAutoVerified
                    ? Icons.verified_user
                    : Icons.check,
                color: isAutoVerified
                    ? Colors.green
                    : Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAutoVerified
                    ? 'Verified & Approved!'
                    : 'Application Submitted',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ─── Auto-verified banner ───
              if (isAutoVerified)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin:
                      const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your identity was automatically verified against our alumni registry. You can log in immediately!',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color:
                                Colors.green.shade700,
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),

              Text(
                isAutoVerified
                    ? 'Your account is now active.'
                    : 'Your application has been received.',
                style: GoogleFonts.inter(
                    fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _reviewRow('Name', fullName),
                    _reviewRow('Batch',
                        _batchCtrl.text.trim()),
                    _reviewRow('Course',
                        _courseCtrl.text.trim()),
                    _reviewRow('Status',
                        isAutoVerified
                            ? '✓ Auto-Verified'
                            : 'Pending Review'),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                isAutoVerified
                    ? 'Welcome to the St. Cecilia\'s Alumni Network!'
                    : 'Our committee will review your profile and notify you via email once approved.',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.5),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                      context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAutoVerified
                      ? Colors.green
                      : AppColors.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  isAutoVerified
                      ? 'Sign In Now'
                      : 'Return to Sign In',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered.';
          break;
        case 'weak-password':
          msg = 'Password is too weak.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        default:
          msg = e.message ?? 'Registration failed';
      }
      _showSnackBar(msg, isError: true);
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
          // ─── Left panel ───
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
                          const AlwaysStoppedAnimation(0.2),
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
                              cursor: SystemMouseCursors
                                  .click,
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons
                                          .arrow_back_ios_new_rounded,
                                      color:
                                          Colors.white38,
                                      size: 12),
                                  const SizedBox(
                                      width: 6),
                                  Text('Back',
                                      style:
                                          GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors
                                                  .white38)),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(children: [
                            Container(
                                width: 20,
                                height: 1,
                                color:
                                    AppColors.brandRed),
                            const SizedBox(width: 10),
                            Text(
                              'ST. CECILIA\'S  ·  ALUMNI',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  letterSpacing: 3,
                                  color:
                                      AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w700),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          Text(
                            'Join the\nNetwork.',
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
                              'Apply for exclusive access to the St. Cecilia\'s alumni community.',
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
                          const SizedBox(height: 32),
                          ...List.generate(
                              _steps.length, (i) {
                            final done = i < _step;
                            final active = i == _step;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                      bottom: 12),
                              child: Row(children: [
                                AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 300),
                                  width: 20,
                                  height: 20,
                                  decoration:
                                      BoxDecoration(
                                    color: done
                                        ? AppColors
                                            .brandRed
                                        : active
                                            ? Colors.white
                                            : Colors.white
                                                .withOpacity(
                                                    0.1),
                                    shape:
                                        BoxShape.circle,
                                    border: Border.all(
                                      color: done ||
                                              active
                                          ? Colors
                                              .transparent
                                          : Colors.white
                                              .withOpacity(
                                                  0.2),
                                    ),
                                  ),
                                  child: Center(
                                    child: done
                                        ? const Icon(
                                            Icons.check,
                                            size: 11,
                                            color: Colors
                                                .white)
                                        : Text(
                                            '${i + 1}',
                                            style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: active
                                                    ? AppColors.brandRed
                                                    : Colors.white.withOpacity(0.3)),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(_steps[i],
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: active
                                            ? Colors.white
                                            : done
                                                ? Colors
                                                    .white60
                                                : Colors
                                                    .white24,
                                        fontWeight: active
                                            ? FontWeight
                                                .w600
                                            : FontWeight
                                                .w300)),
                              ]),
                            );
                          }),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Right panel ───
          Container(
            width: isMobile ? w : 520,
            color: Colors.white,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 48,
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
                          mainAxisSize: MainAxisSize.min,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                          children: List.generate(
                              _steps.length, (i) {
                        final done = i < _step;
                        final active = i == _step;
                        return Expanded(
                          child: Row(children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 300),
                                height: 2,
                                color: done || active
                                    ? AppColors.brandRed
                                    : AppColors
                                        .borderSubtle,
                              ),
                            ),
                            if (i < _steps.length - 1)
                              const SizedBox(width: 4),
                          ]),
                        );
                      })),
                      const SizedBox(height: 8),
                      Text(
                          'Step ${_step + 1} of ${_steps.length}: ${_steps[_step]}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.mutedText)),
                      const SizedBox(height: 24),
                    ],
                    AnimatedSwitcher(
                      duration:
                          const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(
                              opacity: anim, child: child),
                      child: _step == 0
                          ? _buildStep0(
                              key: const ValueKey(0))
                          : _step == 1
                              ? _buildStep1(
                                  key: const ValueKey(1))
                              : _buildStep2(
                                  key: const ValueKey(2)),
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

  // ══════════════════════════════════════════
  //  STEP 0 — Account
  // ══════════════════════════════════════════

  Widget _buildStep0({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account Details',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: AppColors.darkText,
                height: 1.0)),
        const SizedBox(height: 8),
        Text(
            'Create your login credentials for the alumni portal.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.5)),
        const SizedBox(height: 32),

        Row(children: [
          Expanded(
              child: _field(
                  _firstNameCtrl, 'FIRST NAME', 'Juan')),
          const SizedBox(width: 12),
          Expanded(
              child: _field(_lastNameCtrl, 'LAST NAME',
                  'Dela Cruz')),
        ]),
        const SizedBox(height: 20),

        _field(_emailCtrl, 'EMAIL ADDRESS',
            'juan@email.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),

        _passwordField(_passwordCtrl, 'PASSWORD',
            obscure: _obscure,
            onToggle: () =>
                setState(() => _obscure = !_obscure)),
        const SizedBox(height: 8),
        _passwordHints(_passwordCtrl.text),
        const SizedBox(height: 20),

        _passwordField(
            _confirmPasswordCtrl, 'CONFIRM PASSWORD',
            obscure: _obscureConfirm,
            onToggle: () => setState(
                () => _obscureConfirm = !_obscureConfirm)),

        const SizedBox(height: 32),

        _stepButton('Next: Personal Info', () {
          if (_validateStep0()) {
            setState(() => _step = 1);
          }
        }),

        const SizedBox(height: 20),
        Center(
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Already have an account? ',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText)),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushReplacementNamed(
                          context, '/login'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text('Sign In',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.brandRed,
                            fontWeight:
                                FontWeight.w700)),
                  ),
                ),
              ]),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  STEP 1 — Personal Info + Registry Check
  // ══════════════════════════════════════════

  Widget _buildStep1({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personal Information',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: AppColors.darkText,
                height: 1.0)),
        const SizedBox(height: 8),
        Text(
            'Help us verify your alumni status with your academic details.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.5)),
        const SizedBox(height: 32),

        _sectionLabel('ACADEMIC DETAILS'),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(
            child: _field(
                _batchCtrl, 'BATCH YEAR *', 'e.g. 2015',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {
                      _registryChecked = false;
                      _matchResult = null;
                    })),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
                _courseCtrl, 'COURSE / PROGRAM *',
                'e.g. BS Nursing',
                onChanged: (_) => setState(() {
                      _registryChecked = false;
                      _matchResult = null;
                    })),
          ),
        ]),

        const SizedBox(height: 16),

        // ─── Registry check button ───
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isCheckingRegistry
                ? null
                : _checkRegistry,
            icon: _isCheckingRegistry
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandRed))
                : const Icon(Icons.search,
                    size: 16,
                    color: AppColors.brandRed),
            label: Text(
              _isCheckingRegistry
                  ? 'Checking registry...'
                  : 'Check Alumni Registry',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.brandRed,
                  fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandRed,
              side: const BorderSide(
                  color: AppColors.brandRed),
              padding: const EdgeInsets.symmetric(
                  vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
          ),
        ),

        // ─── Registry check result ───
        if (_registryChecked && _matchResult != null)
          _buildRegistryResult(),

        const SizedBox(height: 24),

        _sectionLabel('CONTACT & LOCATION'),
        const SizedBox(height: 12),

        _field(_phoneCtrl, 'PHONE NUMBER',
            'e.g. +63 912 345 6789',
            keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _field(_locationCtrl, 'CURRENT LOCATION',
            'e.g. Cebu City, Philippines',
            prefixIcon: Icons.location_on_outlined),

        const SizedBox(height: 24),

        _sectionLabel('CAREER (OPTIONAL)'),
        const SizedBox(height: 12),

        _field(_occupationCtrl,
            'JOB TITLE / OCCUPATION',
            'e.g. Software Engineer'),
        const SizedBox(height: 16),
        _field(_companyCtrl, 'COMPANY / ORGANIZATION',
            'e.g. Accenture Philippines',
            prefixIcon: Icons.business_outlined),
        const SizedBox(height: 16),
        _field(_aboutCtrl, 'ABOUT YOURSELF',
            'Share a brief intro about yourself...',
            maxLines: 3),

        const SizedBox(height: 32),

        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedText,
                side: const BorderSide(
                    color: AppColors.borderSubtle),
                padding: const EdgeInsets.symmetric(
                    vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(6)),
              ),
              child: Text('Back',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _stepButton('Review Application', () {
              if (_validateStep1()) {
                setState(() => _step = 2);
              }
            }),
          ),
        ]),
      ],
    );
  }

  Widget _buildRegistryResult() {
    final isMatch = _matchResult!.isMatch;
    final confidence = _matchResult!.confidence;
    final record = _matchResult!.record;
    final confidencePct =
        (confidence * 100).toStringAsFixed(0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMatch
            ? Colors.green.withOpacity(0.06)
            : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMatch
              ? Colors.green.withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              isMatch
                  ? Icons.verified_user
                  : Icons.info_outline,
              size: 16,
              color: isMatch ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMatch
                    ? 'Registry Match Found! ($confidencePct% confidence)'
                    : 'No registry match found',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isMatch
                        ? Colors.green.shade700
                        : Colors.orange.shade700),
              ),
            ),
          ]),
          const SizedBox(height: 6),

          if (isMatch && record != null) ...[
            // ─── Match details ───
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('Matched record:',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedText,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _matchRow(Icons.person_outline,
                      record.fullName),
                  if (record.batch.isNotEmpty)
                    _matchRow(Icons.school_outlined,
                        'Batch ${record.batch}'),
                  if (record.course.isNotEmpty)
                    _matchRow(Icons.book_outlined,
                        record.course),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '✓ Your account will be automatically verified upon registration.',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  height: 1.4),
            ),
          ] else ...[
            Text(
              'Your application will be submitted for manual review by our committee.',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _matchRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 12, color: AppColors.mutedText),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.darkText,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ══════════════════════════════════════════
  //  STEP 2 — Review + Submit
  // ══════════════════════════════════════════

  Widget _buildStep2({Key? key}) {
    final fullName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';
    final isAutoVerified =
        _matchResult?.isMatch == true &&
            (_matchResult?.confidence ?? 0) >= 0.65;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Application',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: AppColors.darkText,
                height: 1.0)),
        const SizedBox(height: 8),
        Text(
            'Please review your information before submitting.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.5)),
        const SizedBox(height: 28),

        // ─── Registry status banner ───
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isAutoVerified
                ? Colors.green.withOpacity(0.07)
                : Colors.orange.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAutoVerified
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(children: [
            Icon(
              isAutoVerified
                  ? Icons.verified_user
                  : Icons.pending_outlined,
              size: 18,
              color: isAutoVerified
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    isAutoVerified
                        ? 'Auto-Verification Ready'
                        : 'Manual Review Required',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isAutoVerified
                            ? Colors.green.shade700
                            : Colors.orange.shade700),
                  ),
                  Text(
                    isAutoVerified
                        ? 'Your identity matched our alumni registry. You\'ll be verified instantly.'
                        : 'No registry match found. Your application will be reviewed by our committee.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isAutoVerified
                            ? Colors.green.shade600
                            : Colors.orange.shade600,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ),

        _reviewSection('ACCOUNT', [
          ['Full Name', fullName],
          ['Email', _emailCtrl.text.trim()],
        ]),
        const SizedBox(height: 12),
        _reviewSection('ACADEMIC', [
          ['Batch Year', _batchCtrl.text.trim()],
          ['Course', _courseCtrl.text.trim()],
          [
            'Registry',
            isAutoVerified
                ? '✓ Matched'
                : 'Not matched'
          ],
        ]),
        if (_phoneCtrl.text.trim().isNotEmpty ||
            _locationCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _reviewSection('CONTACT', [
            if (_phoneCtrl.text.trim().isNotEmpty)
              ['Phone', _phoneCtrl.text.trim()],
            if (_locationCtrl.text.trim().isNotEmpty)
              ['Location', _locationCtrl.text.trim()],
          ]),
        ],
        if (_occupationCtrl.text.trim().isNotEmpty ||
            _companyCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _reviewSection('CAREER', [
            if (_occupationCtrl.text.trim().isNotEmpty)
              ['Title', _occupationCtrl.text.trim()],
            if (_companyCtrl.text.trim().isNotEmpty)
              ['Company', _companyCtrl.text.trim()],
          ]),
        ],

        const SizedBox(height: 24),

        // ─── NDA checkbox ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(
                    () => _agreeNda = !_agreeNda),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _agreeNda
                        ? AppColors.brandRed
                        : Colors.white,
                    border: Border.all(
                      color: _agreeNda
                          ? AppColors.brandRed
                          : AppColors.borderSubtle,
                      width: 1.5,
                    ),
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                  child: _agreeNda
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 12)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I acknowledge the Non-Disclosure Agreement and understand that membership is subject to committee review and approval.',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.darkText,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _step = 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedText,
                side: const BorderSide(
                    color: AppColors.borderSubtle),
                padding: const EdgeInsets.symmetric(
                    vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(6)),
              ),
              child: Text('Back',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAutoVerified
                    ? Colors.green
                    : AppColors.brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(6)),
                disabledBackgroundColor:
                    AppColors.brandRed.withOpacity(0.6),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2))
                  : Text(
                      isAutoVerified
                          ? 'SUBMIT & GET VERIFIED'
                          : 'SUBMIT APPLICATION',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
            ),
          ),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _reviewSection(
      String title, List<List<String>> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: AppColors.brandRed,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(
                    width: 72,
                    child: Text(row[0],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedText)),
                  ),
                  Expanded(
                    child: Text(
                        row[1].isEmpty ? '—' : row[1],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: row[1].startsWith('✓')
                                ? Colors.green.shade700
                                : AppColors.darkText,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _stepButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(children: [
      Container(
          width: 16, height: 1, color: AppColors.brandRed),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 9,
              letterSpacing: 2,
              color: AppColors.brandRed,
              fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _passwordHints(String password) {
    final checks = [
      ['At least 8 characters', password.length >= 8],
      [
        'One uppercase letter',
        RegExp(r'[A-Z]').hasMatch(password)
      ],
      ['One number', RegExp(r'[0-9]').hasMatch(password)],
    ];
    return Column(
      children: checks.map((c) {
        final passed = c[1] as bool;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(
              passed
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              size: 12,
              color: passed
                  ? Colors.green
                  : AppColors.borderSubtle,
            ),
            const SizedBox(width: 6),
            Text(c[0].toString(),
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: passed
                        ? Colors.green
                        : AppColors.mutedText)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.darkText),
          onChanged: onChanged ??
              (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.borderSubtle,
                fontSize: 13),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon,
                    color: AppColors.mutedText, size: 18)
                : null,
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.brandRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String label, {
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.darkText),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '••••••••••',
            hintStyle: GoogleFonts.inter(
                color: AppColors.borderSubtle,
                fontSize: 13,
                letterSpacing: 3),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.mutedText,
                  size: 18),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.brandRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}