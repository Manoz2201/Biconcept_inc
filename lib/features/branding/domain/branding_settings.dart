import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';

class BrandingSettings {
  const BrandingSettings({
    required this.id,
    required this.firmName,
    this.tagline,
    this.logoFileId,
    this.logoDarkFileId,
    this.faviconFileId,
    this.primaryColor = '#0B5C5E',
    this.secondaryColor = '#F3B3A8',
    this.accentColor = '#75D8BB',
    this.fontFamily,
    this.emailTemplateHeader,
    this.emailTemplateFooter,
    this.emailSignature,
    this.invoiceTemplate,
    this.customDomain,
    this.domainVerified = false,
    this.supportEmail,
    this.supportPhone,
    this.websiteUrl,
    this.socialLinks,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firmName;
  final String? tagline;
  final String? logoFileId;
  final String? logoDarkFileId;
  final String? faviconFileId;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String? fontFamily;
  final String? emailTemplateHeader;
  final String? emailTemplateFooter;
  final String? emailSignature;
  final String? invoiceTemplate;
  final String? customDomain;
  final bool domainVerified;
  final String? supportEmail;
  final String? supportPhone;
  final String? websiteUrl;
  final Map<String, String>? socialLinks;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const defaults = BrandingSettings(id: 'firm', firmName: 'BiConcept');

  Map<String, dynamic> toJson() => {
        'id': id,
        'firmName': firmName,
        'tagline': ?tagline,
        'logoFileId': ?logoFileId,
        'logoDarkFileId': ?logoDarkFileId,
        'faviconFileId': ?faviconFileId,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentColor': accentColor,
        'fontFamily': ?fontFamily,
        'emailTemplateHeader': ?emailTemplateHeader,
        'emailTemplateFooter': ?emailTemplateFooter,
        'emailSignature': ?emailSignature,
        'invoiceTemplate': ?invoiceTemplate,
        'customDomain': ?customDomain,
        'domainVerified': domainVerified,
        'supportEmail': ?supportEmail,
        'supportPhone': ?supportPhone,
        'websiteUrl': ?websiteUrl,
        'socialLinks': ?socialLinks,
        'isActive': isActive,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory BrandingSettings.fromJson(Map<String, dynamic> data) => BrandingSettings(
        id: data['id']?.toString() ?? 'firm',
        firmName: data['firmName']?.toString() ?? 'BiConcept',
        tagline: data['tagline']?.toString(),
        logoFileId: data['logoFileId']?.toString(),
        logoDarkFileId: data['logoDarkFileId']?.toString(),
        faviconFileId: data['faviconFileId']?.toString(),
        primaryColor: data['primaryColor']?.toString() ?? '#0B5C5E',
        secondaryColor: data['secondaryColor']?.toString() ?? '#F3B3A8',
        accentColor: data['accentColor']?.toString() ?? '#75D8BB',
        fontFamily: data['fontFamily']?.toString(),
        emailTemplateHeader: data['emailTemplateHeader']?.toString(),
        emailTemplateFooter: data['emailTemplateFooter']?.toString(),
        emailSignature: data['emailSignature']?.toString(),
        invoiceTemplate: data['invoiceTemplate']?.toString(),
        customDomain: data['customDomain']?.toString(),
        domainVerified: data['domainVerified'] == true,
        supportEmail: data['supportEmail']?.toString(),
        supportPhone: data['supportPhone']?.toString(),
        websiteUrl: data['websiteUrl']?.toString(),
        socialLinks: data['socialLinks'] is Map
            ? {
                for (final entry in (data['socialLinks'] as Map).entries) entry.key.toString(): entry.value.toString(),
              }
            : null,
        isActive: data['isActive'] != false,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

abstract class BrandingRepository {
  Future<AppResult<BrandingSettings>> getBrandingSettings();
  Future<AppResult<BrandingSettings>> updateBrandingSettings(Map<String, dynamic> data);
  Future<AppResult<BrandingSettings>> uploadLogo(UploadBytes file, {bool isDark = false});
  Future<AppResult<BrandingSettings>> uploadFavicon(UploadBytes file);
  Future<AppResult<BrandingSettings>> resetToDefaults();
  Future<AppResult<BrandingSettings>> verifyCustomDomain(String token);
}
