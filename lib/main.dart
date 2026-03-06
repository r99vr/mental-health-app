import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MentalHealthApp());
}

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Mental Health App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            
            // RTL / Arabic Support
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''), 
              Locale('ar', ''),
            ],
            // Switch to ar for Arabic layout testing: locale: const Locale('ar', ''),

            home: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                if (auth.isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (auth.isAuthenticated) {
                  return const HomeScreen();
                }

                return const LoginScreen();
              },
            ),
          );
        }
      ),
    );
  }
}
