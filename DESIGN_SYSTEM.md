# BiConcept design system

Warm soft-UI (neumorphic) tokens. Use these files and `App*` widgets instead of one-off colors or raw Material chrome.

## Tokens

| Token | Light | Dark |
|---|---|---|
| Background | `#F7F3EE` warm cream | `#1A1A1A` |
| Surface | `#FCFAF8` off-white card | `#2A2A2A` |
| Primary | `#0B5C5E` dark teal | `#4DB6AC` |
| Pressed | `#094A4C` | `#3A9A91` |
| Text | `#2D2A26` | `#EAEAEA` |
| Secondary text | `#7A746E` | `#B0AAA4` |
| Border | `#E6DFD8` | `#3A3A3A` |
| Error / success / warning | `#B83A3A` / `#3A7D5C` / `#D48A3A` | lighter mates |

Typography is Manrope: H1 32 bold, H2 24 bold, H3 20 semibold, H4 16 semibold, body 16/14/12, buttons 14 semibold uppercase + 0.5 tracking.

Spacing: 4 / 8 / 12 / 16 / 24 / 32 / 48. Radii: 4 / 8 / 12 / 16 / 24. Shadows: dual light+dark offsets (levels 2–5) or inset for inputs and pressed buttons.

Defined in `lib/core/theme/`.

## Components

```dart
AppPrimaryButton(label: 'Sign in', onPressed: submit, loading: busy);
AppSecondaryButton(label: 'Cancel', onPressed: pop);
AppTextField(label: 'Email', hint: 'name@firm.in');
AppSurfaceCard(child: content);
AppEmptyState(title: 'Nothing yet', actionLabel: 'Create', onAction: create);
showAppModal(context: context, title: 'Confirm', child: body);
showAppToast(context, message: 'Saved', tone: AppToastTone.success);
```

Chat: `AppChatBubble` — sender teal + white, receiver surface + charcoal, 16px corners with a 4px “tail”.

## Do

- Read colors from `AppPalette.of(context)` so dark mode works.
- Keep 48×48 touch targets.
- Wrap heavy shadows in `RepaintBoundary` (already done on cards and primary buttons).

## Don’t

- Hardcode coral/navy leftovers (`#E8877A`, `#101218`).
- Store API secrets in theme or widgets.
- Change repository or routing code to “make it look right”.

`ThemeData` in `AppTheme.light()` / `AppTheme.dark()` restyles Material `FilledButton`, `TextField`, `Card`, `Dialog`, and `SnackBar` app-wide. Firm branding can still tint primary via `themeFromBrandingProvider`.
