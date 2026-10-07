import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/number_input.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/numeric_field.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/product.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';
import 'package:stock_management/core/data_refresh.dart';

class AdjustStockScreen extends ConsumerStatefulWidget {
  const AdjustStockScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends ConsumerState<AdjustStockScreen> {
  Product? _product;
  String? _loadError;
  String _direction = 'out';
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyController.addListener(() => setState(() {}));
    ref.read(productServiceProvider).getById(widget.productId).then((product) {
      if (mounted) setState(() => _product = product);
    }).catchError((error) {
      if (mounted) setState(() => _loadError = userFacingMessage(error));
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String? get _previewNewStock {
    if (_product == null || !isPositiveMoney(_qtyController.text)) {
      return null;
    }
    final current = parseMoney(_product!.currentStock);
    final qty = parseMoney(_qtyController.text);
    final next = _direction == 'in' ? current + qty : current - qty;
    return formatDt(next.toString());
  }

  Future<void> _save() async {
    if (ref.read(authProvider).user?.role != 'ADMIN') {
      setState(() => _error = 'Seul un administrateur peut ajuster le stock.');
      return;
    }
    if (_reasonController.text.trim().length < 3) {
      setState(() => _error = 'Indiquez une raison (3 caractères min.)');
      return;
    }
    if (!isPositiveMoney(_qtyController.text)) {
      setState(() => _error = 'La quantité doit être supérieure à 0');
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Confirmer l’ajustement',
      message:
          'Produit : ${_product?.name ?? '-'}\nType : ${_direction == 'in' ? 'Entrée' : 'Sortie'}\nQuantité : ${_qtyController.text}\nStock actuel : ${formatDt(_product?.currentStock)}\nNouveau stock : ${_previewNewStock ?? '-'}',
    );
    if (!confirmed) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(stockOpsServiceProvider).adjust(
            productId: widget.productId,
            direction: _direction,
            quantity: decimalForApi(_qtyController.text),
            reason: _reasonController.text.trim(),
          );
      if (!mounted) return;
      invalidateOperationalData(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajustement enregistré · Stock mis à jour')),
      );
      context.pop();
    } on ApiException catch (error) {
      setState(() => _error = userFacingMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustement de stock')),
        body: ErrorView(message: _loadError!),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustement de stock')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_product?.name ?? 'Chargement...', style: Theme.of(context).textTheme.titleLarge),
          if (_product != null) Text('Stock actuel : ${formatDt(_product!.currentStock)}'),
          if (_previewNewStock != null) Text('Nouveau stock : $_previewNewStock'),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'in', label: Text('Entrée')),
              ButtonSegment(value: 'out', label: Text('Sortie')),
            ],
            selected: {_direction},
            onSelectionChanged: (value) => setState(() => _direction = value.first),
          ),
          const SizedBox(height: 12),
          DecimalTextField(
            controller: _qtyController,
            labelText: 'Quantité',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Raison (obligatoire)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Enregistrer l’ajustement'),
          ),
        ],
      ),
    );
  }
}
