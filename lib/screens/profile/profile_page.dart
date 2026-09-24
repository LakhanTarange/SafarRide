import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  String _role = '';
  String _accountStatus = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
      return;
    }

    try {
      final profile = await _authService.getUserProfile(user.uid);

      if (!profile.exists) {
        if (!mounted) {
          return;
        }

        setState(() {
          _emailController.text = user.email ?? '';
          _nameController.text = user.displayName ?? '';
          _isLoading = false;
        });

        return;
      }

      final data = profile.data();

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text =
            data?['name']?.toString() ?? user.displayName ?? '';

        _emailController.text =
            data?['email']?.toString() ?? user.email ?? '';

        _phoneController.text =
            data?['phone']?.toString() ?? '';

        _role = data?['role']?.toString() ?? '';

        _accountStatus =
            data?['accountStatus']?.toString() ?? 'active';

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _emailController.text = user.email ?? '';
        _nameController.text = user.displayName ?? '';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load your profile.',
          ),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    final user = _authService.currentUser;

    if (user == null || _isSaving) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name.'),
        ),
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid 10-digit mobile number.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.updateUserProfile(
        uid: user.uid,
        name: name,
        phone: phone,
      );

      await user.updateDisplayName(name);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to update profile.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to logout. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _showLogoutConfirmation() async {
    if (_isLoggingOut) {
      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  String _formatRole() {
    switch (_role) {
      case 'customer':
        return 'Customer';

      case 'partner':
        return 'Partner';

      default:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  32,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _nameController.text.isEmpty
                          ? 'User'
                          : _nameController.text,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRole(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textCapitalization:
                                  TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon:
                                    Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon:
                                    Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                prefixIcon:
                                    Icon(Icons.phone_outlined),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.verified_user_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            title: const Text('Account Status'),
                            subtitle: Text(
                              _accountStatus.isEmpty
                                  ? 'ACTIVE'
                                  : _accountStatus.toUpperCase(),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.badge_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            title: const Text('Account Type'),
                            subtitle: Text(_formatRole()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoggingOut
                            ? null
                            : _showLogoutConfirmation,
                        icon: _isLoggingOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${AppConfig.appName} • ${AppConfig.companyName}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}