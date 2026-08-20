import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalog_repository.dart';
import '../models/estimate_models.dart';

Future<CatalogArea?> showAddAreaDialog(
  BuildContext context, {
  EstimateCatalog? catalog,
  String initialName = '',
}) async {
  final name = TextEditingController(text: initialName);
  final selectedTypes = <String>{};
  final workTypes = catalog?.workTypes ?? const <WorkTypeSummary>[];

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add area type'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Area type name',
                      hintText: 'e.g. Server room, Director cabin',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => Navigator.pop(context, true),
                  ),
                  if (workTypes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Typical work types (optional)', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in workTypes)
                          FilterChip(
                            label: Text(type.name),
                            selected: selectedTypes.contains(type.name),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  selectedTypes.add(type.name);
                                } else {
                                  selectedTypes.remove(type.name);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add area'),
              ),
            ],
          );
        },
      );
    },
  );

  final submitted = result == true;
  final trimmed = name.text.trim();
  name.dispose();
  if (!submitted || trimmed.isEmpty) return null;

  return CatalogRepository.instance.addArea(
    name: trimmed,
    typicalWorkTypes: selectedTypes.toList(),
  );
}

Future<WorkTypeSummary?> showAddWorkTypeDialog(
  BuildContext context, {
  EstimateCatalog? catalog,
}) async {
  final name = TextEditingController();
  final serial = TextEditingController(
    text: catalog == null || catalog.workTypes.isEmpty
        ? '1'
        : '${catalog.workTypes.map((type) => type.serialNo).reduce((a, b) => a > b ? a : b) + 1}',
  );
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add work type'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Work type name',
                    hintText: 'e.g. Signage, AV, Facade',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: serial,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'S.No.',
                    helperText: 'Shown as the numbered heading on the quotation',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, true);
            },
            child: const Text('Add work type'),
          ),
        ],
      );
    },
  );

  final trimmed = name.text.trim();
  final serialNo = int.tryParse(serial.text.trim());
  name.dispose();
  serial.dispose();
  if (confirmed != true || trimmed.isEmpty) return null;

  return CatalogRepository.instance.addWorkType(name: trimmed, serialNo: serialNo);
}

Future<WorkScope?> showAddScopeDialog(
  BuildContext context, {
  required EstimateCatalog catalog,
  String? workTypeId,
  List<String>? presetAreas,
}) async {
  var selectedTypeId = workTypeId ?? (catalog.workTypes.isEmpty ? null : catalog.workTypes.first.id);
  final name = TextEditingController();
  final description = TextEditingController();
  final code = TextEditingController();
  final suggested = TextEditingController();
  final minRate = TextEditingController();
  final maxRate = TextEditingController();
  var unit = catalogUnits.first;
  final selectedAreas = <String>{...?presetAreas};
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add work scope'),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Work type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final type in catalog.workTypes)
                            DropdownMenuItem(value: type.id, child: Text('${type.serialNo}. ${type.name}')),
                        ],
                        onChanged: workTypeId == null
                            ? (value) => setState(() => selectedTypeId = value)
                            : null,
                        validator: (value) => value == null ? 'Select a work type' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Scope name',
                          hintText: 'e.g. Acoustic wall panelling',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a scope name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Spec / finish / make notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final item in catalogUnits)
                                  DropdownMenuItem(value: item, child: Text(item)),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => unit = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: code,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Code (A, B, C…)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: suggested,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Suggested unit rate (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minRate,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Min rate',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: maxRate,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Max rate',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (catalog.areas.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Typical areas (optional)', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final area in catalog.areas)
                              FilterChip(
                                label: Text(area.name),
                                selected: selectedAreas.contains(area.name),
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      selectedAreas.add(area.name);
                                    } else {
                                      selectedAreas.remove(area.name);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Add scope'),
              ),
            ],
          );
        },
      );
    },
  );

  final typeId = selectedTypeId;
  final trimmed = name.text.trim();
  final desc = description.text.trim();
  final codeText = code.text.trim();
  final suggestedRate = double.tryParse(suggested.text.trim());
  final min = double.tryParse(minRate.text.trim());
  final max = double.tryParse(maxRate.text.trim());
  name.dispose();
  description.dispose();
  code.dispose();
  suggested.dispose();
  minRate.dispose();
  maxRate.dispose();

  if (confirmed != true || trimmed.isEmpty || typeId == null) return null;

  return CatalogRepository.instance.addScope(
    workTypeId: typeId,
    name: trimmed,
    description: desc,
    unit: unit,
    suggestedRate: suggestedRate,
    minRate: min,
    maxRate: max,
    code: codeText,
    typicalAreas: selectedAreas.toList(),
  );
}

Future<WorkScope?> showEditScopePricingDialog(
  BuildContext context, {
  required WorkScope scope,
}) async {
  final units = {
    ...catalogUnits,
    if (scope.unit.trim().isNotEmpty) scope.unit.trim(),
  }.toList();
  var unit = scope.unit.trim().isEmpty ? catalogUnits.first : scope.unit.trim();
  if (!units.contains(unit)) units.insert(0, unit);
  final rate = TextEditingController(text: scope.suggestedRate?.toString() ?? '');
  final minRate = TextEditingController(text: scope.minRate?.toString() ?? '');
  final maxRate = TextEditingController(text: scope.maxRate?.toString() ?? '');
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit unit and rate'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scope.name, style: Theme.of(context).textTheme.titleSmall),
                    Text(scope.workType, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final item in units) DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => unit = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rate,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Unit price (₹)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter a unit price';
                        if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: minRate,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min rate',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: maxRate,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Max rate',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved to local cache and used in new estimate quotations.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save to cache'),
              ),
            ],
          );
        },
      );
    },
  );

  final suggestedRate = double.tryParse(rate.text.trim());
  final min = double.tryParse(minRate.text.trim());
  final max = double.tryParse(maxRate.text.trim());
  rate.dispose();
  minRate.dispose();
  maxRate.dispose();
  if (confirmed != true || suggestedRate == null) return null;

  return CatalogRepository.instance.updateScope(
    scopeId: scope.id,
    unit: unit,
    suggestedRate: suggestedRate,
    minRate: min,
    maxRate: max,
  );
}
