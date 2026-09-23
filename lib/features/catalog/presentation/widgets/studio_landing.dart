import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/appwrite_client.dart';
import '../../../../models/company_profile.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/built_in_services.dart';
import '../../domain/portfolio_item.dart';
import '../../domain/service_item.dart';
import '../providers/services_provider.dart';
import 'enquiry_form.dart';
import 'public_shell.dart';
import 'service_card.dart';

const studioInk = Color(0xFF1C1916);
const studioCream = Color(0xFFF7F3EE);

class LandingBand extends StatelessWidget {
  const LandingBand({
    super.key,
    required this.child,
    this.color,
    this.padding,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Material(
      color: color ?? AppPalette.of(context).backgroundBase,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: padding ?? EdgeInsets.fromLTRB(compact ? 20 : 40, 56, compact ? 20 : 40, 56),
            child: child,
          ),
        ),
      ),
    );
  }
}

class LandingKicker extends StatelessWidget {
  const LandingKicker({super.key, required this.text, this.light = false});

  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: light ? studioCream.withValues(alpha: 0.62) : AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }
}

class LandingHero extends StatelessWidget {
  const LandingHero({
    super.key,
    required this.onStartProject,
    required this.onViewServices,
    this.coverUrl,
  });

  final VoidCallback onStartProject;
  final VoidCallback onViewServices;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < AppBreakpoints.compact;
    final short = size.height < 760;
    final titleSize = short ? 32.0 : compact ? 40.0 : 64.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LandingKicker(text: 'Architecture  ·  Interiors  ·  Noida', light: true),
        if (short) const SizedBox(height: 28) else const Spacer(),
        Text(
          'Homes designed as one complete whole.',
          style: TextStyle(
            color: studioCream,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.02,
            letterSpacing: -1.4,
          ),
        ).easySeoH1,
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Interiors planned, detailed, and delivered from first sketch through handover. '
            'You always know the scope, the timing, and the cost.',
            style: TextStyle(color: studioCream.withValues(alpha: 0.78), fontSize: compact ? 16 : 18, height: 1.5),
          ).easySeoP,
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              key: const Key('landing-start-project'),
              onPressed: onStartProject,
              style: FilledButton.styleFrom(
                backgroundColor: studioCream,
                foregroundColor: studioInk,
                minimumSize: const Size(160, 48),
              ),
              child: const Text('Start a project'),
            ),
            OutlinedButton(
              key: const Key('landing-login'),
              onPressed: () => context.go('/login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: studioCream,
                side: BorderSide(color: studioCream.withValues(alpha: 0.55)),
                minimumSize: const Size(120, 48),
              ),
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: onViewServices,
              style: TextButton.styleFrom(foregroundColor: studioCream),
              child: const Text('View services'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _HeroPill(index: '01', label: 'Architecture', onPressed: onViewServices),
            _HeroPill(index: '02', label: 'Design', onPressed: onViewServices),
            _HeroPill(index: '03', label: 'Delivery', onPressed: () => context.go('/services')),
          ],
        ),
      ],
    );

    final band = LandingBand(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(compact ? 20 : 40, compact ? 28 : 56, compact ? 20 : 40, 40),
      child: content,
    );

    return SizedBox(
      height: short ? null : (size.height < 640 ? 640 : size.height * 0.92),
      width: double.infinity,
      child: Stack(
        fit: short ? StackFit.loose : StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: studioInk)),
          ),
          if (coverUrl != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      studioInk.withValues(alpha: coverUrl == null ? 1 : 0.55),
                      studioInk.withValues(alpha: 0.88),
                      studioInk,
                    ],
                  ),
                ),
              ),
            ),
          ),
          band,
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.index, required this.label, required this.onPressed});

  final String index;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: studioCream.withValues(alpha: 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: Text(
        '$index  $label',
        style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.6),
      ),
    );
  }
}

class LandingProjects extends StatelessWidget {
  const LandingProjects({super.key, required this.items});

