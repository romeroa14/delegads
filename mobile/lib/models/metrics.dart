/// Aggregated dashboard data returned by GET /api/v1/metrics.
///
/// Mirrors the Laravel [MetricsController::index] response shape.
class DashboardMetrics {
  final int leadsTotal;
  final int leadsNewToday;
  final Map<String, int> leadsByStage;
  final Map<String, int> leadsByLevel;

  final int designJobsTotal;
  final int designJobsPending;
  final double designJobsRevenueTotal;
  final Map<String, int> designJobsByStatus;

  final int campaignsTotal;
  final int campaignsActive;
  final int campaignsPaused;
  final Map<String, int> campaignsByStatus;

  final DateTime? generatedAt;

  const DashboardMetrics({
    this.leadsTotal = 0,
    this.leadsNewToday = 0,
    this.leadsByStage = const {},
    this.leadsByLevel = const {},
    this.designJobsTotal = 0,
    this.designJobsPending = 0,
    this.designJobsRevenueTotal = 0,
    this.designJobsByStatus = const {},
    this.campaignsTotal = 0,
    this.campaignsActive = 0,
    this.campaignsPaused = 0,
    this.campaignsByStatus = const {},
    this.generatedAt,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseCountMap(dynamic v) {
      if (v is! Map) return const <String, int>{};
      return v.map((k, val) => MapEntry(k.toString(), (val as num).toInt()));
    }

    final leads = (json['leads'] as Map?)?.cast<String, dynamic>() ?? const {};
    final design = (json['design_jobs'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final campaigns = (json['campaigns'] as Map?)?.cast<String, dynamic>() ??
        const {};

    return DashboardMetrics(
      leadsTotal: (leads['total'] as num?)?.toInt() ?? 0,
      leadsNewToday: (leads['new_today'] as num?)?.toInt() ?? 0,
      leadsByStage: parseCountMap(leads['by_stage']),
      leadsByLevel: parseCountMap(leads['by_level']),
      designJobsTotal: (design['total'] as num?)?.toInt() ?? 0,
      designJobsPending: (design['pending'] as num?)?.toInt() ?? 0,
      designJobsRevenueTotal:
          (design['revenue_total'] as num?)?.toDouble() ?? 0,
      designJobsByStatus: parseCountMap(design['by_status']),
      campaignsTotal: (campaigns['total'] as num?)?.toInt() ?? 0,
      campaignsActive: (campaigns['active'] as num?)?.toInt() ?? 0,
      campaignsPaused: (campaigns['paused'] as num?)?.toInt() ?? 0,
      campaignsByStatus: parseCountMap(campaigns['by_status']),
      generatedAt: json['generated_at'] is String
          ? DateTime.tryParse(json['generated_at'] as String)
          : null,
    );
  }

  /// Pipeline stage counts ordered for the conversion funnel view.
  /// Stages absent from the backend response default to 0.
  List<FunnelStage> get funnel {
    const order = [
      'new',
      'initial',
      'interested',
      'pricing_discussion',
      'ready_to_buy',
      'payment_pending',
      'active',
    ];
    return order
        .map((s) => FunnelStage(stage: s, count: leadsByStage[s] ?? 0))
        .toList();
  }

  /// Most populated stage — used to size the funnel bars.
  int get funnelMax {
    final values = leadsByStage.values;
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }
}

class FunnelStage {
  final String stage;
  final int count;

  const FunnelStage({required this.stage, required this.count});

  String get label {
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
      case 'active':
        return 'Active';
      default:
        return stage;
    }
  }
}
