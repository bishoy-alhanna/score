import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(ScoreUserApp());
}

class ScoreUserApp extends StatelessWidget {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();

  ScoreUserApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider(_secureStorage, _apiService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return MaterialApp.router(
            title: 'Score User App',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
            ),
            routerConfig: _createRouter(auth),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/login', // Go directly to login
      redirect: (context, state) {
        final isAuthenticated = auth.isAuthenticated;
        final isOnAuth =
            state.fullPath == '/login' || state.fullPath == '/register';

        // If authenticated and on auth pages, go to home
        if (isAuthenticated && isOnAuth) {
          return '/home';
        }

        // If not authenticated and not on auth pages, go to login
        if (!isAuthenticated && !isOnAuth) {
          return '/login';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      ],
    );
  }
}
