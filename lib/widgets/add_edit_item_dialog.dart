import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_item.dart';
import '../theme.dart';

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
    _nameCtrl      = TextEditingController(text: item?.name ?? '');
    _estimatedCtrl = TextEditingController(
      text: item != null ? item.estimatedPrice.toStringAsFixed(2) : '',
    );
    _actualCtrl = TextEditingController(
      text: item?.actualPrice != null ? item!.actualPrice!.toStringAsFixed(2) : '',
    );
    _notesCtrl         = TextEditingController(text: item?.notes ?? '');
    _selectedCategory  = item?.category ?? kCategories.first;
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
      Navigator.of(context).pop(ShoppingItem(
        id:             existing?.id ?? const Uuid().v4(),
        name:           _nameCtrl.text.trim(),
        category:       _selectedCategory,
        estimatedPrice: double.parse(_estimatedCtrl.text),
        actualPrice:    _actualCtrl.text.isNotEmpty ? double.parse(_actualCtrl.text) : null,
        isBought:       existing?.isBought ?? false,
        notes:          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        createdAt:      existing?.createdAt ?? now,
        updatedAt:      now,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kSheetRadius)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'EDIT' : 'NEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: context.subColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEdit ? (widget.item!.name) : 'Add item',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: context.inkColor,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.bgColor,
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Icon(Icons.close, size: 18, color: context.inkColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Name ───────────────────────────────────
              _label('Name', context),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 16, color: context.inkColor),
                decoration: _inputDec(context, 'e.g. Sourdough loaf'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // ── Category chips ─────────────────────────
              _label('Category', context),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kCategories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? context.inkColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(kChipRadius),
                        border: Border.all(
                          color: selected ? context.inkColor : context.borderColor,
                        ),
                      ),
                      child: Text(
                        '${kCategoryIcons[cat] ?? "📦"} $cat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? context.bgColor : context.inkColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // ── Estimated / Actual ─────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Estimated', context),
                        TextFormField(
                          controller: _estimatedCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 16, color: context.inkColor),
                          decoration: _inputDec(context, '0.00'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Actual', context),
                        TextFormField(
                          controller: _actualCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 16, color: context.inkColor),
                          decoration: _inputDec(context, '—'),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Notes ──────────────────────────────────
              _label('Notes', context),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 16, color: context.inkColor),
                decoration: _inputDec(context, 'Optional'),
              ),
              const SizedBox(height: 20),

              // ── Buttons ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(kInputRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text('Cancel',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.inkColor)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: context.inkColor,
                          borderRadius: BorderRadius.circular(kInputRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isEdit ? 'Save changes' : 'Add item',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.bgColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: context.subColor,
          ),
        ),
      );

  InputDecoration _inputDec(BuildContext context, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.muteColor),
        filled: true,
        fillColor: context.bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kInputRadius),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kInputRadius),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kInputRadius),
          borderSide: BorderSide(color: context.inkColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kInputRadius),
          borderSide: const BorderSide(color: Color(0xFFB91C1C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kInputRadius),
          borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
        ),
      );
}
