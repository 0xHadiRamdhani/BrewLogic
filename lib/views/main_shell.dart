import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

import 'package:provider/provider.dart';

import '../viewmodels/shell_navigation.dart';
import 'home_screen.dart';
import 'journal_screen.dart';
import 'settings_screen.dart';
import 'timer_screen.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/ambient_background.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/live_brew_chip.dart';
import 'widgets/motion.dart';

/// Kerangka aplikasi: `AdaptiveScaffold` dengan bottom navigation (tab bar
/// native Liquid Glass di iOS 26+, NavigationBar di Android) dan app bar kaca
/// buatan sendiri yang melayang di atas konten.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.introDone});

  /// Bernilai `true` setelah splash selesai; animasi masuk tab pertama
  /// menunggu sinyal ini. `null` berarti langsung diputar.
  final ValueListenable<bool>? introDone;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _timerTab = 1;
  static const int _journalTab = 2;
  static const List<String> _titles = <String>[
    'Kalkulator',
    'Timer',
    'Jurnal',
    'Pengaturan',
  ];
  static const List<String> _subtitles = <String>[
    'Hitung takaran seduh yang presisi',
    'Seduh step-by-step tanpa menebak',
    'Catatan dan rating seduhanmu',
    'Atur preferensi aplikasi',
  ];

  int _index = 0;
  late bool _entered;
  ShellNavigation? _navigation;
  int _handledRequest = 0;

  @override
  void initState() {
    super.initState();
    _entered = widget.introDone?.value ?? true;
    widget.introDone?.addListener(_onIntroChanged);
  }

  void _onIntroChanged() {
    if (widget.introDone!.value && !_entered && mounted) {
      setState(() => _entered = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ShellNavigation nav = context.read<ShellNavigation>();
    if (!identical(nav, _navigation)) {
      _navigation?.removeListener(_onNavigationRequest);
      _navigation = nav..addListener(_onNavigationRequest);
      _handledRequest = nav.requestId;
    }
  }

  void _onNavigationRequest() {
    final ShellNavigation? nav = _navigation;
    if (nav == null || nav.requestId == _handledRequest || !mounted) {
      return;
    }
    _handledRequest = nav.requestId;
    _select(nav.requestedTab);
  }

  @override
  void dispose() {
    _navigation?.removeListener(_onNavigationRequest);
    widget.introDone?.removeListener(_onIntroChanged);
    super.dispose();
  }

  /// Sapaan sesuai jam, dipakai sebagai subjudul Kalkulator.
  static String _greeting() {
    final int hour = DateTime.now().hour;
    final String part = hour < 11
        ? 'pagi'
        : hour < 15
        ? 'siang'
        : hour < 18
        ? 'sore'
        : 'malam';
    return 'Selamat $part, yuk seduh';
  }

  void _select(int index) {
    if (index == _index) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final bool ios = PlatformInfo.isIOS;
    final List<Widget> screens = <Widget>[
      HomeScreen(
        onOpenTimer: () => _select(_timerTab),
        onOpenJournal: () => _select(_journalTab),
      ),
      TimerScreen(onOpenJournal: () => _select(_journalTab)),
      const JournalScreen(),
      const SettingsScreen(),
    ];

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _index,
        onTap: _select,
        selectedItemColor: AppColors.caramel,
        items: <AdaptiveNavigationDestination>[
          AdaptiveNavigationDestination(
            icon: ios ? 'scalemass.fill' : Icons.scale_rounded,
            label: _titles[0],
          ),
          AdaptiveNavigationDestination(
            icon: ios ? 'timer' : Icons.timer_rounded,
            label: _titles[1],
          ),
          AdaptiveNavigationDestination(
            icon: ios ? 'book.fill' : Icons.menu_book_rounded,
            label: _titles[2],
          ),
          AdaptiveNavigationDestination(
            icon: ios ? 'gearshape.fill' : Icons.settings_rounded,
            label: _titles[3],
          ),
        ],
      ),
      body: AppTextScope(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AmbientBackground(),
            for (int i = 0; i < screens.length; i++)
              Offstage(
                offstage: i != _index,
                child: TickerMode(
                  enabled: i == _index,
                  child: TabActivity(
                    active: i == _index && _entered,
                    child: HeaderClip(child: screens[i]),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: _titles[_index],
                subtitle: _index == 0 ? _greeting() : _subtitles[_index],
                tabIndex: _index,
                trailing: LiveBrewChip(
                  visible: _index != _timerTab,
                  onTap: () => _select(_timerTab),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
