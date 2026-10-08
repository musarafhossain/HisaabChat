import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/color_palette.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show toHexColor;
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';

/// Settings → Categories: Expense / Income tabs, add, edit, archive.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Categories', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Expense'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'New category',
            onPressed: () {
              final type = DefaultTabController.of(context).index == 0 ? CategoryType.expense : CategoryType.income;
              unawaited(showCategoryForm(context, type: type));
            },
            child: const Icon(AppIcons.add),
          ),
          body: const TabBarView(
            children: [
              _CategoryList(type: CategoryType.expense),
              _CategoryList(type: CategoryType.income),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider);
    final all = (categories.value ?? const <TxnCategory>[]).where((c) => c.type == type).toList();
    if (categories.value == null) return Center(child: CircularProgressIndicator(color: colors.primary));

    final active = all.where((c) => !c.archived).toList();
    final archived = all.where((c) => c.archived).toList();

    Widget tile(TxnCategory category, int index) => FadeSlideIn(
      index: index,
      child: Opacity(
        opacity: category.archived ? 0.6 : 1,
        child: ChatTile(
          leading: IconAvatar(icon: AppIcons.byKey(category.icon), color: category.color),
          title: category.name,
          subtitle: category.archived ? 'Archived · hidden from pickers' : null,
          onTap: () => showCategoryForm(context, existing: category, type: type),
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final (i, category) in active.indexed) tile(category, i),
            if (archived.isNotEmpty) ...[
              const SectionLabel('Archived'),
              for (final category in archived) tile(category, 0),
            ],
          ],
        ),
      ),
    );
  }
}

/// Add/edit a category: name, color, icon (sheet on phones, dialog otherwise).
Future<void> showCategoryForm(BuildContext context, {required CategoryType type, TxnCategory? existing}) {
  final form = _CategoryForm(type: type, existing: existing);
  if (context.windowClass == WindowClass.compact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: form,
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: form),
    ),
  );
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({required this.type, this.existing});

  final CategoryType type;
  final TxnCategory? existing;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late Color _color = widget.existing?.color ?? kPaletteColors.first;
  late String _icon = widget.existing?.icon ?? 'category';
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = error.fieldErrors;
        _error = error.fieldErrors.isEmpty ? error.message : null;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(categoriesProvider.notifier);
    final body = {'name': _name.text.trim(), 'color': toHexColor(_color), 'icon': _icon};
    await _run(() async {
      if (widget.existing == null) {
        await controller.create({...body, 'type': widget.type.api});
      } else {
        await controller.updateCategory(widget.existing!.id, body);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final existing = widget.existing;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconAvatar(icon: AppIcons.byKey(_icon), color: _color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    existing == null
                        ? 'New ${widget.type == CategoryType.income ? 'income' : 'expense'} category'
                        : 'Edit category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SectionLabel('Name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: 'e.g. Pets', errorText: _fieldErrors['name']),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SectionLabel('Color'),
            ColorPalettePicker(selected: _color, onChanged: (color) => setState(() => _color = color)),
            const SectionLabel('Icon'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final key in AppIcons.categoryChoices)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _icon = key),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: key == _icon ? _color.withValues(alpha: 0.2) : colors.inputFill,
                      child: Icon(
                        AppIcons.byKey(key),
                        size: 20,
                        color: key == _icon ? _color : colors.textSecondary,
                        fill: key == _icon ? 1 : 0,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
            SubmitButton(label: existing == null ? 'Add category' : 'Save', loading: _saving, onPressed: _save),
            if (existing != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => _run(
                        () => ref
                            .read(categoriesProvider.notifier)
                            .setArchived(existing.id, archived: !existing.archived),
                      ),
                icon: const Icon(AppIcons.archive),
                label: Text(existing.archived ? 'Unarchive category' : 'Archive category'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
