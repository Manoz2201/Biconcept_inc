import 'package:biconcept/features/auth/domain/deep_link_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses verification links only when userId and secret are present', () {
    final valid = DeepLinkPayload.tryParse(
      Uri.parse('biconcept://verify?userId=abc&secret=tok'),
    );
    expect(valid?.kind, DeepLinkKind.verify);
    expect(valid?.isValid, isTrue);

    final missing = DeepLinkPayload.tryParse(Uri.parse('biconcept://verify?userId=abc'));
    expect(missing?.isValid, isFalse);
  });

  test('parses GitHub Pages HTTPS invite and verify paths', () {
    expect(
      DeepLinkPayload.tryParse(
        Uri.parse(
          'https://manoz2201.github.io/Biconcept_inc/register?userId=u&secret=s&membershipId=m&teamId=firm_staff',
        ),
      )?.kind,
      DeepLinkKind.invite,
    );
    expect(
      DeepLinkPayload.tryParse(
        Uri.parse('https://manoz2201.github.io/Biconcept_inc/verify-email?userId=u&secret=s'),
      )?.kind,
      DeepLinkKind.verify,
    );
  });

  test('parses invite and reset-password hosts', () {
    expect(
      DeepLinkPayload.tryParse(
        Uri.parse('biconcept://invite?userId=u&secret=s&membershipId=m&teamId=firm_staff'),
      )?.kind,
      DeepLinkKind.invite,
    );
    expect(
      DeepLinkPayload.tryParse(
        Uri.parse('biconcept://reset-password?userId=u&secret=s'),
      )?.kind,
      DeepLinkKind.resetPassword,
    );
  });
}
