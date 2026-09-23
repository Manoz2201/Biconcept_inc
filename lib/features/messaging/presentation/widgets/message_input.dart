import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../catalog/domain/storage_repository.dart';

class MessageInput extends StatefulWidget {
  const MessageInput({super.key, required this.onSend, this.enabled = true});

  final Future<void> Function(String text, List<UploadBytes> files) onSend;
  final bool enabled;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _files = <UploadBytes>[];
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_files.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${_files.length} file(s) attached', style: const TextStyle(fontSize: 12)),
          ),
        Row(
          children: [
            IconButton(
              onPressed: widget.enabled && !_busy ? _pick : null,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled && !_busy,
                decoration: const InputDecoration(hintText: 'Write a message'),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            IconButton(
              onPressed: widget.enabled && !_busy ? _send : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.bytes == null) continue;
        _files.add(UploadBytes(bytes: file.bytes!, filename: file.name));
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _files.isEmpty) return;
    setState(() => _busy = true);
    await widget.onSend(text, List.of(_files));
    if (!mounted) return;
    _controller.clear();
    _files.clear();
    setState(() => _busy = false);
  }
}
