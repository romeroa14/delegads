import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../services/api_service.dart';

/// Active campaigns overview. Read-only on mobile — edits stay in the web CRM.
class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final raw = await api.fetchCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = raw
            .map((j) => Campaign.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Campaign> get _filtered {
    if (_statusFilter == null) return _campaigns;
    return _campaigns
        .where((c) =>
            (c.campaignStatus ?? '').toUpperCase() ==
            _statusFilter!.toUpperCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _StatusFilterChips(
                selected: _statusFilter,
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorView(message: _error!, onRetry: _load),
              )
            else if (_filtered.isEmpty)
              const SliverFillRemaining(child: _EmptyView())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _CampaignCard(campaign: _filtered[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _StatusFilterChips({required this.selected, required this.onChanged});

  static const _options = [
    {'key': null, 'label': 'All'},
    {'key': 'ACTIVE', 'label': 'Active'},
    {'key': 'PAUSED', 'label': 'Paused'},
    {'key': 'DELETED', 'label': 'Deleted'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final o = _options[index];
          return ChoiceChip(
            label: Text(o['label']!),
            selected: o['key'] == selected,
            onSelected: (_) => onChanged(o['key']),
          );
        },
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.MMMd();
    final dateRange = (campaign.dateStart != null && campaign.dateStop != null)
        ? '${dateFmt.format(campaign.dateStart!)} – ${dateFmt.format(campaign.dateStop!)}'
        : (campaign.dateRange ?? '—');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: campaign.statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.campaign, color: campaign.statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.campaignName ?? 'Untitled campaign',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (campaign.facebookAccountName != null)
                      Text(
                        campaign.facebookAccountName!,
                        style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusPill(campaign: campaign),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'Spend',
                value: '\$${campaign.spend.toStringAsFixed(2)}',
              ),
              _Stat(
                label: 'Impr.',
                value: _compactNumber(campaign.impressions),
              ),
              _Stat(
                label: 'Clicks',
                value: _compactNumber(campaign.clicks),
              ),
              _Stat(
                label: 'CTR',
                value: '${campaign.ctr.toStringAsFixed(2)}%',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.date_range, size: 14, color: theme.hintColor),
              const SizedBox(width: 4),
              Text(
                dateRange,
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactNumber(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(0);
  }
}

class _StatusPill extends StatelessWidget {
  final Campaign campaign;
  const _StatusPill({required this.campaign});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: campaign.statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        campaign.campaignStatus ?? 'UNKNOWN',
        style: TextStyle(
          color: campaign.statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined,
              size: 56, color: Theme.of(context).hintColor),
          const SizedBox(height: 8),
          Text('No campaigns yet',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
