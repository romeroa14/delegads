import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../models/metrics.dart';
import '../services/api_service.dart';
import '../widgets/funnel_chart.dart';
import '../widgets/stage_badge.dart';
import '../widgets/stat_card.dart';
import 'campaigns_screen.dart';
import 'designs_screen.dart';
import 'lead_detail_screen.dart';
import 'leads_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Main dashboard for the agency owner.
///
/// - Top: KPI grid (leads, campaigns, pending designs, revenue)
/// - Middle: conversion funnel
/// - Bottom: recent leads (tap to view detail)
/// - Bottom navigation: Dashboard / Leads / Campaigns / Designs / Settings
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<_DashboardData>? _future;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final api = context.read<ApiService>();
    final results = await Future.wait([
      api.fetchMetrics(),
      api.fetchLeads(page: 1),
    ]);
    final metricsJson = results[0] as Map<String, dynamic>;
    final leadsJson = results[1] as List<dynamic>;
    return _DashboardData(
      metrics: DashboardMetrics.fromJson(metricsJson),
      recentLeads: leadsJson
          .take(5)
          .map((j) => Lead.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardBody(future: _future, onRefresh: _refresh),
      const LeadsScreen(),
      const CampaignsScreen(),
      const DesignsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delegads CRM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: pages[_navIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Leads',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Campaigns',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            selectedIcon: Icon(Icons.palette),
            label: 'Designs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access the CRM.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ApiService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _DashboardData {
  final DashboardMetrics metrics;
  final List<Lead> recentLeads;
  const _DashboardData({required this.metrics, required this.recentLeads});
}

class _DashboardBody extends StatelessWidget {
  final Future<_DashboardData> future;
  final Future<void> Function() onRefresh;
  const _DashboardBody({required this.future, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<_DashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: onRefresh,
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _KpiGrid(metrics: data.metrics),
              const SizedBox(height: 16),
              _SectionTitle(title: 'Conversion Funnel'),
              const SizedBox(height: 8),
              _Card(
                child: FunnelChart(
                  stages: data.metrics.funnel,
                  max: data.metrics.funnelMax,
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: 'Recent Leads'),
              const SizedBox(height: 8),
              if (data.recentLeads.isEmpty)
                const _EmptyHint(text: 'No leads yet.')
              else
                _Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < data.recentLeads.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        _RecentLeadTile(lead: data.recentLeads[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final DashboardMetrics metrics;
  const _KpiGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: 'USD');
    return LayoutBuilder(builder: (context, constraints) {
      // 2 columns on phones, 4 on wider devices.
      final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 2 ? 1.5 : 1.7,
        children: [
          StatCard(
            icon: Icons.people_alt_outlined,
            label: 'Total Leads',
            value: '${metrics.leadsTotal}',
            subtitle: '+${metrics.leadsNewToday} today',
            color: const Color(0xFF6D28D9),
          ),
          StatCard(
            icon: Icons.campaign_outlined,
            label: 'Active Campaigns',
            value: '${metrics.campaignsActive}',
            subtitle: '${metrics.campaignsPaused} paused',
            color: const Color(0xFF3B82F6),
          ),
          StatCard(
            icon: Icons.palette_outlined,
            label: 'Pending Designs',
            value: '${metrics.designJobsPending}',
            subtitle: '${metrics.designJobsTotal} total',
            color: const Color(0xFFF59E0B),
          ),
          StatCard(
            icon: Icons.attach_money,
            label: 'Design Revenue',
            value: currency.format(metrics.designJobsRevenueTotal),
            subtitle: 'Approved',
            color: const Color(0xFF22C55E),
          ),
        ],
      );
    });
  }
}

class _RecentLeadTile extends StatelessWidget {
  final Lead lead;
  const _RecentLeadTile({required this.lead});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: lead.stageColor.withOpacity(0.15),
        child: Text(
          lead.displayName.isNotEmpty
              ? lead.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(color: lead.stageColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        lead.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          StageBadge(stage: lead.stage, dense: true),
          const SizedBox(width: 8),
          if (lead.leadLevel != null) LeadLevelDot(level: lead.leadLevel),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LeadDetailScreen(leadId: lead.id),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: child,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView so RefreshIndicator works even while loading.
      children: const [
        SizedBox(height: 200),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
        const SizedBox(height: 12),
        Text(
          'Could not load dashboard',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          error,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
    );
  }
}
