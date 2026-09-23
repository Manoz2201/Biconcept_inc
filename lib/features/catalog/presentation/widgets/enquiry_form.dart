import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalog/domain/service_item.dart';
import '../../../catalog/presentation/providers/services_provider.dart';
import '../../../enquiries/presentation/providers/enquiries_provider.dart';

class EnquiryForm extends ConsumerStatefulWidget {
  const EnquiryForm({super.key, this.preselectedServiceId});

  final String? preselectedServiceId;

  @override
  ConsumerState<EnquiryForm> createState() => _EnquiryFormState();
}

class _EnquiryFormState extends ConsumerState<EnquiryForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  var _success = false;
  String? _error;
  String? _hint;

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(publicServicesProvider).valueOrNull ?? const <ServiceItem>[];
    if (_success) {
      return Column(
        key: const Key('enquiry-success'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thanks — we received your enquiry.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'A BiConcept architect will get back to you shortly.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/register'),
            child: const Text('Create an account'),
          ),
        ],
      );
    }
    return FormBuilder(
      key: _formKey,
      initialValue: {
        if (widget.preselectedServiceId != null) 'serviceId': widget.preselectedServiceId,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.down)),
            ),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_hint!, style: TextStyle(color: AppColors.primarySoft)),
            ),
          FormBuilderTextField(
            name: 'name',
            decoration: const InputDecoration(labelText: 'Name'),
            validator: FormBuilderValidators.required(errorText: 'Name is required'),
          ),
          const SizedBox(height: 12),
          FormBuilderTextField(
            name: 'email',
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Email is required'),
              FormBuilderValidators.email(errorText: 'Enter a valid email'),
            ]),
          ),
          const SizedBox(height: 12),
          FormBuilderTextField(
            name: 'phone',
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: 12),
          FormBuilderDropdown<String>(
            name: 'serviceId',
            decoration: const InputDecoration(labelText: 'Service (optional)'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Any / not sure')),
              for (final service in services)
                DropdownMenuItem(value: service.id, child: Text('${service.category} · ${service.title}')),
            ],
          ),
          const SizedBox(height: 12),
          FormBuilderTextField(
            name: 'message',
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Message'),
            validator: FormBuilderValidators.required(errorText: 'Message is required'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('enquiry-submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send enquiry'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _hint = null;
    });
    final cooldown = ref.read(enquiryCooldownProvider);
    final wait = await cooldown.remaining();
    if (wait != null) {
      setState(() {
        _busy = false;
        _error = 'Please wait ${wait.inSeconds + 1}s before sending another enquiry';
      });
      return;
    }
    final email = form.value['email']?.toString().trim() ?? '';
    final validator = ref.read(emailValidationServiceProvider);
    if (!validator.validateLocally(email)) {
      setState(() {
        _busy = false;
        _error = 'Enter a valid email';
      });
      return;
    }
    final backend = await validator.validateWithBackend(email);
    final blocked = backend.when(
      success: (result) => validator.hardBlockMessage(result),
      failure: (error) => error.userMessage,
    );
    if (blocked != null) {
      setState(() {
        _busy = false;
        _error = blocked;
        _hint = backend.dataOrNull == null ? null : validator.warningMessage(backend.dataOrNull!);
      });
      return;
    }
    final warning = backend.dataOrNull == null ? null : validator.warningMessage(backend.dataOrNull!);
    final serviceId = form.value['serviceId']?.toString();
    final result = await ref.read(enquiryRepositoryProvider).submitEnquiry(
          name: form.value['name']?.toString() ?? '',
          email: email,
          phone: () {
            final value = form.value['phone']?.toString().trim() ?? '';
            return value.isEmpty ? null : value;
          }(),
          serviceId: serviceId == null || serviceId.isEmpty ? null : serviceId,
          message: form.value['message']?.toString() ?? '',
          source: 'website',
        );
    if (!mounted) return;
    result.when(
      success: (_) async {
        await cooldown.markSubmitted();
        setState(() {
          _busy = false;
          _success = true;
          _hint = warning;
        });
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
        _hint = warning;
      }),
    );
  }
}
