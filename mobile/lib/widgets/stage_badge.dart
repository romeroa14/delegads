import 'package:flutter/material.dart';

import '../models/lead.dart';

/// Colored pill showing a lead's pipeline stage.
///
/// Uses the same palette as the Filament CRM widget so the two views feel
/// consistent for the agency owner.
class StageBadge extends StatelessWidget {
  final String stage;
  final bool dense;

  const StageBadge({super.key, required this.stage, this.dense = false});

  factory StageBadge.forLead(Lead lead, {bool dense = false}) {
    return StageBadge(stage: lead.stage, dense: dense);
  }

  Color get _color {
    switch (stage) {
      case 'new':
        return const Color(0xFF94A3B8);
      case 'initial':
        return const Color(0xFF0EA5E9);
      case 'interested':
        return const Color(0xFF3B82F6);
      case 'pricing_discussion':
        return const Color(0xFFF59E0B);
      case 'ready_to_buy':
        return const Color(0xFFF97316);
      case 'payment_pending':
        return const Color(0xFFEAB308);
      case 'onboarding':
        return const Color(0xFF14B8A6);
      case 'active':
        return const Color(0xFF22C55E);
      case 'cold':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String get _label {
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

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Compact colored dot for the lead level (hot/warm/cold).
class LeadLevelDot extends StatelessWidget {
  final String? level;
  const LeadLevelDot({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();
    Color color;
    String label;
    switch (level) {
      case 'hot':
        color = const Color(0xFFEF4444);
        label = 'Hot';
        break;
      case 'warm':
        color = const Color(0xFFF97316);
        label = 'Warm';
        break;
      case 'cold':
        color = const Color(0xFF3B82F6);
        label = 'Cold';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
