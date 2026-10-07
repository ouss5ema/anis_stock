import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/dates.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/partner_stats.dart';
import 'package:stock_management/data/models/supplier.dart';
import 'package:stock_management/data/services/service_providers.dart';

class SuppliersQuery {
  const SuppliersQuery({this.search = '', this.type});

  final String search;
  final String? type;

  @override
  bool operator ==(Object other) => other is SuppliersQuery && other.search == search && other.type == type;

  @override
  int get hashCode => Object.hash(search, type);
}

final suppliersProvider = FutureProvider.family<PaginatedResult<Supplier>, SuppliersQuery>((ref, query) {
  return ref.watch(supplierServiceProvider).list(search: query.search, type: query.type, includeInactive: true);
});

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _search = '';
  String? _type;

  String _typeLabel(String type) {
    switch (type) {
      case 'TABAC':
        return 'Tabac';
      case 'TELECOM':
        return 'Télécom';
      default:
        return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = SuppliersQuery(search: _search, type: _type);
    final suppliers = ref.watch(suppliersProvider(query));
    final active = [
      if (_search.isNotEmpty) 'Recherche : $_search',
      if (_type != null) 'Type : ${_typeLabel(_type!)}',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/suppliers/new');
          ref.invalidate(suppliersProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SearchField(hint: 'Rechercher', onChanged: (value) => setState(() => _search = value)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChoice(label: 'Tous', selected: _type == null, onSelected: () => setState(() => _type = null)),
                FilterChoice(label: 'Tabac', selected: _type == 'TABAC', onSelected: () => setState(() => _type = 'TABAC')),
                FilterChoice(label: 'Télécom', selected: _type == 'TELECOM', onSelected: () => setState(() => _type = 'TELECOM')),
                FilterChoice(label: 'Autre', selected: _type == 'OTHER', onSelected: () => setState(() => _type = 'OTHER')),
              ],
            ),
          ),
          ActiveFiltersBar(
            labels: active,
            onReset: () => setState(() {
              _search = '';
              _type = null;
            }),
          ),
          Expanded(
            child: suppliers.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Aucun fournisseur trouvé',
                    subtitle: 'Essayez de modifier votre recherche ou vos filtres.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  itemCount: data.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final supplier = data.items[index];
                    return AppCard(
                      onTap: () => context.push('/suppliers/${supplier.id}/edit'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplier.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(_typeLabel(supplier.type)),
                          if (supplier.phone != null) Text(supplier.phone!),
                          if (!supplier.isActive) const Text('Inactif'),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(message: userFacingMessage(error)),
            ),
          ),
        ],
      ),
    );
  }
}

class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplierId});

  final String? supplierId;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'OTHER';
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  PartnerStats? _stats;
  List<SupplierProductLink> _products = [];

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) {
      ref.read(supplierServiceProvider).getById(widget.supplierId!).then((supplier) {
        if (!mounted) return;
        setState(() {
          _name.text = supplier.name;
          _phone.text = supplier.phone ?? '';
          _email.text = supplier.email ?? '';
          _address.text = supplier.address ?? '';
          _notes.text = supplier.notes ?? '';
          _type = supplier.type;
          _isActive = supplier.isActive;
          _stats = supplier.stats;
          _products = supplier.products;
          _loading = false;
        });
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _error = userFacingMessage(error);
          _loading = false;
        });
      });
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Nom requis');
      return;
    }
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'type': _type,
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'isActive': _isActive,
    };
    try {
      if (widget.supplierId == null) {
        await ref.read(supplierServiceProvider).create(body);
      } else {
        await ref.read(supplierServiceProvider).update(widget.supplierId!, body);
      }
      if (mounted) context.pop();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.supplierId == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'TABAC', child: Text('Tabac')),
              DropdownMenuItem(value: 'TELECOM', child: Text('Télécom')),
              DropdownMenuItem(value: 'OTHER', child: Text('Autre')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'OTHER'),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
          const SizedBox(height: 12),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            value: _isActive,
            onChanged: (value) async {
              if (!value) {
                final confirmed = await confirmAction(
                  context,
                  title: 'Désactiver le fournisseur',
                  message: 'Ce fournisseur ne pourra plus être sélectionné pour un achat.',
                );
                if (!confirmed) return;
              }
              setState(() => _isActive = value);
            },
          ),
          if (_stats != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activité', style: Theme.of(context).textTheme.titleMedium),
                  Text('${_stats!.count} achat(s)'),
                  Text('Total ${formatDtLabel(_stats!.totalAmount)}'),
                  if (_stats!.lastDate != null)
                    Text('Dernier achat : ${formatDate(_stats!.lastDate!)}${_stats!.lastReference != null ? ' · ${_stats!.lastReference}' : ''}'),
                ],
              ),
            ),
          ],
          if (_products.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Produits fournis', style: Theme.of(context).textTheme.titleMedium),
                  ..._products.map((item) => Text(item.productName)),
                ],
              ),
            ),
          ],
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