  final List<PortfolioItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return LandingBand(
      color: studioInk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'Projects', light: true),
          const SizedBox(height: 12),
          Text(
            'Work that stays composed from drawing to site.',
            style: TextStyle(
              color: studioCream,
              fontSize: compact ? 28 : 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ).easySeoH2,
          const SizedBox(height: 28),
          SizedBox(
            height: compact ? 420 : 480,
            child: PageView.builder(
              controller: PageController(viewportFraction: compact ? 0.92 : 0.72),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _ProjectSlide(item: item),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/portfolio'),
            style: TextButton.styleFrom(foregroundColor: studioCream),
            child: const Text('View all projects'),
          ),
        ],
      ),
    );
  }
}

class _ProjectSlide extends ConsumerWidget {
  const _ProjectSlide({required this.item});

  final PortfolioItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageRepositoryProvider);
    final url = item.coverImageId.isEmpty
        ? null
        : storage.getFilePreviewUrl(
            AppwriteService.portfolioImagesBucket,
            item.coverImageId,
            width: 1200,
            height: 800,
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/portfolio/${item.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url == null
                    ? const ColoredBox(color: Color(0xFF2A2622))
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF2A2622)),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(item.title, style: const TextStyle(color: studioCream, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                if (item.area != null && item.area!.trim().isNotEmpty)
                  _Stat(label: 'Area', value: item.area!),
                if (item.location != null && item.location!.trim().isNotEmpty)
                  _Stat(label: 'City', value: item.location!),
                if (item.year != null) _Stat(label: 'Year', value: '${item.year}'),
                _Stat(label: 'Type', value: item.projectType),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: studioCream.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: studioCream, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class LandingComposition extends StatelessWidget {
  const LandingComposition({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return LandingBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'Composed'),
          const SizedBox(height: 12),
          Text(
            'A home is a composition.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 32 : 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ).easySeoH2,
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'In a well-composed interior, nothing is accidental. Proportion sets the structure, '
              'material sets the tone, and light shapes the space. We begin with how the home should work, '
              'refine how it should feel, and keep every decision priced through the build.',
              style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.6),
            ).easySeoP,
          ),
        ],
      ),
    );
  }
}

class LandingServices extends StatelessWidget {
  const LandingServices({super.key, required this.items});

  final List<ServiceItem> items;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final services = items.isEmpty ? builtInServices : items;
    final featured = _featuredServices(services);
    return LandingBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'Services'),
          const SizedBox(height: 12),
          Text(
            'What we plan, build, and finish.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 32 : 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ).easySeoH2,
          const SizedBox(height: 8),
          Text(
            'Architecture, construction, renovation, interiors, and commercial fit-outs — quoted before work starts.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ).easySeoP,
          const SizedBox(height: 28),
          const _PracticeRow(),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 700 ? 2 : 1;
              const gap = 14.0;
              final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in featured)
                    SizedBox(
                      width: width,
                      child: ServiceCard(
                        item: item,
                        onTap: () => context.go('/services/${item.slug}'),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.go('/services'),
            child: Text('See all ${services.length} services'),
          ),
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('01', 'Architecture', 'Planning, vastu, municipal drawings, and the invisible layer that makes daily life easy.'),
      ('02', 'Design', 'Material, light, and proportion — interiors that stay calm and age well.'),
      ('03', 'Delivery', 'Civil, renovation, and site supervision so the built room matches the quoted one.'),
    ];
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    Widget pane((String, String, String) item) {
      final column = InkWell(
        onTap: () => context.go('/services'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.$1, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(item.$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(item.$3, style: TextStyle(color: AppColors.muted, height: 1.5)),
          ],
        ),
      );
      return compact ? column : Expanded(child: column);
    }

    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 0 : 28, height: compact ? 24 : 0),
          pane(items[i]),
        ],
      ],
    );
  }
}

