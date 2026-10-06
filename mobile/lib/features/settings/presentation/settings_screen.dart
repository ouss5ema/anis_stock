import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/config/env.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profil', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(user?.name ?? 'Utilisateur'),
                Text(user?.email ?? ''),
                Text(roleLabel(user?.role)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Application', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(AppEnv.appName),
                Text('Version ${AppEnv.appVersion}'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
