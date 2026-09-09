import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/pos_store.dart';
import 'screens/app_shell.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<PosStore> _future = PosStore.open();
  @override
  Widget build(BuildContext context) => FutureBuilder<PosStore>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return BazaarApp(store: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storage_outlined,
                          size: 42,
                          color: forest,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Unable to open local storage',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Allow browser storage, or check that this device has free space. Your existing data has not been reset.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _future = PosStore.open()),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class BazaarApp extends StatelessWidget {
  const BazaarApp({super.key, required this.store});
  final PosStore store;
  @override
  Widget build(BuildContext context) => PosScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: store.settings.name,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Flutter has no Badini Material delegate. Application strings are Badini;
        // system calendar/picker controls use Arabic, with explicit RTL direction.
        locale: Locale(store.language == 'ku' ? 'ar' : store.language),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => Directionality(
          textDirection: store.language == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: child!,
        ),
        home: store.currentUser == null
            ? const WelcomeScreen()
            : AppShell(key: ValueKey(store.currentUser!.id)),
      ),
    ),
  );
}
