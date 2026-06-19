import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/design_job.dart';
import '../services/api_service.dart';

/// Pending design jobs that need an approval decision.
///
/// NOTE: approve/reject endpoints aren't implemented on the CRM yet — this
/// screen shows the data and the buttons are wired with a TODO toast so the
/// UI flow is ready to go the moment the backend lands.
class DesignsScreen extends StatefulWidget {
  const DesignsScreen({super.key});

  @override
  State<DesignsScreen> createState() => _DesignsScreenState();
}

class _DesignsScreenState extends State<DesignsScreen> {
  List<DesignJob> _jobs = [];
  bool _loading = true;
  String? _error;
  bool _onlyPending = true;

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
      final raw = await api.fetchDesignJobs();
      if (!mounted) return;
      setState(() {
        _jobs = raw
            .map((j) => DesignJob.fromJson(j as Map<String, dynamic>))
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

  List<DesignJob> get _visible {
    if (!_onlyPending) return _jobs;
    return _jobs.where((j) => j.isPending).toList();
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Design Jobs',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Pending only'),
                      selected: _onlyPending,
                      onSelected: (v) => setState(() => _onlyPending = v),
                    ),
                  ],
                ),
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
            else if (_visible.isEmpty)
              const SliverFillRemaining(child: _EmptyView())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _DesignJobCard(
                      job: _visible[index],
                      onApprove: () => _onDecision(_visible[index], true),
                      onReject: () => _onDecision(_visible[index], false),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onDecision(DesignJob job, bool approve) {
    // TODO(backend): wire to PUT /api/v1/design-jobs/{id}/approve|reject
    // once the CRM exposes those endpoints. For now show a friendly notice.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approve
              ? 'Approve flow not yet wired on the backend.'
              : 'Reject flow not yet wired on the backend.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DesignJobCard extends StatelessWidget {
  final DesignJob job;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DesignJobCard({
    required this.job,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.MMMd().add_jm();
    final leadLabel = job.leadClientName ?? job.leadPhoneNumber ?? 'Lead #${job.leadId ?? '?'}';
    final placeholderBg = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade100;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (job.resultUrl != null && job.resultUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: placeholderBg,
                  alignment: Alignment.center,
                  child: Image.network(
                    job.resultUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                    loadingBuilder: (_, child, p) {
                      if (p == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeChip(isAi: job.isAi),
                    const SizedBox(width: 8),
                    _StatusPill(job: job),
                    const Spacer(),
                    if (job.price != null)
                      Text(
                        '\$${job.price!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Lead: $leadLabel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (job.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Submitted ${dateFmt.format(job.createdAt!.toLocal())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
                ],
                if (job.isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final bool isAi;
  const _TypeChip({required this.isAi});
  @override
  Widget build(BuildContext context) {
    final color = isAi ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAi ? Icons.auto_awesome : Icons.brush, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isAi ? 'AI' : 'Human',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final DesignJob job;
  const _StatusPill({required this.job});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: job.statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        job.statusLabel,
        style: TextStyle(
          color: job.statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
          Icon(Icons.palette_outlined,
              size: 56, color: Theme.of(context).hintColor),
          const SizedBox(height: 8),
          Text('No design jobs to review',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}
