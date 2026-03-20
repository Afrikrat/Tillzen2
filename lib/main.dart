import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'database/database.dart';
import 'screens/sales_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_screen.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'screens/reports_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init err: $e');
  }
  
  final db = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider(create: (_) => UserProvider(db)),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const TillzenApp(),
    ),
  );
}

// ShellRoute for Bottom Navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final userProvider = context.read<UserProvider>();
    final isLoggedIn = userProvider.user != null;
    final isGoingToAuth = state.uri.toString() == '/login';

    // Protect unauthorized root access
    if (!isLoggedIn && !isGoingToAuth) return '/login';
    // Redirect away from login if already authenticated
    if (isLoggedIn && isGoingToAuth) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SalesScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
      ],
    ),
  ],
);

class TillzenApp extends StatelessWidget {
  const TillzenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tillzen POS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    int getSelectedIndex() {
      final String location = GoRouterState.of(context).uri.toString();
      if (location.startsWith('/inventory')) return 1;
      if (location.startsWith('/settings')) return 2;
      if (location.startsWith('/reports')) return 3;
      return 0;
    }

    final isCashier = context.watch<UserProvider>().activeRole == UserRole.cashier;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: getSelectedIndex(),
        onTap: (index) {
          switch (index) {
            case 2:
              context.go('/settings');
              break;
            case 3:
              context.go('/reports');
              break;
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Settings',
          ),
          if (!isCashier)
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
        ],
      ),
    );
  }
}
