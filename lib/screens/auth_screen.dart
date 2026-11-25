import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/employee_roster.dart';
import '../models/equipment_item.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegisterMode = false;

  // Login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Registration controllers
  String? _selectedOfficialName;
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmPassCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _loginEmailCtrl.text.trim();
    final password = _loginPassCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Sign-in failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerEmployee() async {
    final officialName = _selectedOfficialName?.trim() ?? '';
    final email = _regEmailCtrl.text.trim().toLowerCase();
    final password = _regPassCtrl.text;
    final confirmPassword = _regConfirmPassCtrl.text;

    if (officialName.isEmpty) {
      setState(
        () => _error = 'Please select your official name from the list.',
      );
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(officialName);

      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(uid).set({
        'uid': uid,
        'role': 'employee',
        'fullName': officialName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Auto-link any existing MR'ed equipment matching this employee's name
      final eqSnap = await db
          .collection(AppConstants.equipmentCollection)
          .where('isArchived', isEqualTo: false)
          .get();

      final batch = db.batch();
      int matchedCount = 0;
      for (final doc in eqSnap.docs) {
        final item = EquipmentItem.fromFirestore(doc);
        if (EmployeeRoster.matchesResponsiblePersonnel(
          rosterName: officialName,
          responsiblePersonnel: item.responsiblePersonnel,
        )) {
          batch.update(doc.reference, {'assignedUserEmail': email});
          matchedCount++;
        }
      }
      if (matchedCount > 0) {
        await batch.commit();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed.');
    } catch (e) {
      setState(() => _error = 'Registration error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _loginEmailCtrl.text.trim());
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool manualMode = false;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              manualMode ? 'Request Manual ICTU Reset' : 'Forgot Password?',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!manualMode) ...[
                    const Text(
                      'Enter your registered email to receive a password reset link, or request manual assistance from ICTU.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Registered Email Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setDialogState(() => manualMode = true),
                      icon: const Icon(Icons.support_agent, size: 18),
                      label: const Text(
                        'Cannot access email? Inform ICTU manually',
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Submit your name and details so ICTU can assist with your account recovery:',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Used (if remembered)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Office / Contact Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => submitting = true);
                        try {
                          if (!manualMode) {
                            final email = emailCtrl.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid email address.'),
                                ),
                              );
                              setDialogState(() => submitting = false);
                              return;
                            }
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: email,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Password reset link sent to $email. Check your inbox/spam.',
                                ),
                              ),
                            );
                          } else {
                            final fullName = nameCtrl.text.trim();
                            if (fullName.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter your full name.'),
                                ),
                              );
                              setDialogState(() => submitting = false);
                              return;
                            }
                            await FirebaseFirestore.instance
                                .collection('ictu_requests')
                                .add({
                                  'type': 'password_reset',
                                  'fullName': fullName,
                                  'email': emailCtrl.text.trim(),
                                  'notes': notesCtrl.text.trim(),
                                  'status': 'pending',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Request logged! Please also follow up with ICTU if urgent.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => submitting = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                child: Text(manualMode ? 'Send to ICTU' : 'Send Reset Email'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openUnlistedEmployeeDialog() async {
    final nameCtrl = TextEditingController();
    final officeCtrl = TextEditingController();
    final emailCtrl = TextEditingController(text: _regEmailCtrl.text.trim());
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Name Not on Official List?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'If your name is missing from the center employee list (e.g., newly hired or COS), submit your details to ICTU so we can register your MR profile:',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Complete Name (LAST, FIRST MI.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: officeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Division / Office / Section',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Preferred Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final fullName = nameCtrl.text.trim();
                        if (fullName.isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => submitting = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('ictu_requests')
                              .add({
                                'type': 'unlisted_employee',
                                'fullName': fullName.toUpperCase(),
                                'email': emailCtrl.text.trim(),
                                'notes': officeCtrl.text.trim(),
                                'status': 'pending',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Submitted to ICTU! Please notify ICTU personnel to verify your MR record.',
                              ),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => submitting = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to submit: $e')),
                          );
                        }
                      },
                child: const Text('Notify ICTU'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRegisterMode
              ? 'Employee MR Registration'
              : 'ICT Inventory Sign In',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'DOH - DATRC Mountain Province',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),

                // Mode Switcher (Sign In vs Employee Register)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign In')),
                    ButtonSegment(
                      value: true,
                      label: Text('Employee Register'),
                    ),
                  ],
                  selected: {_isRegisterMode},
                  onSelectionChanged: (sel) {
                    setState(() {
                      _isRegisterMode = sel.first;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 20),

                if (!_isRegisterMode) ...[
                  TextField(
                    controller: _loginEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _loginPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _openForgotPasswordDialog,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOfficialName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Your Official Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: EmployeeRoster.officialEmployees
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedOfficialName = val),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _loading ? null : _openUnlistedEmployeeDialog,
                      icon: const Icon(Icons.person_add_disabled, size: 16),
                      label: const Text('Name not on the list? Notify ICTU'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _regEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _regPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Create Password (min. 6 chars)',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _regConfirmPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_reset),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : (_isRegisterMode ? _registerEmployee : _signIn),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isRegisterMode
                              ? 'Create Employee MR Account'
                              : 'Sign In',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
