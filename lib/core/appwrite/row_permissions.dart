import 'package:appwrite/appwrite.dart';

import '../config/env.dart';

List<String> clientDocumentPermissions(
  String clientId, {
  bool clientCanUpdate = true,
}) {
  return [
    Permission.read(Role.user(clientId)),
    Permission.read(Role.team(Env.teamStaff)),
    if (clientCanUpdate) Permission.update(Role.user(clientId)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'architect')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
    Permission.delete(Role.team(Env.teamStaff, 'admin')),
    Permission.delete(Role.team(Env.teamStaff, 'owner')),
    Permission.delete(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

/// Permissions a signed-in client can actually assign. Appwrite rejects
/// `Role.team(...)` grants from users who are not on that team (401).
List<String> clientOwnedRowPermissions(String clientId) {
  return [
    Permission.read(Role.user(clientId)),
    Permission.update(Role.user(clientId)),
  ];
}

const kMaxUploadBytes = 25 * 1024 * 1024;
const kMaxProjectUploadBytes = 50 * 1024 * 1024;

const kAllowedUploadExtensions = {
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'dwg',
  'dxf',
  'doc',
  'docx',
  'xls',
  'xlsx',
};

const kAllowedProjectUploadExtensions = {
  ...kAllowedUploadExtensions,
  'zip',
  'rar',
};

String sanitizeUploadName(String filename) {
  final base = filename.split(RegExp(r'[\\/]')).last.trim();
  final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return cleaned.isEmpty ? 'upload.bin' : cleaned;
}

void validateUpload(List<int> bytes, String filename) {
  if (bytes.length > kMaxUploadBytes) {
    throw AppwriteException('File must be 25 MB or smaller', 400);
  }
  final ext = filename.split('.').last.toLowerCase();
  if (!kAllowedUploadExtensions.contains(ext)) {
    throw AppwriteException('That file type is not allowed', 400);
  }
}

void validateProjectUpload(List<int> bytes, String filename) {
  if (bytes.length > kMaxProjectUploadBytes) {
    throw AppwriteException('File must be 50 MB or smaller', 400);
  }
  final ext = filename.split('.').last.toLowerCase();
  if (!kAllowedProjectUploadExtensions.contains(ext)) {
    throw AppwriteException('That file type is not allowed', 400);
  }
}

List<String> projectRowPermissions(String clientId, {String? assigneeId}) {
  return [
    Permission.read(Role.user(clientId)),
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'architect')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
    if (assigneeId != null && assigneeId.isNotEmpty) Permission.update(Role.user(assigneeId)),
    Permission.delete(Role.team(Env.teamStaff, 'admin')),
    Permission.delete(Role.team(Env.teamStaff, 'owner')),
    Permission.delete(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

List<String> vendorRowPermissions(String? vendorUserId) {
  return [
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
    Permission.delete(Role.team(Env.teamStaff, 'admin')),
    Permission.delete(Role.team(Env.teamStaff, 'owner')),
    Permission.delete(Role.team(Env.teamStaff, 'super_admin')),
    if (vendorUserId != null && vendorUserId.isNotEmpty) ...[
      Permission.read(Role.user(vendorUserId)),
      Permission.update(Role.user(vendorUserId)),
    ],
  ];
}

List<String> invoiceRowPermissions(String clientId) {
  return [
    Permission.read(Role.user(clientId)),
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'accountant')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

List<String> financeRowPermissions() {
  return [
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'accountant')),
    Permission.update(Role.team(Env.teamStaff, 'architect')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

List<String> intelligenceRowPermissions() {
  return [
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'architect')),
    Permission.update(Role.team(Env.teamStaff, 'accountant')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

List<String> platformRowPermissions() {
  return [
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'accountant')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

List<String> complianceRowPermissions() {
  return [
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'accountant')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
  ];
}

const kAllowedGstUploadExtensions = {'json', 'csv', 'xlsx', 'pdf', 'zip'};

void validateGstUpload(List<int> bytes, String filename) {
  if (bytes.length > kMaxUploadBytes) {
    throw AppwriteException('File must be 25 MB or smaller', 400);
  }
  final ext = filename.split('.').last.toLowerCase();
  if (!kAllowedGstUploadExtensions.contains(ext)) {
    throw AppwriteException('Use JSON, CSV, XLSX, PDF, or ZIP', 400);
  }
}

final tanPattern = RegExp(r'^[A-Z]{4}[0-9]{5}[A-Z]$');

bool isValidTan(String? value) => value == null || value.isEmpty || tanPattern.hasMatch(value.toUpperCase());

List<String> rfqRowPermissions(Iterable<String> vendorUserIds) {
  final unique = {for (final id in vendorUserIds) if (id.isNotEmpty) id};
  return [
    Permission.read(Role.team(Env.teamStaff)),
    Permission.update(Role.team(Env.teamStaff, 'admin')),
    Permission.update(Role.team(Env.teamStaff, 'architect')),
    Permission.update(Role.team(Env.teamStaff, 'owner')),
    Permission.update(Role.team(Env.teamStaff, 'super_admin')),
    Permission.delete(Role.team(Env.teamStaff, 'admin')),
    Permission.delete(Role.team(Env.teamStaff, 'owner')),
    Permission.delete(Role.team(Env.teamStaff, 'super_admin')),
    for (final id in unique) Permission.read(Role.user(id)),
  ];
}

final gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

bool isValidGstin(String? value) => value == null || value.isEmpty || gstinPattern.hasMatch(value.toUpperCase());
bool isValidPan(String? value) => value == null || value.isEmpty || panPattern.hasMatch(value.toUpperCase());
bool isValidIfsc(String? value) => value == null || value.isEmpty || ifscPattern.hasMatch(value.toUpperCase());

({double subtotal, double taxAmount, double total}) pricedTotals(Iterable<({double quantity, double rate})> items, double taxRate) {
  final subtotal = items.fold<double>(0, (sum, item) => sum + item.quantity * item.rate);
  final taxAmount = subtotal * (taxRate / 100);
  return (subtotal: subtotal, taxAmount: taxAmount, total: subtotal + taxAmount);
}

List<String> changeRequestRowPermissions(String clientId) {
  return [
    ...projectRowPermissions(clientId),
    Permission.update(Role.user(clientId)),
  ];
}

String formatDisplayDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  return '$day ${months[local.month - 1]} ${local.year}';
}

String formatMoney(double value) => '₹${value.toStringAsFixed(2)}';

List<String> directMessagePermissions(String senderId, String receiverId) {
  return [
    Permission.read(Role.user(senderId)),
    Permission.read(Role.user(receiverId)),
    Permission.update(Role.user(senderId)),
    Permission.update(Role.user(receiverId)),
    Permission.delete(Role.user(senderId)),
  ];
}
