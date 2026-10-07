import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/theme/app_theme.dart';
import 'package:stock_management/core/widgets/app_logo.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final error = auth.status == AuthStatus.unknown ? auth.errorMessage : null;

    return Scaffold(
      backgroundColor: AppTheme.seed,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 8 || constraints.maxHeight < 8) {
              return const SizedBox.expand();
            }

            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth.clamp(160, 420),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 132, radius: 28),
                        const SizedBox(height: 20),
                        const Text(
                          'anis_stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gestion de stock professionnelle',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 32),
                        if (error == null)
                          const CircularProgressIndicator(color: Colors.white)
                        else ...[
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () => ref.read(authProvider.notifier).restoreSession(),
                            child: const Text('Réessayer'),
                          ),
                          if (auth.user != null)
                            TextButton(
                              onPressed: () => ref.read(authProvider.notifier).continueOffline(),
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              child: const Text('Continuer sans vérifier'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
