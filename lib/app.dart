import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/theme/app_theme.dart';
import 'services/data_transfer_service.dart';
import 'services/journal_repository.dart';
import 'services/photo_storage.dart';
import 'services/timer_alerts.dart';
import 'viewmodels/bean_viewmodel.dart';
import 'viewmodels/brew_viewmodel.dart';
import 'viewmodels/journal_viewmodel.dart';
import 'viewmodels/mocktail_viewmodel.dart';
import 'viewmodels/recipe_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/shell_navigation.dart';
import 'views/main_shell.dart';
import 'views/splash_screen.dart';

class BrewLogicApp extends StatelessWidget {
  const BrewLogicApp({
    super.key,
    required this.repository,
    this.showSplash = true,
  });

  final JournalRepository repository;
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<JournalRepository>.value(value: repository),
        Provider<PhotoStorage>(create: (_) => PhotoStorage()),
        Provider<DataTransferService>(
          create: (_) => DataTransferService(repository: repository),
        ),
        ChangeNotifierProvider<BeanViewModel>(
          create: (_) => BeanViewModel(repository: repository),
        ),
        ChangeNotifierProvider<SettingsViewModel>(
          create: (_) => SettingsViewModel(repository: repository),
        ),
        ChangeNotifierProvider<BrewViewModel>(
          create: (BuildContext context) => BrewViewModel(
            repository: repository,
            alerts: PlatformTimerAlerts(),
            prefs: context.read<SettingsViewModel>(),
          ),
        ),
        ChangeNotifierProvider<RecipeViewModel>(
          create: (_) => RecipeViewModel(repository: repository),
        ),
        ChangeNotifierProvider<MocktailViewModel>(
          create: (_) => MocktailViewModel(repository: repository),
        ),
        ChangeNotifierProvider<ShellNavigation>(
          create: (_) => ShellNavigation(),
        ),
        ChangeNotifierProvider<JournalViewModel>(
          create: (BuildContext context) => JournalViewModel(
            repository: repository,
            photos: context.read<PhotoStorage>(),
          ),
        ),
      ],
      child: AdaptiveApp(
        title: 'BrewLogic',
        themeMode: ThemeMode.dark,
        // Diperlukan pemilih tanggal Cupertino (butuh MaterialLocalizations)
        // dan memberi teks sistem berbahasa Indonesia.
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id'), Locale('en')],
        materialLightTheme: AppTheme.material,
        materialDarkTheme: AppTheme.material,
        cupertinoLightTheme: AppTheme.cupertino,
        cupertinoDarkTheme: AppTheme.cupertino,
        builder: (BuildContext context, Widget? child) {
          // Memperkecil teks tanpa membuang pengaturan ukuran teks pengguna,
          // dan memastikan font pixel dipakai juga di bawah CupertinoApp
          // (iOS), tempat tema Material tidak otomatis berlaku.
          final MediaQueryData media = MediaQuery.of(context);
          return ValueListenableBuilder<double>(
            valueListenable: TextScalePrefs.factor,
            builder: (BuildContext context, double factor, Widget? _) {
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(
                    media.textScaler.scale(1) * factor,
                  ),
                ),
                child: Theme(
                  data: AppTheme.material,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontFamily: appFontFamily),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          );
        },
        home: _AppRoot(showSplash: showSplash),
      ),
    );
  }
}

/// Menumpuk splash di atas shell. Shell sudah dibangun di bawahnya sehingga
/// saat splash memudar, aplikasi langsung siap dan animasi masuk dimulai.
class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.showSplash});

  final bool showSplash;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  static const Duration _fade = Duration(milliseconds: 700);

  late final ValueNotifier<bool> _introDone = ValueNotifier<bool>(
    !widget.showSplash,
  );
  late bool _splashVisible = widget.showSplash;
  bool _fadingOut = false;

  void _onSplashFinished() {
    if (_fadingOut) {
      return;
    }
    setState(() => _fadingOut = true);
    _introDone.value = true;
  }

  @override
  void dispose() {
    _introDone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        MainShell(introDone: _introDone),
        if (_splashVisible)
          IgnorePointer(
            ignoring: _fadingOut,
            child: AnimatedOpacity(
              opacity: _fadingOut ? 0 : 1,
              duration: _fade,
              curve: Curves.easeInOut,
              onEnd: () {
                if (_fadingOut && mounted) {
                  setState(() => _splashVisible = false);
                }
              },
              child: AnimatedScale(
                scale: _fadingOut ? 1.08 : 1,
                duration: _fade,
                curve: Curves.easeInOut,
                child: ColoredBox(
                  color: AppColors.background,
                  child: SplashScreen(onFinished: _onSplashFinished),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
