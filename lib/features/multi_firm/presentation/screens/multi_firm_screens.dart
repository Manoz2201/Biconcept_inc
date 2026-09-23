import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_navigation.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../intelligence/presentation/providers/intelligence_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/tenant.dart';

class MultiFirmDashboardScreen extends ConsumerWidget {
  const MultiFirmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(availableTenantsProvider);
    return PermissionGate(
      permission: Permission.multiFirmDashboard,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Multi-firm')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/multi-firm/tenants/new'),
          child: const Icon(Icons.add),
        ),
        body: tenants.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              ListTile(
                title: Text('${items.length} firms'),
                subtitle: Text('${items.where((item) => item.subscriptionStatus == 'trial').length} on trial'),
                trailing: TextButton(onPressed: () => context.push('/multi-firm/subscription/plans'), child: const Text('Plans')),
              ),
              for (final item in items)
                ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.subdomain} · ${item.subscriptionPlan} · ${item.subscriptionStatus}'),
                  onTap: () => context.push('/multi-firm/tenants/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantSwitcherScreen extends ConsumerWidget {
  const TenantSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(availableTenantsProvider);
    final current = ref.watch(currentTenantProvider);
    return PermissionGate(
      permission: Permission.tenantView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Switch firm')),
        body: tenants.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              current.when(
                data: (tenant) => ListTile(title: Text('Current: ${tenant.name}')),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              for (final item in items)
                ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.subdomain),
                  onTap: () async {
                    await ref.read(intelligenceRepositoryProvider).switchTenant(item.id);
                    ref.invalidate(currentTenantProvider);
                    ref.invalidate(availableTenantsProvider);
                    if (context.mounted) context.pop();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add new firm'),
                onTap: () => context.push('/multi-firm/tenants/new'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantOnboardingScreen extends ConsumerStatefulWidget {
  const TenantOnboardingScreen({super.key});

  @override
  ConsumerState<TenantOnboardingScreen> createState() => _TenantOnboardingScreenState();
}

class _TenantOnboardingScreenState extends ConsumerState<TenantOnboardingScreen> {
  final _name = TextEditingController();
  final _subdomain = TextEditingController();
  final _email = TextEditingController();
  var _plan = 'basic';
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _subdomain.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.tenantCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('New firm')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppStepper(
              current: _name.text.isEmpty
                  ? 0
                  : _subdomain.text.isEmpty
                      ? 1
                      : _email.text.isEmpty
                          ? 2
                          : 3,
              steps: const ['Name', 'Domain', 'Admin', 'Plan'],
            ),
            const SizedBox(height: 20),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Firm name'), onChanged: (_) => setState(() {})),
            TextField(controller: _subdomain, decoration: const InputDecoration(labelText: 'Subdomain'), onChanged: (_) => setState(() {})),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Admin email'), onChanged: (_) => setState(() {})),
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'Plan'),
              items: const [
                DropdownMenuItem(value: 'basic', child: Text('Basic')),
                DropdownMenuItem(value: 'pro', child: Text('Pro')),
                DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
              ],
              onChanged: (value) => setState(() => _plan = value ?? 'basic'),
            ),
            AppPrimaryButton(
              label: 'Provision tenant',
              loading: _busy,
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final created = await ref.read(intelligenceRepositoryProvider).createTenant(
                            name: _name.text.trim(),
                            subdomain: _subdomain.text.trim(),
                            adminEmail: _email.text.trim(),
                            plan: _plan,
                          );
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (created.dataOrNull != null) {
                        ref.invalidate(availableTenantsProvider);
                        context.go('/multi-firm/tenants/${created.dataOrNull!.id}');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Failed')));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class TenantSettingsScreen extends ConsumerWidget {
  const TenantSettingsScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      permission: Permission.tenantView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: _TenantBody(tenantId: tenantId),
    );
  }
}

class _TenantBody extends ConsumerStatefulWidget {
  const _TenantBody({required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<_TenantBody> createState() => _TenantBodyState();
}

class _TenantBodyState extends ConsumerState<_TenantBody> {
  final _name = TextEditingController();
  final _gstin = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(tenantUsageProvider(widget.tenantId));
    final sub = ref.watch(tenantSubscriptionProvider(widget.tenantId));
    final tenants = ref.watch(availableTenantsProvider).valueOrNull ?? const <Tenant>[];
    final tenant = tenants.cast<Tenant?>().firstWhere((item) => item?.id == widget.tenantId, orElse: () => null);
    if (tenant != null && _name.text.isEmpty) {
      _name.text = tenant.name;
      _gstin.text = tenant.gstin ?? '';
    }
    return Scaffold(
      appBar: AppBar(title: Text(tenant?.name ?? 'Tenant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Firm name')),
          TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
          FilledButton(
            onPressed: () async {
              await ref.read(intelligenceRepositoryProvider).updateTenant(widget.tenantId, {
                'name': _name.text.trim(),
                'gstin': _gstin.text.trim(),
              });
              ref.invalidate(availableTenantsProvider);
            },
            child: const Text('Save'),
          ),
          usage.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (item) => Column(
              children: [
                ListTile(title: Text('Users ${item.users}/${item.userLimit}'), subtitle: LinearProgressIndicator(value: item.userRatio.clamp(0, 1))),
                ListTile(title: Text('Projects ${item.projects}/${item.projectLimit}'), subtitle: LinearProgressIndicator(value: item.projectRatio.clamp(0, 1))),
                ListTile(title: Text('AI calls ${item.aiTokens} · WhatsApp ${item.whatsappMessages}')),
              ],
            ),
          ),
          sub.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
            data: (item) => ListTile(title: Text('${item.plan} · ${item.status}'), subtitle: Text('₹${item.amount} / period')),
          ),
          TextButton(onPressed: () => context.push('/multi-firm/tenants/${widget.tenantId}/usage'), child: const Text('Usage dashboard')),
          TextButton(onPressed: () => context.push('/multi-firm/subscription/plans'), child: const Text('Change plan')),
        ],
      ),
    );
  }
}

