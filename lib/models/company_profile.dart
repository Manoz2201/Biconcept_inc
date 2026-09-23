const defaultCompanyBrand = 'Biconcept Architects & Interiors';
const defaultCompanyAddress = 'D-41, Second Floor, Sector-59, Noida- 201301';
const defaultCompanyPhone = '+91 8178869148';
const companyDisplayName = 'BiConcept';
const companyLogoAsset = 'assets/data/logo.png';
const companyMarkAsset = 'assets/data/logo.png';

String resolveCompanyAddress({String? prefsAddress, String? draftAddress}) {
  for (final value in [prefsAddress, draftAddress]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return defaultCompanyAddress;
}

String resolveCompanyPhone({String? prefsPhone, String? draftPhone}) {
  for (final value in [prefsPhone, draftPhone]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return defaultCompanyPhone;
}

String companyContactLine(String phone) => 'Contact no. : $phone';
