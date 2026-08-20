import 'package:flutter/material.dart';

import '../models/estimate_document.dart';

Future<String?> showEstimateTypePicker(
  BuildContext context, {
  required String current,
}) {
  var selected = normalizeEstimateType(current);
  final custom = TextEditingController(
    text: presetEstimateTypes.contains(selected) ? '' : selected,
  );
  final isPreset = presetEstimateTypes.contains(selected);
  if (!isPreset) selected = '';

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Estimate type'),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final type in presetEstimateTypes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected == type ? Icons.radio_button_checked : Icons.radio_button_off,
                      ),
                      title: Text(type),
                      selected: selected == type,
                      onTap: () => setState(() {
                        selected = type;
                        custom.clear();
                      }),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected.isEmpty ? Icons.radio_button_checked : Icons.radio_button_off,
                    ),
                    title: const Text('Custom'),
                    selected: selected.isEmpty,
                    onTap: () => setState(() => selected = ''),
                  ),
                  TextField(
                    controller: custom,
                    enabled: selected.isEmpty,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Custom type',
                      hintText: 'e.g. Revised Interior Estimate',
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => setState(() => selected = ''),
                    onChanged: (_) => setState(() => selected = ''),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final customText = custom.text.trim();
              final value = selected.isNotEmpty ? selected : customText;
              Navigator.pop(context, normalizeEstimateType(value));
            },
            child: const Text('Save type'),
          ),
        ],
      );
    },
  ).whenComplete(custom.dispose);
}
