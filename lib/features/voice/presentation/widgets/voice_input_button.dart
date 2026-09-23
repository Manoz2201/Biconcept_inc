import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../rbac/domain/permission.dart';

class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({super.key, required this.onTranscription});

  final void Function(String text) onTranscription;

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.voiceToText,
      child: AppIconButton(
        icon: Icons.mic_none,
        tooltip: 'Dictate or type',
        accent: true,
        onPressed: () async {
          final controller = TextEditingController();
          final text = await showAppModal<String>(
            context: context,
            title: 'Voice note',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Speak on device, then paste or type. Audio is not stored.',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const Spacer(),
                    FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Use')),
                  ],
                ),
              ],
            ),
          );
          controller.dispose();
          if (text != null && text.isNotEmpty) {
            onTranscription(text);
          }
        },
      ),
    );
  }
}

class VoiceTranscriptionScreen extends ConsumerStatefulWidget {
  const VoiceTranscriptionScreen({super.key});

  @override
  ConsumerState<VoiceTranscriptionScreen> createState() => _VoiceTranscriptionScreenState();
}

class _VoiceTranscriptionScreenState extends ConsumerState<VoiceTranscriptionScreen> {
  String _text = '';

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.voiceToText,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Transcribe')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('On-device speech packages are not bundled. Paste a transcript; it is not uploaded.'),
              VoiceInputButton(onTranscription: (text) => setState(() => _text = text)),
              const SizedBox(height: 12),
              Text(_text.isEmpty ? 'Nothing transcribed yet.' : _text),
            ],
          ),
        ),
      ),
    );
  }
}
