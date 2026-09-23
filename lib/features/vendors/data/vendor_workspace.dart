import 'dart:convert';

import '../../project_vendors/domain/project_vendor.dart';
import '../../purchase_orders/domain/purchase_order.dart';
import '../../rfqs/domain/rfq.dart';
import '../../rfqs/domain/vendor_quote.dart';
import '../../vendor_bills/domain/vendor_bill.dart';
import '../../vendor_bills/domain/vendor_payment.dart';
import '../domain/vendor_rate.dart';
import '../domain/vendor_rating.dart';

class VendorWorkspace {
  VendorWorkspace({
    List<VendorRate>? rates,
    List<VendorRating>? ratings,
    List<VendorQuote>? quotes,
    List<PurchaseOrder>? purchaseOrders,
    List<VendorBill>? bills,
    List<VendorPayment>? payments,
    List<ProjectVendor>? assignments,
  })  : rates = rates ?? <VendorRate>[],
        ratings = ratings ?? <VendorRating>[],
        quotes = quotes ?? <VendorQuote>[],
        purchaseOrders = purchaseOrders ?? <PurchaseOrder>[],
        bills = bills ?? <VendorBill>[],
        payments = payments ?? <VendorPayment>[],
        assignments = assignments ?? <ProjectVendor>[];

  final List<VendorRate> rates;
  final List<VendorRating> ratings;
  final List<VendorQuote> quotes;
  final List<PurchaseOrder> purchaseOrders;
  final List<VendorBill> bills;
  final List<VendorPayment> payments;
  final List<ProjectVendor> assignments;

  factory VendorWorkspace.decode(String? raw) {
    final data = _map(raw);
    if (data == null) return VendorWorkspace();
    return VendorWorkspace(
      rates: _list(data['rates'], VendorRate.fromJson),
      ratings: _list(data['ratings'], VendorRating.fromJson),
      quotes: _list(data['quotes'], VendorQuote.fromJson),
      purchaseOrders: _list(data['purchaseOrders'], PurchaseOrder.fromJson),
      bills: _list(data['bills'], VendorBill.fromJson),
      payments: _list(data['payments'], VendorPayment.fromJson),
      assignments: _list(data['assignments'], ProjectVendor.fromJson),
    );
  }

  String encode() => jsonEncode({
        'rates': [for (final item in rates) item.toJson()],
        'ratings': [for (final item in ratings) item.toJson()],
        'quotes': [for (final item in quotes) item.toJson()],
        'purchaseOrders': [for (final item in purchaseOrders) item.toJson()],
        'bills': [for (final item in bills) item.toJson()],
        'payments': [for (final item in payments) item.toJson()],
        'assignments': [for (final item in assignments) item.toJson()],
      });
}

class RfqWorkspace {
  RfqWorkspace({List<RFQRecipient>? recipients}) : recipients = recipients ?? <RFQRecipient>[];

  final List<RFQRecipient> recipients;

  factory RfqWorkspace.decode(String? raw) {
    final data = _map(raw);
    if (data == null) return RfqWorkspace();
    return RfqWorkspace(recipients: _list(data['recipients'], RFQRecipient.fromJson));
  }

  String encode() => jsonEncode({
        'recipients': [for (final item in recipients) item.toJson()],
      });
}

Map<String, dynamic>? _map(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (item is Map) parse(Map<String, dynamic>.from(item)),
  ];
}
