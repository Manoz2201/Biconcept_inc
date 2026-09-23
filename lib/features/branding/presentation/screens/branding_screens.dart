import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/branding_settings.dart';

class BrandingSettingsScreen extends ConsumerStatefulWidget {
  const BrandingSettingsScreen({super.key});

  @override
  ConsumerState<BrandingSettingsScreen> createState() => _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState extends ConsumerState<BrandingSettingsScreen> {
  late TextEditingController _name;
  late TextEditingController _tagline;
  late TextEditingController _primary;
  late TextEditingController _secondary;
  late TextEditingController _accent;
  late TextEditingController _header;
  late TextEditingController _footer;
  late TextEditingController _signature;
  late TextEditingController _domain;
  late TextEditingController _email;
  var _ready = false;

  @override
  void dispose() {
    if (_ready) {
      _name.dispose();
      _tagline.dispose();
      _primary.dispose();
      _secondary.dispose();
      _accent.dispose();
      _header.dispose();
      _footer.dispose();
      _signature.dispose();
      _domain.dispose();
      _email.dispose();
    }
    super.dispose();
  }

  void _bind(BrandingSettings item) {
    if (_ready) return;
    _name = TextEditingController(text: item.firmName);
    _tagline = TextEditingController(text: item.tagline ?? '');
    _primary = TextEditingController(text: item.primaryColor);
    _secondary = TextEditingController(text: item.secondaryColor);
    _accent = TextEditingController(text: item.accentColor);
    _header = TextEditingController(text: item.emailTemplateHeader ?? '');
    _footer = TextEditingController(text: item.emailTemplateFooter ?? '');
    _signature = TextEditingController(text: item.emailSignature ?? '');
    _domain = TextEditingController(text: item.customDomain ?? '');
    _email = TextEditingController(text: item.supportEmail ?? '');
    _ready = true;
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingSettingsProvider);
    return PermissionGate(
      permission: Permission.brandingView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Branding')),
        body: branding.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (item) {
            _bind(item);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text(_name.text),
                    subtitle: Text(_tagline.text.isEmpty ? 'App header preview' : _tagline.text),
                    tileColor: _color(_primary.text),
                  ),
                ),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Firm name')),
                TextField(controller: _tagline, decoration: const InputDecoration(labelText: 'Tagline')),
                TextField(controller: _primary, decoration: const InputDecoration(labelText: 'Primary hex')),
                TextField(controller: _secondary, decoration: const InputDecoration(labelText: 'Secondary hex')),
                TextField(controller: _accent, decoration: const InputDecoration(labelText: 'Accent hex')),
                TextField(controller: _header, decoration: const InputDecoration(labelText: 'Email header'), maxLines: 3),
                TextField(controller: _footer, decoration: const InputDecoration(labelText: 'Email footer'), maxLines: 3),
                TextField(controller: _signature, decoration: const InputDecoration(labelText: 'Email signature')),
                TextField(controller: _domain, decoration: const InputDecoration(labelText: 'Custom domain')),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Support email')),
                const SizedBox(height: 8),
                const Text('Add a DNS TXT record: biconcept-verify=firm'),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => _pick(false), child: const Text('Upload logo')),
                    OutlinedButton(onPressed: () => _pick(true), child: const Text('Dark logo')),
                    PermissionGate(
                      permission: Permission.brandingEdit,
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(brandingRepositoryProvider).updateBrandingSettings({
                            'firmName': _name.text.trim(),
                            'tagline': _tagline.text.trim(),
                            'primaryColor': _primary.text.trim(),
                            'secondaryColor': _secondary.text.trim(),
                            'accentColor': _accent.text.trim(),
                            'emailTemplateHeader': _header.text,
                            'emailTemplateFooter': _footer.text,
                            'emailSignature': _signature.text,
                            'customDomain': _domain.text.trim(),
                            'supportEmail': _email.text.trim(),
                          });
                          ref.invalidate(brandingSettingsProvider);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(brandingRepositoryProvider).verifyCustomDomain('biconcept-verify=firm');
                        ref.invalidate(brandingSettingsProvider);
                      },
                      child: const Text('Verify domain'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(brandingRepositoryProvider).resetToDefaults();
                        _ready = false;
                        ref.invalidate(brandingSettingsProvider);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pick(bool dark) async {
    final picked = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
    final file = picked?.files.single;
    if (file?.bytes == null) return;
    await ref.read(brandingRepositoryProvider).uploadLogo(UploadBytes(bytes: file!.bytes!, filename: file.name), isDark: dark);
    ref.invalidate(brandingSettingsProvider);
  }

  Color _color(String raw) {
    final clean = raw.replaceAll('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null || clean.length != 6) return Colors.blueGrey;
    return Color(0xFF000000 | value);
  }
}

class ColorPickerScreen extends StatelessWidget {
  const ColorPickerScreen({super.key});

  @override
  Widget build(BuildContext context) => const BrandingSettingsScreen();
}

class EmailTemplateEditorScreen extends StatelessWidget {
  const EmailTemplateEditorScreen({super.key});

  @override
  Widget build(BuildContext context) => const BrandingSettingsScreen();
}
