import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/features/catalog/presentation/providers/portfolio_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/portfolio_card.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';

class PortfolioListScreen extends ConsumerStatefulWidget {
  const PortfolioListScreen({super.key});

  @override
  ConsumerState<PortfolioListScreen> createState() => _PortfolioListScreenState();
}

class _PortfolioListScreenState extends ConsumerState<PortfolioListScreen> {
  String? _type;
  String? _location;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicPortfolioProvider);
    final items = async.valueOrNull ?? const [];
    final types = {for (final item in items) item.projectType}.where((v) => v.isNotEmpty).toList()..sort();
    final locations = {for (final item in items) item.location ?? ''}.where((v) => v.isNotEmpty).toList()..sort();
    final years = {for (final item in items) item.year}.whereType<int>().toList()..sort();
    final visible = items.where((item) {
      if (_type != null && item.projectType != _type) return false;
      if (_location != null && item.location != _location) return false;
      if (_year != null && item.year != _year) return false;
      return true;
    }).toList();
    return PublicShell(
      title: 'Portfolio | BiConcept',
      description: 'Selected architecture and interior projects by BiConcept.',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Portfolio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(label: const Text('All types'), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
              for (final type in types)
                FilterChip(label: Text(type), selected: _type == type, onSelected: (_) => setState(() => _type = type)),
              FilterChip(label: const Text('All locations'), selected: _location == null, onSelected: (_) => setState(() => _location = null)),
              for (final location in locations)
                FilterChip(label: Text(location), selected: _location == location, onSelected: (_) => setState(() => _location = location)),
              FilterChip(label: const Text('All years'), selected: _year == null, onSelected: (_) => setState(() => _year = null)),
              for (final year in years)
                FilterChip(label: Text('$year'), selected: _year == year, onSelected: (_) => setState(() => _year = year)),
            ],
          ),
          const SizedBox(height: 16),
          CatalogAsync(
            value: async,
            builder: (_) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in visible)
                  SizedBox(
                    width: 320,
                    child: PortfolioCard(
                      item: item,
                      onTap: () => context.go('/portfolio/${item.slug}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
