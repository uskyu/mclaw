import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_update_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'services/gateway_service.dart';
import 'services/background_runtime_service.dart';
import 'services/notification_service.dart';
import 'screens/chat_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await BackgroundRuntimeService.instance.configure();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppUpdateProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => GatewayService()),
        ChangeNotifierProxyProvider<GatewayService, ChatProvider>(
          create: (context) => ChatProvider(
            gatewayService: context.read<GatewayService>(),
          ),
          update: (context, gatewayService, previous) =>
              previous ?? ChatProvider(gatewayService: gatewayService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'MClaw',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeProvider.themeMode,
            locale: themeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) {
                return const Locale('en');
              }
              if (locale.languageCode == 'zh') {
                return const Locale('zh');
              }
              return const Locale('en');
            },
            home: const ChatScreen(),
          );
        },
      ),
    );
  }
}
