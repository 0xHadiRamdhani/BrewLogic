import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../models/brew_model.dart';
import '../viewmodels/bean_viewmodel.dart';
import 'bean_editor_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/ambient_background.dart';
import 'widgets/bean_strip.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/motion.dart';

/// Perpustakaan biji kopi: daftar biji beserta kesegarannya.
class BeansScreen extends StatelessWidget {
  const BeansScreen({super.key});

  static Future<void> openEditor(BuildContext context, {BrewBean? bean}) =>
      pushPlatformPage<bool>(context, BeanEditorScreen(bean: bean));

  @override
  Widget build(BuildContext context) {
    final BeanViewModel vm = context.watch<BeanViewModel>();

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      body: AppTextScope(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AmbientBackground(),
            HeaderClip(
              child: ListView(
                padding: AppLayout.screenPadding(context, hasBottomBar: false),
                children: <Widget>[
                  if (vm.isEmpty)
                    const StaggerIn(
                      child: EmptyState(
                        icon: Icons.grain_rounded,
                        title: 'Belum ada biji',
                        message:
                            'Tambahkan biji beserta tanggal roasting untuk '
                            'memantau kesegarannya.',
                      ),
                    )
                  else
                    for (final (int i, BrewBean bean) in vm.beans.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                        child: StaggerIn(
                          key: ValueKey<String>(bean.id),
                          index: i,
                          child: BeanCard(
                            bean: bean,
                            freshness: vm.freshnessOf(bean),
                            onTap: () => openEditor(context, bean: bean),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: 'Biji Kopi',
                subtitle: 'Pantau kesegaran bijimu',
                leading: const GlassBackButton(),
                trailing: GlassIconButton(
                  icon: Icons.add_rounded,
                  label: 'Tambah biji',
                  onTap: () => openEditor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
