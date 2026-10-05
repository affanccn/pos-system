import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/table_model.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/kitchen/kitchen_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/order/table_detail_screen.dart';
import '../../features/order/payment_screen.dart';
import '../../features/manager/staff_screen.dart';
import '../../features/printers/printer_screen.dart';
import '../../features/reports/daily_report_screen.dart';
import '../../features/reports/advanced_reports_screen.dart';
import '../../features/reports/profitability_screen.dart';
import '../../features/waiter/tables_screen.dart';
import '../../features/manager/catalog_screen.dart';
import '../../features/manager/expense_screen.dart';
import '../../features/manager/cash_register_screen.dart';
import '../../features/manager/audit_log_screen.dart';
import '../../features/manager/reservations_screen.dart';
import '../../features/manager/branches_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/manager/manager_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authNotifier.state.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      if (isAuthenticated && isLoggingIn) {
        if (authNotifier.state.isOwner || authNotifier.state.isManager) {
          return '/manager/dashboard';
        }
        return '/waiter/tables';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/order/payment',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return PaymentScreen(orderId: extras['orderId'], tableId: extras['tableId']);
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/waiter/tables',
        builder: (context, state) => const TablesScreen(),
      ),
      GoRoute(
        path: '/waiter/table-detail',
        builder: (context, state) {
          final table = state.extra as RestaurantTable;
          return TableDetailScreen(table: table);
        },
      ),
      GoRoute(
        path: '/waiter/order',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            return OrderScreen(
              table: map['table'] as RestaurantTable,
              existingOrderId: map['existingOrderId'] as String?,
            );
          }
          final table = state.extra as RestaurantTable;
          return OrderScreen(table: table);
        },
      ),
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => const KitchenScreen(),
      ),
      GoRoute(
        path: '/reports/daily',
        builder: (context, state) => const DailyReportScreen(),
      ),
      GoRoute(
        path: '/reports/profitability',
        builder: (context, state) => const ProfitabilityScreen(),
      ),
      GoRoute(
        path: '/reports/advanced',
        builder: (context, state) => const AdvancedReportsScreen(),
      ),
      GoRoute(
        path: '/manager/staff',
        builder: (context, state) => const StaffScreen(),
      ),
      GoRoute(
        path: '/manager/catalog',
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/printers',
        builder: (context, state) => const PrinterScreen(),
      ),
      GoRoute(
        path: '/manager/expenses',
        builder: (context, state) => const ExpenseScreen(),
      ),
      GoRoute(
        path: '/manager/cash',
        builder: (context, state) => const CashRegisterScreen(),
      ),
      GoRoute(
        path: '/manager/audit',
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/manager/reservations',
        builder: (context, state) => const ReservationsScreen(),
      ),
      GoRoute(
        path: '/manager/branches',
        builder: (context, state) => const BranchesScreen(),
      ),
      GoRoute(
        path: '/manager/dashboard',
        builder: (context, state) => const ManagerDashboardScreen(),
      ),
    ],
  );
});// refresh
