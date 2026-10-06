import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/features/auth/presentation/login_screen.dart';
import 'package:stock_management/features/auth/presentation/register_screen.dart';
import 'package:stock_management/features/auth/presentation/splash_screen.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';
import 'package:stock_management/features/categories/presentation/categories_screen.dart';
import 'package:stock_management/features/customers/presentation/customers_screen.dart';
import 'package:stock_management/features/home/presentation/home_screen.dart';
import 'package:stock_management/features/more/presentation/more_screen.dart';
import 'package:stock_management/features/products/presentation/products_screen.dart';
import 'package:stock_management/features/purchases/presentation/purchase_detail_screen.dart';
import 'package:stock_management/features/purchases/presentation/purchase_form_screen.dart';
import 'package:stock_management/features/purchases/presentation/purchases_screen.dart';
import 'package:stock_management/features/sales/presentation/sale_detail_screen.dart';
import 'package:stock_management/features/sales/presentation/sale_form_screen.dart';
import 'package:stock_management/features/sales/presentation/sales_screen.dart';
import 'package:stock_management/features/settings/presentation/settings_screen.dart';
import 'package:stock_management/features/shell/presentation/main_shell.dart';
import 'package:stock_management/features/stock/presentation/adjust_stock_screen.dart';
import 'package:stock_management/features/stock/presentation/movements_screen.dart';
import 'package:stock_management/features/stock/presentation/stock_screen.dart';
import 'package:stock_management/features/suppliers/presentation/suppliers_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final location = state.matchedLocation;
      final isLoginRoute = location == '/login' || location == '/register';
      final isAuthRoute = location == '/splash' || isLoginRoute;

      if (status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated) {
        return isLoginRoute ? null : '/login';
      }

      if (isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/stock', builder: (context, state) => const StockScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/purchases', builder: (context, state) => const PurchasesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/sales', builder: (context, state) => const SalesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/more', builder: (context, state) => const MoreScreen())],
          ),
        ],
      ),
      GoRoute(path: '/products', builder: (context, state) => const ProductsScreen()),
      GoRoute(path: '/products/new', builder: (context, state) => const ProductFormScreen()),
      GoRoute(
        path: '/products/:id/edit',
        builder: (context, state) => ProductFormScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: '/suppliers', builder: (context, state) => const SuppliersScreen()),
      GoRoute(path: '/suppliers/new', builder: (context, state) => const SupplierFormScreen()),
      GoRoute(
        path: '/suppliers/:id/edit',
        builder: (context, state) => SupplierFormScreen(supplierId: state.pathParameters['id']),
      ),
      GoRoute(path: '/customers', builder: (context, state) => const CustomersScreen()),
      GoRoute(path: '/customers/new', builder: (context, state) => const CustomerFormScreen()),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) => CustomerFormScreen(customerId: state.pathParameters['id']),
      ),
      GoRoute(path: '/purchases/new', builder: (context, state) => const PurchaseFormScreen()),
      GoRoute(
        path: '/purchases/:id',
        builder: (context, state) => PurchaseDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/sales/new', builder: (context, state) => const SaleFormScreen()),
      GoRoute(
        path: '/sales/:id',
        builder: (context, state) => SaleDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stock/movements',
        builder: (context, state) => MovementsScreen(
          productId: state.uri.queryParameters['productId'],
        ),
      ),
      GoRoute(
        path: '/stock/adjust/:productId',
        builder: (context, state) => AdjustStockScreen(productId: state.pathParameters['productId']!),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});
