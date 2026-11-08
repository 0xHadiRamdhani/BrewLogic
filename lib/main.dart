import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'services/journal_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  try {
    final JournalRepository repository = await JournalRepository.open();
    runApp(BrewLogicApp(repository: repository));
  } catch (_) {
    runApp(const _StartupErrorApp());
  }
}

/// Fallback jika penyimpanan lokal gagal dibuka, agar tidak crash tanpa pesan.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.material,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Penyimpanan lokal tidak dapat dibuka. '
              'Tutup aplikasi lalu coba lagi.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ),
        ),
      ),
    );
  }
}
