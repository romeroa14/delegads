import 'package:flutter/material.dart';

/// Domain model for a Lead in the Delegads CRM pipeline.
///
/// The CRM backend (Laravel) returns leads with these fields selected in
/// [LeadController::index]. Extra fields from the show endpoint (designJobs,
/// messages, pageAccessRequests) are intentionally ignored here — they belong
/// to the detail screen model.
class Lead {
  final int id;
  final String? clientName;
  final String? phoneNumber;
  final String stage;
  final String? intent;
  final String? leadLevel;
  final String? selectedPlan;
  final String? pageName;
  final double? confidenceScore;
  final bool botDisabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lead({
    required this.id,
    this.clientName,
    this.phoneNumber,
    required this.stage,
    this.intent,
    this.leadLevel,
    this.selectedPlan,
    this.pageName,
    this.confidenceScore,
    this.botDisabled = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Display name: prefer the human name, fall back to the phone number.
  String get displayName =>
      (clientName != null && clientName!.isNotEmpty) ? clientName! : (phoneNumber ?? 'Unknown');

  factory Lead.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Lead(
      id: (json['id'] as num).toInt(),
      clientName: json['client_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      stage: (json['stage'] as String?) ?? 'new',
      intent: json['intent'] as String?,
      leadLevel: json['lead_level'] as String?,
      selectedPlan: json['selected_plan'] as String?,
      pageName: json['page_name'] as String?,
      confidenceScore: parseDouble(json['confidence_score']),
      botDisabled: json['bot_disabled'] == true,
      createdAt: parse(json['created_at']),
      updatedAt: parse(json['updated_at']),
    );
  }

  /// Color used by the stage badge and lead cards.
  ///
  /// The palette mirrors the Filament CRM widget colors so the mobile
  /// dashboard matches what Alfredo already sees in the admin panel.
  Color get stageColor {
    switch (stage) {
      case 'new':
        return const Color(0xFF94A3B8); // slate-400
      case 'initial':
        return const Color(0xFF0EA5E9); // sky-500
      case 'interested':
        return const Color(0xFF3B82F6); // blue-500
      case 'pricing_discussion':
        return const Color(0xFFF59E0B); // amber-500
      case 'ready_to_buy':
        return const Color(0xFFF97316); // orange-500
      case 'payment_pending':
        return const Color(0xFFEAB308); // yellow-500
      case 'onboarding':
        return const Color(0xFF14B8A6); // teal-500
      case 'active':
        return const Color(0xFF22C55E); // green-500
      case 'cold':
        return const Color(0xFF64748B); // slate-500
      default:
        return const Color(0xFF9CA3AF); // gray-400
    }
  }

  /// Human-readable stage label for badges and lists.
  String get stageLabel {
    switch (stage) {
      case 'new':
        return 'New';
      case 'initial':
        return 'Initial';
      case 'interested':
        return 'Interested';
      case 'pricing_discussion':
        return 'Pricing';
      case 'ready_to_buy':
        return 'Ready';
      case 'payment_pending':
        return 'Payment';
      case 'onboarding':
        return 'Onboarding';
      case 'active':
        return 'Active';
      case 'cold':
        return 'Cold';
      default:
        return stage;
    }
  }

  /// Heat color: hot=red, warm=orange, cold=blue.
  Color? get leadLevelColor {
    switch (leadLevel) {
      case 'hot':
        return const Color(0xFFEF4444); // red-500
      case 'warm':
        return const Color(0xFFF97316); // orange-500
      case 'cold':
        return const Color(0xFF3B82F6); // blue-500
      default:
        return null;
    }
  }
}

/// Lead detail model — extends the basic Lead with relationships returned
/// by the show endpoint. Conversations are exposed as a simple shape so the
/// detail screen can render them without depending on a Conversation model.
class LeadDetail extends Lead {
  final List<LeadMessage> messages;
  final List<dynamic> designJobs;
  final List<dynamic> pageAccessRequests;

  const LeadDetail({
    required super.id,
    super.clientName,
    super.phoneNumber,
    required super.stage,
    super.intent,
    super.leadLevel,
    super.selectedPlan,
    super.pageName,
    super.confidenceScore,
    super.botDisabled,
    super.createdAt,
    super.updatedAt,
    this.messages = const [],
    this.designJobs = const [],
    this.pageAccessRequests = const [],
  });

  factory LeadDetail.fromJson(Map<String, dynamic> json) {
    final messagesRaw = json['messages'];
    final messages = <LeadMessage>[];
    if (messagesRaw is List) {
      for (final m in messagesRaw) {
        if (m is Map<String, dynamic>) {
          messages.add(LeadMessage.fromJson(m));
        }
      }
    }

    return LeadDetail(
      id: (json['id'] as num).toInt(),
      clientName: json['client_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      stage: (json['stage'] as String?) ?? 'new',
      intent: json['intent'] as String?,
      leadLevel: json['lead_level'] as String?,
      selectedPlan: json['selected_plan'] as String?,
      pageName: json['page_name'] as String?,
      confidenceScore: json['confidence_score'] is num
          ? (json['confidence_score'] as num).toDouble()
          : null,
      botDisabled: json['bot_disabled'] == true,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      messages: messages,
      designJobs: (json['design_jobs'] as List?) ?? const [],
      pageAccessRequests: (json['page_access_requests'] as List?) ?? const [],
    );
  }
}

class LeadMessage {
  final int id;
  final String? direction; // inbound | outbound
  final String? content;
  final String? platform;
  final String? status;
  final DateTime? createdAt;

  const LeadMessage({
    required this.id,
    this.direction,
    this.content,
    this.platform,
    this.status,
    this.createdAt,
  });

  factory LeadMessage.fromJson(Map<String, dynamic> json) {
    return LeadMessage(
      id: (json['id'] as num).toInt(),
      direction: json['direction'] as String?,
      content: json['content'] as String?,
      platform: json['platform'] as String?,
      status: json['status'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  bool get isInbound => direction == 'inbound';
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
