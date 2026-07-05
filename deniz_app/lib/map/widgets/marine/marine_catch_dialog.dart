import 'package:deniz_app/domain/marine_catch_record.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_dialog.dart';
import 'package:flutter/material.dart';

class MarineCatchAddDialog extends StatefulWidget {
  const MarineCatchAddDialog({super.key, this.initial});

  final MarineCatchRecord? initial;

  bool get isEditMode => initial != null;

  @override
  State<MarineCatchAddDialog> createState() => _MarineCatchAddDialogState();
}

class _MarineCatchAddDialogState extends State<MarineCatchAddDialog> {
  late final TextEditingController _speciesCtrl;
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _baitCtrl;
  late final TextEditingController _methodCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _caughtAt;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _speciesCtrl = TextEditingController(text: initial?.species ?? '');
    _lengthCtrl = TextEditingController(
      text: initial?.lengthCm?.toString() ?? '',
    );
    _weightCtrl = TextEditingController(
      text: initial?.weightKg?.toString() ?? '',
    );
    _baitCtrl = TextEditingController(text: initial?.bait ?? '');
    _methodCtrl = TextEditingController(text: initial?.method ?? '');
    _notesCtrl = TextEditingController(text: initial?.notes ?? '');
    _caughtAt = initial != null
        ? DateTime.tryParse(initial.caughtAt)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
  }

  @override
  void dispose() {
    _speciesCtrl.dispose();
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
    _baitCtrl.dispose();
    _methodCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _caughtAt.toLocal(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_caughtAt.toLocal()),
    );
    if (time == null || !mounted) return;
    setState(() {
      _caughtAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc();
    });
  }

  void _submit() {
    final species = _speciesCtrl.text.trim();
    if (species.isEmpty) return;
    Navigator.pop(
      context,
      {
        'species': species,
        'length_cm': double.tryParse(_lengthCtrl.text.replaceAll(',', '.')),
        'weight_kg': double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
        'bait': _baitCtrl.text.trim(),
        'method': _methodCtrl.text.trim(),
        'caught_at': _caughtAt.toIso8601String(),
        'notes': _notesCtrl.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF142434),
      title: Text(
        widget.isEditMode ? kMarineCatchEditDialogTitle : kMarineCatchDialogTitle,
      ),
      content: PremiumErrorBoundary(
        sectionTitle: kMarineCatchDialogTitle,
        builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _speciesCtrl,
              decoration: InputDecoration(labelText: kMarineCatchSpeciesHint),
            ),
            TextField(
              controller: _lengthCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: kMarineCatchLengthHint),
            ),
            TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: kMarineCatchWeightHint),
            ),
            TextField(
              controller: _baitCtrl,
              decoration: InputDecoration(labelText: kMarineCatchBaitHint),
            ),
            TextField(
              controller: _methodCtrl,
              decoration: InputDecoration(labelText: kMarineCatchMethodHint),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(kMarineCatchDateHint),
              subtitle: Text(_caughtAt.toLocal().toString().substring(0, 16)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _pickDateTime,
              ),
            ),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: kMarineCatchNotesHint),
            ),
          ],
        ),
      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(kDialogClose)),
        FilledButton(onPressed: _submit, child: Text(kMarineCatchSaveButton)),
      ],
    );
  }
}

Future<void> showMarineCatchListSheet(
  BuildContext context, {
  required List<MarineCatchRecord> catches,
  required Future<void> Function(String catchId) onDelete,
  Future<void> Function(MarineCatchRecord catchRecord)? onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF0B1A2A),
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                kMarineCatchListTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            if (catches.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  kMarineCatchListEmpty,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: catches.length,
                  itemBuilder: (_, i) {
                    final item = catches[i];
                    final weight = item.weightKg != null
                        ? '${item.weightKg!.toStringAsFixed(1)} kg'
                        : '—';
                    return ListTile(
                      title: Text(item.species, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '$weight · ${item.caughtAt}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onEdit != null)
                            Semantics(
                              button: true,
                              label: kMarineCatchEditDialogTitle,
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                onPressed: () async {
                                  await onEdit(item);
                                },
                              ),
                            ),
                          Semantics(
                            button: true,
                            label: kMarineCatchDeleteConfirmTitle,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final ok = await PremiumDialog.showConfirm(
                                  ctx,
                                  title: kMarineCatchDeleteConfirmTitle,
                                  message: kMarineCatchDeleteConfirmMessage,
                                  tone: PremiumDialogTone.danger,
                                  destructive: true,
                                );
                                if (ok != true) return;
                                await onDelete(item.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

Color marineSpotLevelColor(String? level) {
  switch (level) {
    case 'Legendary':
      return const Color(0xFFFFD700);
    case 'Elite':
      return const Color(0xFFCE93D8);
    case 'Gold':
      return const Color(0xFFFFB74D);
    case 'Silver':
      return const Color(0xFFB0BEC5);
    default:
      return const Color(0xFF8D6E63);
  }
}

String marineSpotLevelLabelTr(String? level) {
  switch (level) {
    case 'Legendary':
      return kMarineSpotLevelLegendary;
    case 'Elite':
      return kMarineSpotLevelElite;
    case 'Gold':
      return kMarineSpotLevelGold;
    case 'Silver':
      return kMarineSpotLevelSilver;
    default:
      return kMarineSpotLevelBronze;
  }
}
