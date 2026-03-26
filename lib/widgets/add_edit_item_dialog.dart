import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_item.dart';

class AddEditItemDialog extends StatefulWidget {
  final ShoppingItem? item;
  const AddEditItemDialog({super.key, this.item});

  @override
  State<AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends State<AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _estimatedCtrl;
  late TextEditingController _actualCtrl;
  late TextEditingController _notesCtrl;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _estimatedCtrl = TextEditingController(
      text: item != null ? item.estimatedPrice.toStringAsFixed(2) : '',
    );
    _actualCtrl = TextEditingController(
      text: item?.actualPrice != null
          ? item!.actualPrice!.toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    _selectedCategory = item?.category ?? kCategories.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _estimatedCtrl.dispose();
    _actualCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final existing = widget.item;
      final now = DateTime.now().toUtc();
      final result = ShoppingItem(
        id: existing?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        category: _selectedCategory,
        estimatedPrice: double.parse(_estimatedCtrl.text),
        actualPrice: _actualCtrl.text.isNotEmpty
            ? double.parse(_actualCtrl.text)
            : null,
        isBought: existing?.isBought ?? false,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Item' : 'Add Item',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: _dec('Item Name', Icons.shopping_bag_outlined),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _dec('Category', Icons.category_outlined),
                items: kCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Text(kCategoryIcons[c] ?? '📦'),
                            const SizedBox(width: 8),
                            Text(c),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _estimatedCtrl,
                      decoration: _dec('Estimated', Icons.attach_money),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _actualCtrl,
                      decoration: _dec('Actual', Icons.price_check),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                decoration: _dec('Notes (optional)', Icons.notes_outlined),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(isEdit ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
}