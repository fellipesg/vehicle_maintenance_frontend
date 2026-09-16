import 'package:flutter/material.dart';
import '../../models/maintenance_item.dart';
import '../../models/warranty_template.dart';

class MaintenanceItemFormDialog extends StatefulWidget {
  final MaintenanceItem? item;
  final List<WarrantyTemplate> itemWarrantyTemplates;
  final bool showWarrantyTemplates;

  const MaintenanceItemFormDialog({
    super.key,
    this.item,
    this.itemWarrantyTemplates = const [],
    this.showWarrantyTemplates = false,
  });

  @override
  State<MaintenanceItemFormDialog> createState() =>
      _MaintenanceItemFormDialogState();
}

class _MaintenanceItemFormDialogState extends State<MaintenanceItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _partNumberController = TextEditingController();
  int? _selectedWarrantyTemplateId;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description ?? '';
      _quantityController.text = widget.item!.quantity.toString();
      _unitPriceController.text = widget.item!.unitPrice.toStringAsFixed(2);
      _partNumberController.text = widget.item!.partNumber ?? '';
      _selectedWarrantyTemplateId = widget.item!.warrantyTemplateId;
    } else {
      _quantityController.text = '1';
      _unitPriceController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _partNumberController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = int.parse(_quantityController.text);
    final unitPrice = double.parse(_unitPriceController.text);
    final totalPrice = quantity * unitPrice;

    final item = MaintenanceItem(
      id: widget.item?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      partNumber: _partNumberController.text.trim().isEmpty
          ? null
          : _partNumberController.text.trim(),
      warrantyTemplateId: _selectedWarrantyTemplateId,
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item != null ? 'Editar Item' : 'Novo Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Item *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome do item';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Obrigatório';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Quantidade inválida';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Preço Unitário *',
                        border: OutlineInputBorder(),
                        prefixText: 'R\$ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Obrigatório';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Preço inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _partNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número da Peça',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.showWarrantyTemplates) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: _selectedWarrantyTemplateId,
                  decoration: const InputDecoration(
                    labelText: 'Garantia do item',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sem garantia'),
                    ),
                    ...widget.itemWarrantyTemplates.map(
                      (template) => DropdownMenuItem<int?>(
                        value: template.id,
                        child: Text(template.displayLabel),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedWarrantyTemplateId = value;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