class LandingProcess extends StatelessWidget {
  const LandingProcess({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    const steps = [
      ('01', 'One responsible lead', 'A single studio contact from brief to handover — no handoffs between drawing and site.'),
      ('02', 'Structured process', 'Concept, estimate, drawings, and execution each have a sign-off. Nothing moves without yours.'),
      ('03', 'Changes and costs — always visible', 'Every revision is documented and priced before work. No surprises on the invoice.'),
      ('04', 'Quality on site', 'We visit, check against drawing, and keep the contractor on the approved set.'),
    ];
    return LandingBand(
      color: studioInk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'Approach', light: true),
          const SizedBox(height: 12),
          Text(
            'Controlled delivery.\nCalm by design.',
            style: TextStyle(
              color: studioCream,
              fontSize: compact ? 32 : 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ).easySeoH2,
          const SizedBox(height: 12),
          Text(
            'You always know what is happening, when, and what it costs.',
            style: TextStyle(color: studioCream.withValues(alpha: 0.72), height: 1.5),
          ),
          const SizedBox(height: 32),
          for (final step in steps) ...[
            _ProcessRow(index: step.$1, title: step.$2, body: step.$3),
            Divider(color: studioCream.withValues(alpha: 0.12), height: 36),
          ],
        ],
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.index, required this.title, required this.body});

  final String index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final titleText = Text(title, style: const TextStyle(color: studioCream, fontSize: 22, fontWeight: FontWeight.w700));
    final bodyText = Text(body, style: TextStyle(color: studioCream.withValues(alpha: 0.7), height: 1.5));
    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? null : 72,
          child: Text(index, style: TextStyle(color: studioCream.withValues(alpha: 0.5), fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: compact ? 0 : 16, height: compact ? 8 : 0),
        compact ? titleText : Expanded(child: titleText),
        SizedBox(width: compact ? 0 : 24, height: compact ? 8 : 0),
        compact ? bodyText : Expanded(child: bodyText),
      ],
    );
  }
}

class LandingAbout extends StatelessWidget {
  const LandingAbout({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return LandingBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'Studio'),
          const SizedBox(height: 12),
          Text(
            'About us.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 32 : 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ).easySeoH2,
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'BiConcept is a single-studio practice in Sector 59, Noida. We take homes and workplaces '
              'from first sketch through a priced estimate and a finished site — architecture, interiors, '
              'and delivery in one place.',
              style: TextStyle(color: AppColors.muted, height: 1.6, fontSize: 16),
            ).easySeoP,
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 32,
            runSpacing: 20,
            children: const [
              _AboutStat(value: 'Noida', label: 'Studio'),
              _AboutStat(value: 'NCR', label: 'Projects'),
              _AboutStat(value: '1', label: 'Responsible lead'),
              _AboutStat(value: '3', label: 'Practice layers'),
            ],
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.go('/about'),
            child: const Text('Read our story'),
          ),
        ],
      ),
    );
  }
}

