import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:login_fish_app/backend-login/wrapper.dart';
//import 'firebase_options.dart';
import 'package:get/get.dart';
import 'i18n/translations.dart';
import 'dart:ui' as ui;
import 'homepage/Initial/initialType.dart';
import 'controllers/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consent/consent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // If you were using the local Functions emulator, set `useFunctionsEmulator`
  // to true and update `functionsEmulatorHost` to your PC's LAN IP.
  // Currently we disable emulator usage so the app calls the deployed cloud function.
  const useFunctionsEmulator = false;
  const functionsEmulatorHost = '192.168.1.42';
  const functionsEmulatorPort = 5001;
  if (useFunctionsEmulator) {
    FirebaseFunctions.instance.useFunctionsEmulator(
      functionsEmulatorHost,
      functionsEmulatorPort,
    );
  }
  // Determine initial locale: saved preference -> device locale -> fallback en
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('user_language');
  String code;
  if (saved != null && ['hu', 'ro', 'en'].contains(saved)) {
    code = saved;
  } else {
    final dev = ui.PlatformDispatcher.instance.locale;
    code = ['hu', 'ro', 'en'].contains(dev.languageCode)
        ? dev.languageCode
        : 'en';
  }
  runApp(MyApp(initialLocaleCode: code));
}

class MyApp extends StatelessWidget {
  final String initialLocaleCode;
  const MyApp({super.key, required this.initialLocaleCode});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Put the theme controller into GetX
    Get.put(ThemeController());
    return GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(initialLocaleCode),
      fallbackLocale: const Locale('en'),
      title: 'Flutter Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.theme,
      themeMode: ThemeMode.dark,
      home: FutureBuilder<bool?>(
        future: _checkConsent(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final consent = snap.data ?? null;
          if (consent == true) {
            return const Wrapper();
          }
          // show consent screen; when decision is done, push Wrapper
          return ConsentScreen(
            onDecision: (accepted) {
              // After user decides, rebuild by replacing the current route with Wrapper
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const Wrapper()),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool?> _checkConsent() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('consentGiven');
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
