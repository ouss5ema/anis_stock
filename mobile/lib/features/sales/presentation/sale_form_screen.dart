import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/document_line_card.dart';
import 'package:stock_management/core/widgets/pickers.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/customer.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/home/presentation/home_screen.dart';
import 'package:stock_management/features/sales/presentation/sales_screen.dart';

class SaleFormScreen extends ConsumerStatefulWidget {
  const SaleFormScreen({super.key});

  @override
  ConsumerState<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends ConsumerState<SaleFormScreen> {
  Customer? _customer;
  final _notesController = TextEditingController();
  final _lines = <DraftLine>[];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _total => addMoney(_lines.map((line) => line.total));

  bool _exceedsStock(DraftLine line) {
    return greaterThanMoney(line.quantity, line.product.currentStock);
  }

  String _stockError(DraftLine line) {
    return 'Stock disponible : ${formatDt(line.product.currentStock)} ${unitLabel(line.product.unit)}';
  }

  Future<void> _addProduct() async {
    final product = await pickProduct(context, ref, showSalePrice: true);
    if (product == null) return;
    setState(() {
      _lines.add(DraftLine(product: product, unitPrice: formatDt(product.salePrice)));
    });
  }

  Future<void> _save() async {
    if (_customer == null) {
      setState(() => _error = 'Choisissez un client');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Ajoutez au moins un produit');
      return;
    }
    if (_lines.any((line) => !isPositiveMoney(line.quantity))) {
      setState(() => _error = 'Chaque quantité doit être supérieure à 0');
      return;
    }
    final overflow = _lines.where(_exceedsStock).toList();
    if (overflow.isNotEmpty) {
      setState(() => _error = _stockError(overflow.first));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(saleServiceProvider).create({
        'customerId': _customer!.id,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'items': _lines
            .map(
              (line) => {
                'productId': line.product.id,
                'quantity': line.quantity,
                'unitPrice': line.unitPrice,
              },
            )
            .toList(),
      });
      if (!mounted) return;
      ref.invalidate(salesProvider);
      ref.invalidate(dashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vente enregistrée · Stock mis à jour')),
      );
      context.pop();
    } on ApiException catch (error) {
      setState(() => _error = userFacingMessage(error));
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Vérifiez votre connexion Internet.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        children: [
          AppCard(
            onTap: () async {
              final customer = await pickCustomer(context, ref);
              if (customer != null) setState(() => _customer = customer);
            },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(_customer?.name ?? 'Choisir un client'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un produit'),
          ),
          const SizedBox(height: 12),
          if (_lines.isEmpty)
            const EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'Aucun produit',
              subtitle: 'Ajoutez les articles vendus.',
            ),
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final overflow = _exceedsStock(line);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DocumentLineCard(
                line: line,
                showStock: true,
                stockError: overflow,
                stockErrorText: overflow ? _stockError(line) : null,
                onQuantityChanged: (value) => setState(() => line.quantity = value),
                onPriceChanged: (value) => setState(() => line.unitPrice = value),
                onRemove: () => setState(() => _lines.removeAt(index)),
              ),
            );
          }),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_customer?.name ?? 'Aucun client'} · ${_lines.length} ligne(s)',
                textAlign: TextAlign.center,
              ),
              Text(
                'Total ${formatDtLabel(_total)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer la vente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