class _AboutStat extends StatelessWidget {
  const _AboutStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class LandingFaq extends StatelessWidget {
  const LandingFaq({super.key});

  static const items = [
    (
      'Do you only design, or do you manage the build?',
      'Both. Design, estimate, and site delivery can be commissioned together or as separate blocks. '
          'Civil work is run with a contractor we coordinate — you stay with one studio lead.',
    ),
    (
      'What do I receive in a design project?',
      'A concept, 3D views where needed, and working drawings: layout, furniture, lighting, finishes, '
          'and a brand-wise BOQ you can price or ask us to execute.',
    ),
    (
      'How is the estimate prepared?',
      'From the approved drawings and a rate card — quantity × rate, not a lump sum guessed on site. '
          'Changes after sign-off are priced before they are built.',
    ),
    (
      'Can we start if we only know the requirement?',
      'Yes. Use the form on this page. After you create an account you can also send a detailed service '
          'request with rooms, photos, and a preferred budget.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LandingBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'FAQs'),
          const SizedBox(height: 12),
          Text(
            'Questions clients often ask',
            style: TextStyle(color: AppColors.text, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.6),
          ).easySeoH2,
          const SizedBox(height: 16),
          for (final item in items)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: AppColors.outline),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 16),
                title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.$2, style: TextStyle(color: AppColors.muted, height: 1.55)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class LandingRequirements extends StatelessWidget {
  const LandingRequirements({super.key, this.signedIn = false, this.appPath = '/login'});

  final bool signedIn;
  final String appPath;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;
    return LandingBand(
      color: AppPalette.of(context).surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingKicker(text: 'Get in touch'),
          const SizedBox(height: 12),
          Text(
            'Start with a conversation.',
            style: TextStyle(color: AppColors.text, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          ).easySeoH2,
          const SizedBox(height: 8),
          Text(
            'Share a few details about the property. We will come back with a clear next step.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ).easySeoP,
          const SizedBox(height: 28),
          Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              wide ? const Expanded(flex: 3, child: EnquiryForm()) : const EnquiryForm(),
              SizedBox(width: wide ? 40 : 0, height: wide ? 0 : 28),
              wide ? Expanded(flex: 2, child: _LoginAside(signedIn: signedIn, appPath: appPath)) : _LoginAside(signedIn: signedIn, appPath: appPath),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginAside extends StatelessWidget {
  const _LoginAside({required this.signedIn, required this.appPath});

  final bool signedIn;
  final String appPath;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Already with us?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              signedIn
                  ? 'Open the app to send a detailed service request, track quotations, and message the studio.'
                  : 'Login to send a detailed requirement, follow your quotation, and message the architect. New clients can create an account.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('landing-aside-login'),
              onPressed: () => context.go(signedIn ? appPath : '/login'),
              child: Text(signedIn ? 'Open app' : 'Login'),
            ),
            if (!signedIn) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go('/register'),
                child: const Text('Create an account'),
              ),
            ],
            const SizedBox(height: 24),
            Text(defaultCompanyAddress, style: TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => launchStudioCall(context),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
              child: Text('Call $defaultCompanyPhone'),
            ),
          ],
        ),
      ),
    );
  }
}

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LandingBand(
      color: studioInk,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(companyDisplayName, style: TextStyle(color: studioCream, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(defaultCompanyBrand, style: TextStyle(color: studioCream.withValues(alpha: 0.65))),
          const SizedBox(height: 16),
          Text(defaultCompanyAddress, style: TextStyle(color: studioCream.withValues(alpha: 0.7), height: 1.4)),
          const SizedBox(height: 8),
          Text(defaultCompanyPhone, style: TextStyle(color: studioCream.withValues(alpha: 0.7))),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            children: [
              TextButton(onPressed: () => context.go('/services'), style: TextButton.styleFrom(foregroundColor: studioCream), child: const Text('Services')),
              TextButton(onPressed: () => context.go('/portfolio'), style: TextButton.styleFrom(foregroundColor: studioCream), child: const Text('Projects')),
              TextButton(onPressed: () => context.go('/login'), style: TextButton.styleFrom(foregroundColor: studioCream), child: const Text('Login')),
              TextButton(onPressed: () => context.go('/contact'), style: TextButton.styleFrom(foregroundColor: studioCream), child: const Text('Contact')),
            ],
          ),
        ],
      ),
    );
  }
}

List<ServiceItem> _featuredServices(List<ServiceItem> items) {
  const order = [
    kServiceCategoryArchitecture,
    kServiceCategoryInteriors,
    kServiceCategoryBuilding,
    kServiceCategoryRenovation,
    kServiceCategoryCommercial,
    kServiceCategoryAddons,
  ];
  final picked = <ServiceItem>[];
  for (final category in order) {
    picked.addAll(items.where((item) => item.category == category).take(1));
    if (picked.length >= 6) break;
  }
  if (picked.length < 6) {
    for (final item in items) {
      if (picked.any((existing) => existing.id == item.id)) continue;
      picked.add(item);
      if (picked.length >= 6) break;
    }
  }
  return picked;
}

String? landingCoverUrl({
  required List<PortfolioItem> featured,
  required String Function(String bucketId, String fileId, {int? width, int? height}) preview,
}) {
  for (final item in featured) {
    if (item.coverImageId.isEmpty) continue;
    return preview(AppwriteService.portfolioImagesBucket, item.coverImageId, width: 1600, height: 1200);
  }
  return null;
}
