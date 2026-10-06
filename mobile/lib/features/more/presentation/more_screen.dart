import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _tile(context, Icons.category_outlined, 'Produits', '/products'),
          _tile(context, Icons.local_shipping_outlined, 'Fournisseurs', '/suppliers'),
          _tile(context, Icons.storefront_outlined, 'Clients', '/customers'),
          _tile(context, Icons.account_tree_outlined, 'Catégories', '/categories'),
          _tile(context, Icons.history, 'Mouvements', '/stock/movements'),
          _tile(context, Icons.settings_outlined, 'Paramètres', '/settings'),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push(path),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
