import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';

class ShieldPage extends StatelessWidget {
  const ShieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brainrot Shield'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildStatusBanner(),
          const SizedBox(height: 20),
          _buildSectionHeader('QUICK-SHIELD PRESETS'),
          const SizedBox(height: 10),
          _buildPresetsGrid(),
          const SizedBox(height: 24),
          _buildSectionHeader('PROTECTION RULES'),
          const SizedBox(height: 10),
          _buildRulesCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildStatusBanner() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Text(
              '🛡️',
              style: TextStyle(fontSize: 28),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brainrot Shield Guard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHighContrast,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Physically intercepts addictive feeds during focus blocks and restorative breaks.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
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

  Widget _buildPresetsGrid() {
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
          checkmarkColor: AppColors.surfaceMidnight,
          avatar: Text(icon, style: const TextStyle(fontSize: 14)),
          label: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.surfaceMidnight
                  : AppColors.textHighContrast,
            ),
          ),
          selectedColor: AppColors.accentLockIn,
          backgroundColor: AppColors.surfaceRaised,
          side: BorderSide(
            color: isSelected
                ? AppColors.accentLockIn
                : AppColors.surfaceHairline,
          ),
          onSelected: null,
        );
      }).toList(),
    );
  }

  Widget _buildRulesCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _RuleItem(
              icon: Icons.block_rounded,
              title: 'Zero Bypass During Sessions',
              subtitle:
                  'No emergency pass or snooze options. Tapping overlay returns directly to Focusmaxxing.',
            ),
            Divider(color: AppColors.surfaceHairline, height: 20),
            _RuleItem(
              icon: Icons.nightlife_rounded,
              title: 'Restorative Break Guard',
              subtitle:
                  'Apps remain locked through the 5-minute break until you explicitly lock in on your next block.',
            ),
            Divider(color: AppColors.surfaceHairline, height: 20),
            _RuleItem(
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
  final IconData icon;
  final String title;
  final String subtitle;

  const _RuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accentLockIn),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHighContrast,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
