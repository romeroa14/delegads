import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/stage_badge.dart';

/// Lead detail with conversations, design jobs, and metadata.
class LeadDetailScreen extends StatefulWidget {
  final int leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Future<LeadDetail>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<LeadDetail> _load() async {
    final api = context.read<ApiService>();
    final json = await api.fetchLead(widget.leadId);
    return LeadDetail.fromJson(json);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<LeadDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final lead = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(lead: lead),
                const SizedBox(height: 16),
                _MetadataSection(lead: lead),
                const SizedBox(height: 16),
                if (lead.designJobs.isNotEmpty) ...[
                  _SectionTitle(title: 'Design Jobs (${lead.designJobs.length})'),
                  const SizedBox(height: 8),
                  ..._designJobWidgets(lead),
                  const SizedBox(height: 16),
                ],
                _SectionTitle(
                    title: 'Conversations (${lead.messages.length})'),
                const SizedBox(height: 8),
                if (lead.messages.isEmpty)
                  _EmptyHint(text: 'No conversations yet.')
                else
                  ...lead.messages.map((m) => _MessageBubble(message: m)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _designJobWidgets(LeadDetail lead) {
    return lead.designJobs.map<Widget>((raw) {
      if (raw is! Map) return const SizedBox.shrink();
      final type = raw['type']?.toString();
      final status = raw['status']?.toString();
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(
              type == 'ai' ? Icons.auto_awesome : Icons.brush,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (type ?? 'design').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (raw['price'] != null)
                    Text(
                      '\$${raw['price']}',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                ],
              ),
            ),
            Text(
              status ?? '',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _Header extends StatelessWidget {
  final Lead lead;
  const _Header({required this.lead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lead.stageColor.withOpacity(0.15), lead.stageColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lead.stageColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: lead.stageColor,
            child: Text(
              lead.displayName.isNotEmpty
                  ? lead.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.displayName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (lead.phoneNumber != null)
                  Text(
                    lead.phoneNumber!,
                    style: TextStyle(color: theme.hintColor),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StageBadge(stage: lead.stage),
                    const SizedBox(width: 8),
                    if (lead.leadLevel != null) LeadLevelDot(level: lead.leadLevel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  final Lead lead;
  const _MetadataSection({required this.lead});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_jm();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(title: 'Details'),
          const SizedBox(height: 12),
          if (lead.intent != null) _kv('Intent', lead.intent!),
          if (lead.selectedPlan != null) _kv('Selected plan', lead.selectedPlan!),
          if (lead.pageName != null) _kv('Page', lead.pageName!),
          if (lead.confidenceScore != null)
            _kv('AI confidence', lead.confidenceScore!.toStringAsFixed(2)),
          if (lead.createdAt != null)
            _kv('Created', dateFmt.format(lead.createdAt!.toLocal())),
          if (lead.updatedAt != null)
            _kv('Updated', dateFmt.format(lead.updatedAt!.toLocal())),
          _kv('Bot disabled', lead.botDisabled ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final LeadMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isInbound = message.isInbound;
    final align = isInbound ? Alignment.centerLeft : Alignment.centerRight;
    final scheme = Theme.of(context).colorScheme;
    // surfaceVariant exists in older Flutter; surfaceContainerHighest in 3.22+.
    final inboundBg = scheme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : Colors.grey.shade200;
    final bubbleColor = isInbound
        ? inboundBg
        : scheme.primary.withOpacity(0.12);
    final textColor = isInbound
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.primary;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isInbound ? 4 : 14),
            bottomRight: Radius.circular(isInbound ? 14 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content != null)
              Text(
                message.content!,
                style: TextStyle(color: textColor, height: 1.35),
              ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat.MMMd().add_jm().format(message.createdAt!.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
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

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
    );
  }
}
