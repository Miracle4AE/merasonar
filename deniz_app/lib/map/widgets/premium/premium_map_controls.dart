import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class PremiumMapSlider extends StatelessWidget {
  const PremiumMapSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.valueLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String Function(double value)? valueLabel;

  @override
  Widget build(BuildContext context) {
    final formatted = valueLabel?.call(value) ?? value.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.caption)),
            Text(
              formatted,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accentTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accentTeal,
            inactiveTrackColor: AppColors.borderSoft(alpha: 0.2),
            thumbColor: AppColors.accentTeal,
            overlayColor: AppColors.accentTeal.withValues(alpha: 0.12),
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class PremiumMapSwitch extends StatelessWidget {
  const PremiumMapSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.caption)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accentTeal,
          activeTrackColor: AppColors.accentTeal.withValues(alpha: 0.35),
        ),
      ],
    );
  }
}

class PremiumMapCategoryChip extends StatelessWidget {
  const PremiumMapCategoryChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onChanged,
      selectedColor: color.withValues(alpha: 0.22),
      checkmarkColor: color,
      side: BorderSide(
        color: selected ? color : AppColors.borderSoft(alpha: 0.25),
      ),
      label: Text(label, style: AppTextStyles.caption),
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
    );
  }
}
