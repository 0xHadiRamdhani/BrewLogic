import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/brew_model.dart';
import '../viewmodels/brew_viewmodel.dart';
import '../viewmodels/mocktail_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'save_brew_screen.dart';
import 'widgets/app_button.dart';
import 'widgets/brew_timer_panel.dart';
import 'widgets/glass_card.dart';
import 'widgets/mocktail_timer_view.dart';
import 'widgets/motion.dart';

/// Tab Timer: seduh step-by-step (Bloom → First Pour → Second Pour). Di mode
/// Mocktail isinya timer membuat mocktail.
class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key, required this.onOpenJournal});

  final VoidCallback onOpenJournal;

  Future<void> _saveToJournal(BuildContext context) async {
    final bool saved = await SaveBrewScreen.open(context);
    if (saved && context.mounted) {
      onOpenJournal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MocktailViewModel mocktail = context.watch<MocktailViewModel>();
    if (mocktail.isActive) {
      return MocktailTimerView(blend: mocktail.blend);
    }

    final BrewViewModel vm = context.watch<BrewViewModel>();
    final BrewCalculation? calc = vm.calculation;
    final bool finished = vm.timerStatus == BrewTimerStatus.finished;

    return ListView(
      padding: AppLayout.screenPadding(context),
      children: <Widget>[
        if (calc == null)
          const StaggerIn(child: _NoCalculationNotice())
        else ...<Widget>[
          StaggerIn(child: _SummaryBar(calculation: calc)),
          const SizedBox(height: 16),
          StaggerIn(index: 1, child: BrewTimerPanel(viewModel: vm)),
          const SizedBox(height: 16),
          StaggerIn(
            index: 2,
            child: BrewStepList(
              calculation: calc,
              activeIndex: vm.currentStepIndex,
              status: vm.timerStatus,
            ),
          ),
          const SizedBox(height: 16),
          StaggerIn(
            index: 3,
            child: AppButton(
              label: 'Simpan ke Jurnal',
              color: finished ? AppColors.caramel : AppColors.secondaryButton,
              textColor: finished ? AppColors.onAccent : AppColors.textPrimary,
              onPressed: () => _saveToJournal(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.calculation});

  final BrewCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final BrewCalculation c = calculation;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${c.method.label} · ${c.roast.label}',
                  style: AppTextStyles.metricValue,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatGrams(c.coffeeGrams)} g kopi · '
                  '${formatGrams(c.totalWaterGrams)} ml air',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          Text(
            formatTempRange(
              c.minTempC,
              c.maxTempC,
              fahrenheit: context.watch<SettingsViewModel>().useFahrenheit,
            ),
            style: AppTextStyles.metricValue.copyWith(color: AppColors.caramel),
          ),
        ],
      ),
    );
  }
}

class _NoCalculationNotice extends StatelessWidget {
  const _NoCalculationNotice();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_outlined, color: AppColors.sage, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Isi gramasi kopi yang valid di tab Kalkulator terlebih dahulu '
              'agar timer dapat disusun.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}
