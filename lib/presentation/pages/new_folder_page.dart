import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/category.dart';
import '../state/folder_controller.dart';
import '../widgets/folder_card.dart';

/// Form page for creating a new folder (architecture §4, IP-0032).
///
/// Fields: name, category (segmented buttons), colour swatch (12 presets),
/// icon picker (grid of 19 icons). [PopScope] blocks back navigation when the
/// form is dirty — shows a "Discard changes?" confirmation sheet.
class NewFolderPage extends ConsumerStatefulWidget {
  const NewFolderPage({super.key});

  @override
  ConsumerState<NewFolderPage> createState() => _NewFolderPageState();
}

class _NewFolderPageState extends ConsumerState<NewFolderPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  Category _category = Category.work;
  Color _color = AppColors.folderSwatches.first;
  String _iconName = 'briefcase';
  bool _saving = false;

  bool get _isDirty =>
      _nameCtrl.text.trim().isNotEmpty ||
      _category != Category.work ||
      _color != AppColors.folderSwatches.first ||
      _iconName != 'briefcase';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Back guard ─────────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Abandonner ?',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Les modifications non enregistrées seront perdues.',
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Continuer'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Abandonner'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    return result == true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Convert Color to 6-char hex without '#'.
    final hex = _color.value.toRadixString(16).padLeft(8, '0').substring(2);

    await ref.read(folderControllerProvider.notifier).createFolder(
          name: _nameCtrl.text.trim(),
          category: _category,
          colorHex: hex,
          iconName: _iconName,
        );

    if (mounted) context.pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nouveau dossier'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              TextButton(
                onPressed: _save,
                child: const Text('Créer'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Preview card ─────────────────────────────────────────────
              _PreviewCard(
                name: _nameCtrl.text.isEmpty ? 'Aperçu' : _nameCtrl.text,
                color: _color,
                iconName: _iconName,
              ),
              const SizedBox(height: 24),

              // ── Name field ───────────────────────────────────────────────
              _SectionLabel('Nom du dossier'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ex: Réunions clients',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 24),

              // ── Category picker ──────────────────────────────────────────
              _SectionLabel('Catégorie'),
              const SizedBox(height: 12),
              _CategoryPicker(
                selected: _category,
                onSelect: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 24),

              // ── Colour swatches ──────────────────────────────────────────
              _SectionLabel('Couleur'),
              const SizedBox(height: 12),
              _ColorSwatches(
                selected: _color,
                onSelect: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 24),

              // ── Icon picker ──────────────────────────────────────────────
              _SectionLabel('Icône'),
              const SizedBox(height: 12),
              _IconPicker(
                selected: _iconName,
                accentColor: _color,
                onSelect: (n) => setState(() => _iconName = n),
              ),
              const SizedBox(height: 32),

              // ── Primary CTA ──────────────────────────────────────────────
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('Créer le dossier'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Preview card ───────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.name,
    required this.color,
    required this.iconName,
  });
  final String name;
  final Color color;
  final String iconName;

  @override
  Widget build(BuildContext context) {
    final dimColor = color.withAlpha(179);
    final textColor = AppColors.contrastOn(color);
    return Center(
      child: SizedBox(
        width: 160,
        height: 140,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, dimColor],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(77),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(folderIconForName(iconName),
                    color: textColor, size: 20),
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

// ── Category picker ────────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onSelect});
  final Category selected;
  final void Function(Category) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Category.values.map((c) {
        final isSelected = c == selected;
        return ChoiceChip(
          label: Text(c.label),
          selected: isSelected,
          onSelected: (_) => onSelect(c),
          selectedColor:
              AppColors.forCategoryEnum(c).withAlpha(51),
          labelStyle: TextStyle(
            color: isSelected
                ? AppColors.forCategoryEnum(c)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}

// ── Colour swatches ────────────────────────────────────────────────────────────

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.selected, required this.onSelect});
  final Color selected;
  final void Function(Color) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppColors.folderSwatches.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onSelect(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: c.withAlpha(102),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check_rounded,
                    color: AppColors.contrastOn(c), size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Icon picker ────────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selected,
    required this.accentColor,
    required this.onSelect,
  });
  final String selected;
  final Color accentColor;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFolderIconNames.map((name) {
        final isSelected = name == selected;
        return GestureDetector(
          onTap: () => onSelect(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              folderIconForName(name),
              color: isSelected
                  ? AppColors.contrastOn(accentColor)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
        );
      }).toList(),
    );
  }
}
