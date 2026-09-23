import '../../../core/result/app_result.dart';

class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.subdomain,
    this.customDomain,
    this.gstin,
    this.pan,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.logoFileId,
    this.primaryColor,
    this.subscriptionPlan = 'basic',
    this.subscriptionStatus = 'trial',
    this.trialEndsAt,
    this.maxUsers = 5,
    this.maxProjects = 10,
    this.isActive = true,
    this.settings,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String subdomain;
  final String? customDomain;
  final String? gstin;
  final String? pan;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? logoFileId;
  final String? primaryColor;
  final String subscriptionPlan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final int maxUsers;
  final int maxProjects;
  final bool isActive;
  final Map<String, dynamic>? settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subdomain': subdomain,
        'customDomain': ?customDomain,
        'gstin': ?gstin,
        'pan': ?pan,
        'address': ?address,
        'city': ?city,
        'state': ?state,
        'pincode': ?pincode,
        'logoFileId': ?logoFileId,
        'primaryColor': ?primaryColor,
        'subscriptionPlan': subscriptionPlan,
        'subscriptionStatus': subscriptionStatus,
        'trialEndsAt': ?trialEndsAt?.toUtc().toIso8601String(),
        'maxUsers': maxUsers,
        'maxProjects': maxProjects,
        'isActive': isActive,
        'settings': ?settings,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory Tenant.fromJson(Map<String, dynamic> data) => Tenant(
        id: data['id']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        subdomain: data['subdomain']?.toString() ?? '',
        customDomain: data['customDomain']?.toString(),
        gstin: data['gstin']?.toString(),
        pan: data['pan']?.toString(),
        address: data['address']?.toString(),
        city: data['city']?.toString(),
        state: data['state']?.toString(),
        pincode: data['pincode']?.toString(),
        logoFileId: data['logoFileId']?.toString(),
        primaryColor: data['primaryColor']?.toString(),
        subscriptionPlan: data['subscriptionPlan']?.toString() ?? 'basic',
        subscriptionStatus: data['subscriptionStatus']?.toString() ?? 'trial',
        trialEndsAt: DateTime.tryParse(data['trialEndsAt']?.toString() ?? ''),
        maxUsers: (data['maxUsers'] as num?)?.toInt() ?? 5,
        maxProjects: (data['maxProjects'] as num?)?.toInt() ?? 10,
        isActive: data['isActive'] != false,
        settings: data['settings'] is Map ? Map<String, dynamic>.from(data['settings'] as Map) : null,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class TenantSubscription {
  const TenantSubscription({
    required this.id,
    required this.tenantId,
    required this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.amount,
    this.currency = 'INR',
    this.paymentGateway,
    this.gatewaySubscriptionId,
    this.features,
    required this.maxUsers,
    required this.maxProjects,
    required this.maxStorageGB,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String plan;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final double amount;
  final String currency;
  final String? paymentGateway;
  final String? gatewaySubscriptionId;
  final List<String>? features;
  final int maxUsers;
  final int maxProjects;
  final int maxStorageGB;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'plan': plan,
        'status': status,
        'currentPeriodStart': currentPeriodStart.toUtc().toIso8601String(),
        'currentPeriodEnd': currentPeriodEnd.toUtc().toIso8601String(),
        'amount': amount,
        'currency': currency,
        'paymentGateway': ?paymentGateway,
        'gatewaySubscriptionId': ?gatewaySubscriptionId,
        'features': ?features,
        'maxUsers': maxUsers,
        'maxProjects': maxProjects,
        'maxStorageGB': maxStorageGB,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory TenantSubscription.fromJson(Map<String, dynamic> data) => TenantSubscription(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        plan: data['plan']?.toString() ?? 'basic',
        status: data['status']?.toString() ?? 'trial',
        currentPeriodStart: DateTime.tryParse(data['currentPeriodStart']?.toString() ?? '') ?? DateTime.now(),
        currentPeriodEnd: DateTime.tryParse(data['currentPeriodEnd']?.toString() ?? '') ?? DateTime.now(),
        amount: (data['amount'] as num?)?.toDouble() ?? 2999,
        currency: data['currency']?.toString() ?? 'INR',
        paymentGateway: data['paymentGateway']?.toString(),
        gatewaySubscriptionId: data['gatewaySubscriptionId']?.toString(),
        features: data['features'] is List ? [for (final item in data['features'] as List) item.toString()] : null,
        maxUsers: (data['maxUsers'] as num?)?.toInt() ?? 5,
        maxProjects: (data['maxProjects'] as num?)?.toInt() ?? 10,
        maxStorageGB: (data['maxStorageGB'] as num?)?.toInt() ?? 5,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class TenantUsage {
  const TenantUsage({
    required this.users,
    required this.projects,
    required this.storageGB,
    required this.aiTokens,
    required this.whatsappMessages,
    required this.userLimit,
    required this.projectLimit,
    required this.storageLimitGB,
  });

  final int users;
  final int projects;
  final double storageGB;
  final int aiTokens;
  final int whatsappMessages;
  final int userLimit;
  final int projectLimit;
  final int storageLimitGB;

  double get userRatio => userLimit == 0 ? 0 : users / userLimit;
  double get projectRatio => projectLimit == 0 ? 0 : projects / projectLimit;
}

abstract class TenantRepository {
  Future<AppResult<Tenant>> getCurrentTenant();
  Future<AppResult<Tenant>> switchTenant(String tenantId);
  Future<AppResult<List<Tenant>>> getTenants();
  Future<AppResult<Tenant>> getTenantById(String id);
  Future<AppResult<Tenant>> createTenant({required String name, required String subdomain, required String adminEmail, String plan = 'basic'});
  Future<AppResult<Tenant>> updateTenant(String id, Map<String, dynamic> data);
  Future<AppResult<void>> deleteTenant(String id);
  Future<AppResult<TenantUsage>> getTenantUsage(String tenantId);
}

abstract class SubscriptionRepository {
  Future<AppResult<TenantSubscription>> getSubscription(String tenantId);
  Future<AppResult<TenantSubscription>> createSubscription({required String tenantId, required String plan});
  Future<AppResult<TenantSubscription>> upgradePlan(String tenantId, String newPlan);
  Future<AppResult<TenantSubscription>> downgradePlan(String tenantId, String newPlan);
  Future<AppResult<TenantSubscription>> cancelSubscription(String id, {String? reason});
}
