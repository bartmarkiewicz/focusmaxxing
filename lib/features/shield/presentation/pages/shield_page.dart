import 'package:flutter/material.dart';

class ShieldPage extends StatelessWidget {
  const ShieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Brainrot Shield',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildStatusBanner(context),
          const SizedBox(height: 20),
          _buildSectionHeader(context, 'QUICK-SHIELD PRESETS'),
          const SizedBox(height: 10),
          _buildPresetsGrid(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'PROTECTION RULES'),
          const SizedBox(height: 10),
          _buildRulesCard(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Text(
              '🛡️',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brainrot Shield Guard',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Physically intercepts addictive feeds during focus blocks and restorative breaks.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final presets = [
      ('Instagram', '📸', true),
      ('TikTok', '🎵', true),
      ('Twitter / X', '🐦', false),
      ('Reddit', '🤖', false),
      ('YouTube Shorts', '▶️', false),
      ('Mobile Games', '🎮', false),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((preset) {
        final (name, icon, isSelected) = preset;
        return FilterChip(
          selected: isSelected,
          showCheckmark: isSelected,
          checkmarkColor: colorScheme.onPrimary,
          avatar: Text(icon, style: const TextStyle(fontSize: 14)),
          label: Text(
            name,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
          selectedColor: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest,
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
          onSelected: null,
        );
      }).toList(),
    );
  }

  Widget _buildRulesCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _RuleItem(
              icon: Icons.block_rounded,
              title: 'Zero Bypass During Sessions',
              subtitle:
                  'No emergency pass or snooze options. Tapping overlay returns directly to Focusmaxxing.',
            ),
            Divider(color: colorScheme.outlineVariant, height: 20),
            const _RuleItem(
              icon: Icons.nightlife_rounded,
              title: 'Restorative Break Guard',
              subtitle:
                  'Apps remain locked through the 5-minute break until you explicitly lock in on your next block.',
            ),
            Divider(color: colorScheme.outlineVariant, height: 20),
            const _RuleItem(
              icon: Icons.shield_moon_outlined,
              title: 'Native Android Service',
              subtitle:
                  'Engineered with UsageStatsManager and SYSTEM_ALERT_WINDOW (Milestone 2 native engine).',
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
