import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/prefs.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/gate_screens.dart';
import 'screens/update_screen.dart';
import 'services/gift_service.dart';
import 'services/sticker_service.dart';
import 'services/update_service.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  await NotificationService.init();
  FirebaseMessaging.onMessage.listen((m) => NotificationService.handleMessage(m, background: false));
  await initializeDateFormatting('ar');
  final theme = ThemeController();
  await theme.load();
  final prefs = AppPrefs();
  await prefs.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: prefs),
      ChangeNotifierProvider(create: (_) => AuthService()),
      Provider(create: (_) => ChatService()),
      ChangeNotifierProvider(create: (_) => UpdateController(), lazy: false),
      ChangeNotifierProvider(create: (_) => StickerService()),
      ChangeNotifierProvider(create: (_) => GiftService()),
    ],
    child: const BabylonApp(),
  ));
}

class BabylonApp extends StatelessWidget {
  const BabylonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Babylon Chat',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: theme.mode,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    // تحديث إجباري: يمنع فتح التطبيق قبل أي شي (حتى قبل تسجيل الدخول)
    if (context.watch<UpdateController>().forced) return const UpdateScreen(forced: true);
    switch (auth.gate) {
      case Gate.loading:
        return Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Babylon',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ]),
          ),
        );
      case Gate.signedOut:
        return const AuthScreen();
      case Gate.verifyEmail:
        return const VerifyEmailScreen();
      case Gate.otp:
        return const OtpScreen();
      case Gate.ready:
        break;
    }
    return HomeScreen(key: ValueKey(auth.user!.uid));
  }
}
