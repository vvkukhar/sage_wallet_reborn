import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/di/injector.dart';
import 'data/repositories/invitation_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/wallet_repository.dart';
import 'providers/app_mode_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/pro_status_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/auth/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Supabase.initialize(
    url: 'https://xdofjorgomwdyawmwbcj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhkb2Zqb3Jnb213ZHlhd213YmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkzMzE0MTcsImV4cCI6MjA2NDkwNzQxN30.2i9ru8fXLZEYD_jNHoHd0ZJmN4k9gKcPOChdiuL_AMY',
  );

  await configureDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<CurrencyProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ProStatusProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<AuthService>()),
        ChangeNotifierProvider(
          create: (context) => AppModeProvider(context.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<AppModeProvider, WalletProvider>(
          create: (context) => WalletProvider(
            getIt<WalletRepository>(),
            getIt<UserRepository>(),
            getIt<InvitationRepository>(),
            context.read<AppModeProvider>(),
            context.read<AuthService>(),
          ),
          update: (_, appMode, walletProvider) {
            walletProvider!.onAppModeChanged();
            return walletProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final profile = themeProvider.currentProfile;
          return MaterialApp(
            title: 'Гаманець Мудреця',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              fontFamily: profile.fontFamily,
              colorScheme: ColorScheme.fromSeed(
                seedColor: profile.seedColor,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              fontFamily: profile.fontFamily,
              colorScheme: ColorScheme.fromSeed(
                seedColor: profile.seedColor,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            navigatorKey: NavigationService.navigatorKey,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('uk', 'UA'),
            ],
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}