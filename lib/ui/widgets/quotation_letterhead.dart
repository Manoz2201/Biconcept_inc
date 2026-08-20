import 'package:flutter/material.dart';

import '../../export/quotation_layout.dart';
import '../../models/company_profile.dart';
import '../../models/estimate_document.dart';

const _teal = Color(0xFF2EC4B6);
const _headerHeight = 112.0;
const _logoHeight = 96.0;

class QuotationLetterhead extends StatelessWidget {
  const QuotationLetterhead({
    super.key,
    required this.client,
    required this.project,
    required this.date,
    required this.companyAddress,
    required this.companyPhone,
    required this.estimateType,
    this.onEstimateTypeTap,
  });

  final String client;
  final String project;
  final DateTime date;
  final String companyAddress;
  final String companyPhone;
  final String estimateType;
  final VoidCallback? onEstimateTypeTap;

  @override
  Widget build(BuildContext context) {
    final address = resolveCompanyAddress(draftAddress: companyAddress);
    final phone = resolveCompanyPhone(draftPhone: companyPhone);
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: _headerHeight,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    companyLogoAsset,
                    height: _logoHeight,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    filterQuality: FilterQuality.high,
                  ),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: onEstimateTypeTap,
                        child: Text(
                          normalizeEstimateType(estimateType).toUpperCase(),
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detail('Client', client.isEmpty ? '—' : client),
                      if (project.trim().isNotEmpty) _detail('Project', project),
                      _detail('Date', quotationDate(date)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    companyContactLine(phone),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: _teal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}
