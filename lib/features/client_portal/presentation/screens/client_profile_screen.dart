import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../../../../theme/app_theme.dart';
import '../../../../ui/widgets/color_theme_selector.dart';
import '../../../../ui/widgets/portal_shell.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  var _notifyEmail = true;
  var _notifyPush = true;
  var _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).user;
    _name.text = user?.name ?? '';
    _phone.text = user?.phone ?? '';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyEmail = prefs.getBool('client.notifyEmail') ?? true;
      _notifyPush = prefs.getBool('client.notifyPush') ?? true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _oldPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).user;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return PortalPageScaffold(
      title: 'profile',
      subtitle: 'Account, notifications, and billing shortcuts.',
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, compact ? AppBreakpoints.navClearance : 32),
        children: [
          if (_message != null) Text(_message!, style: TextStyle(color: AppColors.up)),
          const ColorThemeSelector(compact: true),
          const SizedBox(height: 24),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          Text(
            user?.email ?? '',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(label: 'Save profile', onPressed: _busy ? null : _saveProfile),
          const SizedBox(height: 24),
          const Text('Change password', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _oldPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 8),
          TextField(controller: _newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
          const SizedBox(height: 8),
          AppSecondaryButton(label: 'Update password', onPressed: _busy ? null : _savePassword),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email notifications'),
            value: _notifyEmail,
            onChanged: (value) async {
              setState(() => _notifyEmail = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('client.notifyEmail', value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push notifications'),
            value: _notifyPush,
            onChanged: (value) async {
              setState(() => _notifyPush = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('client.notifyPush', value);
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Invoices'),
            onTap: () => context.push('/client/invoices'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Payments'),
            onTap: () => context.push('/client/payments'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              await ref.read(sessionControllerProvider.notifier).logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _busy = true);
    final result = await ref.read(sessionControllerProvider.notifier).updateProfile(
          name: _name.text,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.isSuccess ? 'Profile saved' : result.errorOrNull?.userMessage;
    });
  }

  Future<void> _savePassword() async {
    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).updatePassword(
          oldPassword: _oldPassword.text,
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.isSuccess ? 'Password updated' : result.errorOrNull?.userMessage;
    });
  }
}
