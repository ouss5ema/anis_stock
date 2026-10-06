import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/dates.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/customer.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/partner_stats.dart';
import 'package:stock_management/data/services/service_providers.dart';

final customersProvider = FutureProvider.family<PaginatedResult<Customer>, String>((ref, search) {
  return ref.watch(customerServiceProvider).list(search: search, includeInactive: true);
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';

  String _typeLabel(String type) {
    switch (type) {
      case 'FREESHOP':
        return 'Free shop';
      case 'SUPERMARKET':
        return 'Supermarché';
      case 'SHOP':
        return 'Magasin';
      default:
        return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider(_search));
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/customers/new');
          ref.invalidate(customersProvider(_search));
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SearchField(hint: 'Rechercher', onChanged: (value) => setState(() => _search = value)),
          ),
          Expanded(
            child: customers.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(icon: Icons.storefront_outlined, title: 'Aucun client');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  itemCount: data.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final customer = data.items[index];
                    return AppCard(
                      onTap: () => context.push('/customers/${customer.id}/edit'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(_typeLabel(customer.type)),
                          if (customer.phone != null) Text(customer.phone!),
                          if (!customer.isActive) const Text('Inactif'),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(message: error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'SHOP';
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  PartnerStats? _stats;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      ref.read(customerServiceProvider).getById(widget.customerId!).then((customer) {
        if (!mounted) return;
        setState(() {
          _name.text = customer.name;
          _phone.text = customer.phone ?? '';
          _email.text = customer.email ?? '';
          _address.text = customer.address ?? '';
          _notes.text = customer.notes ?? '';
          _type = customer.type;
          _isActive = customer.isActive;
          _stats = customer.stats;
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
      if (widget.customerId == null) {
        await ref.read(customerServiceProvider).create(body);
      } else {
        await ref.read(customerServiceProvider).update(widget.customerId!, body);
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
      appBar: AppBar(title: Text(widget.customerId == null ? 'Nouveau client' : 'Modifier le client')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'FREESHOP', child: Text('Free shop')),
              DropdownMenuItem(value: 'SUPERMARKET', child: Text('Supermarché')),
              DropdownMenuItem(value: 'SHOP', child: Text('Magasin')),
              DropdownMenuItem(value: 'OTHER', child: Text('Autre')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'SHOP'),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone')),
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
                  title: 'Désactiver le client',
                  message: 'Ce client ne pourra plus être sélectionné pour une vente.',
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
                  Text('${_stats!.count} vente(s)'),
                  Text('Total ${formatDtLabel(_stats!.totalAmount)}'),
                  if (_stats!.lastDate != null)
                    Text('Dernière vente : ${formatDate(_stats!.lastDate!)}${_stats!.lastReference != null ? ' · ${_stats!.lastReference}' : ''}'),
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
