import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../intelligence/presentation/providers/intelligence_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/whatsapp_models.dart';

class WhatsAppMessagesScreen extends ConsumerWidget {
  const WhatsAppMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(whatsappMessagesProvider(null));
    return PermissionGate(
      permission: Permission.whatsappView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('WhatsApp'),
          actions: [
            IconButton(onPressed: () => context.push('/whatsapp/templates'), icon: const Icon(Icons.article_outlined)),
            IconButton(onPressed: () => context.push('/whatsapp/settings'), icon: const Icon(Icons.settings_outlined)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final clientId = await showDialog<String>(
              context: context,
              builder: (context) {
                final controller = TextEditingController();
                return AlertDialog(
                  title: const Text('Client ID'),
                  content: TextField(controller: controller),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Open')),
                  ],
                );
              },
            );
            if (clientId != null && clientId.isNotEmpty && context.mounted) {
              context.push('/whatsapp/compose/$clientId');
            }
          },
          child: const Icon(Icons.chat),
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.content['text']?.toString() ?? item.templateName ?? item.messageType),
                  subtitle: Text('${item.clientId} · ${item.status.label} · ${item.direction}'),
                  onTap: () => context.push('/whatsapp/compose/${item.clientId}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WhatsAppComposeScreen extends ConsumerStatefulWidget {
  const WhatsAppComposeScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<WhatsAppComposeScreen> createState() => _WhatsAppComposeScreenState();
}

class _WhatsAppComposeScreenState extends ConsumerState<WhatsAppComposeScreen> {
  final _text = TextEditingController();
  WhatsAppTemplate? _template;
  final _variables = <TextEditingController>[];

  @override
  void dispose() {
    _text.dispose();
    for (final item in _variables) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(whatsappMessagesProvider(widget.clientId));
    return PermissionGate(
      permission: Permission.whatsappSend,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text('Chat ${widget.clientId}')),
        body: Column(
          children: [
            Expanded(
              child: rows.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('$error'),
                data: (items) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in items)
                      Align(
                        alignment: item.direction == 'outbound' ? Alignment.centerRight : Alignment.centerLeft,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('${item.content['text'] ?? item.templateName ?? ''} · ${item.status.label}'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_template != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    for (var i = 0; i < _template!.components.length; i++)
                      TextField(controller: _variables[i], decoration: InputDecoration(labelText: _template!.components[i])),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      final picked = await context.push<WhatsAppTemplate>('/whatsapp/templates');
                      if (picked is WhatsAppTemplate) {
                        for (final item in _variables) {
                          item.dispose();
                        }
                        setState(() {
                          _template = picked;
                          _variables
                            ..clear()
                            ..addAll([for (final _ in picked.components) TextEditingController()]);
                        });
                      }
                    },
                    icon: const Icon(Icons.article_outlined),
                  ),
                  Expanded(child: TextField(controller: _text, decoration: const InputDecoration(hintText: 'Message'))),
                  IconButton(
                    onPressed: () async {
                      if (_template != null) {
                        await ref.read(intelligenceRepositoryProvider).sendTemplateMessage(
                              clientId: widget.clientId,
                              templateName: _template!.name,
                              variables: [for (final item in _variables) item.text.trim()],
                            );
                      } else {
                        await ref.read(intelligenceRepositoryProvider).sendTextMessage(clientId: widget.clientId, text: _text.text.trim());
                      }
                      _text.clear();
                      ref.invalidate(whatsappMessagesProvider(widget.clientId));
                      ref.invalidate(whatsappMessagesProvider(null));
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WhatsAppTemplateSelectorScreen extends ConsumerWidget {
  const WhatsAppTemplateSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(whatsappTemplatesProvider);
    return PermissionGate(
      permission: Permission.whatsappView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Templates')),
        body: templates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.category} · ${item.components.join(', ')}'),
                  onTap: () => context.pop(item),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WhatsAppSettingsScreen extends ConsumerStatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  ConsumerState<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends ConsumerState<WhatsAppSettingsScreen> {
  final _phone = TextEditingController();
  final _webhook = TextEditingController();
  var _hydrated = false;

  @override
  void dispose() {
    _phone.dispose();
    _webhook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(whatsappConfigProvider);
    return PermissionGate(
      permission: Permission.whatsappConfigure,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('WhatsApp settings')),
        body: config.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (item) {
            if (!_hydrated) {
              _phone.text = item.phoneNumberId ?? '';
              _webhook.text = item.webhookUrl ?? '';
              _hydrated = true;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Access tokens stay in the Appwrite Function env. Only the phone number ID and webhook URL are stored here.'),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number ID')),
                TextField(controller: _webhook, decoration: const InputDecoration(labelText: 'Webhook URL')),
                FilledButton(
                  onPressed: () async {
                    await ref.read(intelligenceRepositoryProvider).updateConfig({
                      'phoneNumberId': _phone.text.trim(),
                      'webhookUrl': _webhook.text.trim(),
                    });
                    ref.invalidate(whatsappConfigProvider);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
