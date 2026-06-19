import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/stage_badge.dart';
import 'lead_detail_screen.dart';

/// Browsable, searchable, filterable list of leads.
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Lead> _leads = [];
  bool _loading = true;
  String? _error;
  String? _stageFilter;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final raw = await api.fetchLeads(
        search: _searchTerm.isEmpty ? null : _searchTerm,
        stage: _stageFilter,
      );
      if (!mounted) return;
      setState(() {
        _leads = raw
            .map((j) => Lead.fromJson(j as Map<String, dynamic>))
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchTerm = value.trim();
      _load();
    });
  }

  void _onStageFilterTap(String? stage) {
    setState(() => _stageFilter = stage);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchTerm.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _StageFilterChips(
                selected: _stageFilter,
                onChanged: _onStageFilterTap,
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
            else if (_leads.isEmpty)
              const SliverFillRemaining(
                child: _EmptyView(),
              )
            else
              SliverList.separated(
                itemCount: _leads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final lead = _leads[index];
                  return _LeadTile(
                    lead: lead,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LeadDetailScreen(leadId: lead.id),
                        ),
                      );
                    },
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _StageFilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _StageFilterChips({required this.selected, required this.onChanged});

  static const _stages = [
    {'key': null, 'label': 'All'},
    {'key': 'new', 'label': 'New'},
    {'key': 'initial', 'label': 'Initial'},
    {'key': 'interested', 'label': 'Interested'},
    {'key': 'pricing_discussion', 'label': 'Pricing'},
    {'key': 'ready_to_buy', 'label': 'Ready'},
    {'key': 'active', 'label': 'Active'},
    {'key': 'cold', 'label': 'Cold'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = _stages[index];
          final isSelected = s['key'] == selected;
          return Center(
            child: ChoiceChip(
              label: Text(s['label']!),
              selected: isSelected,
              onSelected: (_) {
                // Tapping the active "All" deselects it, which would clear
                // the filter — keep "All" sticky.
                onChanged(s['key']);
              },
            ),
          );
        },
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  const _LeadTile({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.MMMd().add_jm();
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: lead.stageColor.withOpacity(0.15),
        child: Text(
          lead.displayName.isNotEmpty
              ? lead.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: lead.stageColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        lead.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lead.phoneNumber != null)
            Text(
              lead.phoneNumber!,
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              StageBadge(stage: lead.stage, dense: true),
              const SizedBox(width: 8),
              if (lead.leadLevel != null) LeadLevelDot(level: lead.leadLevel),
              const Spacer(),
              if (lead.updatedAt != null)
                Text(
                  dateFmt.format(lead.updatedAt!.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
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
          Icon(Icons.people_outline,
              size: 56, color: Theme.of(context).hintColor),
          const SizedBox(height: 8),
          Text(
            'No leads found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting the filters or pull to refresh.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}