class UsageDashboardScreen extends ConsumerWidget {
  const UsageDashboardScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(tenantUsageProvider(tenantId));
    return PermissionGate(
      permission: Permission.tenantSubscriptionView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Usage')),
        body: usage.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _bar('Users', item.users, item.userLimit),
              _bar('Projects', item.projects, item.projectLimit),
              _bar('Storage GB', item.storageGB.round(), item.storageLimitGB),
              ListTile(title: Text('AI tokens ${item.aiTokens}')),
              ListTile(title: Text('WhatsApp ${item.whatsappMessages}')),
              if (item.userRatio >= 0.8 || item.projectRatio >= 0.8)
                const ListTile(leading: Icon(Icons.warning_amber), title: Text('Approaching plan limits')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(String label, int used, int limit) {
    return ListTile(
      title: Text('$label $used / $limit'),
      subtitle: LinearProgressIndicator(value: limit == 0 ? 0 : (used / limit).clamp(0, 1)),
    );
  }
}

class SubscriptionPlansScreen extends ConsumerWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTenantProvider);
    return PermissionGate(
      permission: Permission.tenantSubscriptionView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Plans')),
        body: current.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (tenant) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _plan(ref, tenant, 'basic', '₹2,999', '5 users · 10 projects · lead score'),
              _plan(ref, tenant, 'pro', '₹9,999', '20 users · 100 projects · AI, OCR, WhatsApp'),
              _plan(ref, tenant, 'enterprise', '₹24,999', 'Unlimited · custom domain'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plan(WidgetRef ref, Tenant tenant, String plan, String price, String features) {
    final selected = tenant.subscriptionPlan == plan;
    return Card(
      child: ListTile(
        title: Text('${plan[0].toUpperCase()}${plan.substring(1)} · $price'),
        subtitle: Text(features),
        trailing: selected
            ? const Text('Current')
            : TextButton(
                onPressed: () async {
                  await ref.read(intelligenceRepositoryProvider).upgradePlan(tenant.id, plan);
                  ref.invalidate(currentTenantProvider);
                  ref.invalidate(availableTenantsProvider);
                  ref.invalidate(tenantSubscriptionProvider(tenant.id));
                },
                child: Text(plan == 'basic' ? 'Downgrade' : 'Upgrade'),
              ),
      ),
    );
  }
}
