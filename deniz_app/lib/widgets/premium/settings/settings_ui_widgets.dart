import 'package:deniz_app/domain/app_settings.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Ayarlar ekranı bölüm kartı.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.92),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderSoft(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showHelper = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showHelper;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.bodyPremium),
      subtitle: showHelper && subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.bodyPremium.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSegmentedControl<T> extends StatelessWidget {
  const SettingsSegmentedControl({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
  });

  final String label;
  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T value) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyPremium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: options.map((opt) {
            return ChoiceChip(
              selected: opt == selected,
              label: Text(labelBuilder(opt)),
              onSelected: (_) => onSelected(opt),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Kart yoğunluğu ile ölçeklenmiş spacing.
double settingsAwareSpacing(BuildContext context, double base) {
  final density =
      AppSettingsScope.maybeOf(context)?.settings.cardDensity ??
          CardDensityLevel.standard;
  return base * density.spacingMultiplier;
}

/// Kart padding çarpanı.
double settingsCardPadding(BuildContext context) {
  final density =
      AppSettingsScope.maybeOf(context)?.settings.cardDensity ??
          CardDensityLevel.standard;
  return AppSpacing.cardPadding * density.cardPaddingMultiplier;
}

/// Büyük dokunma alanları tercihi.
double settingsTouchTargetSize(BuildContext context) {
  final large =
      AppSettingsScope.maybeOf(context)?.settings.largeTouchTargets ?? false;
  return large ? 48 : 36;
}

/// Helper metin görünürlüğü (ayarlar ekranı hariç genel UI).
bool settingsShowHelperTexts(BuildContext context) {
  return AppSettingsScope.maybeOf(context)?.settings.showHelperTexts ?? true;
}

/// Durum chip görünürlüğü.
bool settingsShowStatusChips(BuildContext context) {
  return AppSettingsScope.maybeOf(context)?.settings.showStatusChips ?? true;
}
