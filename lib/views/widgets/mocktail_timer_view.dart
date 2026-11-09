import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/mocktail_model.dart';
import '../../services/timer_alerts.dart';
import '../../viewmodels/brew_viewmodel.dart' show BrewTimerStatus;
import '../../viewmodels/mocktail_brew_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'app_button.dart';
import 'glass_card.dart';
import 'mocktail_scene_view.dart';
import 'motion.dart';
import 'timer_ring_painter.dart';

/// Isi tab Timer saat mode Mocktail aktif: gelas beranimasi di dalam cincin
/// timer, langkah berjalan otomatis menurut durasi, daftar bahan, dan daftar
/// langkah yang bisa dilompati. Sama seperti timer kopi, timer-nya berjalan
/// terus walau pindah tab; mengubah resep mengatur ulang timer.
class MocktailTimerView extends StatefulWidget {
  const MocktailTimerView({
    super.key,
    required this.blend,
    this.alerts,
    this.prefs,
  });

  /// Hasil hitungan mocktail saat ini; `null` bila resep belum valid.
  final MocktailBlend? blend;

  /// Hanya untuk pengujian; bawaannya suara dan layar menyala dari platform.
  final TimerAlerts? alerts;
  final TimerPrefs? prefs;

  @override
  State<MocktailTimerView> createState() => _MocktailTimerViewState();
}

class _MocktailTimerViewState extends State<MocktailTimerView> {
  MocktailBrewViewModel? _vm;
  TimerAlerts? _alerts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MocktailTimerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Membuat ulang timer hanya bila resepnya benar-benar berubah.
  void _sync() {
    final MocktailBlend? blend = widget.blend;
    final MocktailBrewViewModel? current = _vm;
    if (blend == null) {
      current?.dispose();
      _vm = null;
      return;
    }
    if (current != null && current.blend.spec == blend.spec) {
      return;
    }
    current?.dispose();
    _alerts ??= widget.alerts ?? PlatformTimerAlerts();
    _vm = MocktailBrewViewModel(
      blend: blend,
      alerts: _alerts!,
      prefs: widget.prefs ?? context.read<SettingsViewModel>(),
    );
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MocktailBrewViewModel? vm = _vm;
    if (vm == null) {
      return ListView(
        padding: AppLayout.screenPadding(context),
        children: const <Widget>[
          StaggerIn(
            child: GlassCard(
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.local_bar_rounded,
                    color: AppColors.sage,
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Pilih minimal satu sirup yang valid di tab Kalkulator '
                      '(mode Mocktail) agar timer dapat disusun.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ChangeNotifierProvider<MocktailBrewViewModel>.value(
      value: vm,
      child: Consumer<MocktailBrewViewModel>(
        builder: (BuildContext context, MocktailBrewViewModel vm, _) {
          return ListView(
            padding: AppLayout.screenPadding(context),
            children: <Widget>[
              StaggerIn(child: _SummaryBar(vm: vm)),
              const SizedBox(height: 16),
              StaggerIn(index: 1, child: _TimerPanel(vm: vm)),
              const SizedBox(height: 16),
              StaggerIn(index: 2, child: _PrepCard(vm: vm)),
              const SizedBox(height: 16),
              StaggerIn(index: 3, child: _StepList(vm: vm)),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.vm});

  final MocktailBrewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final MocktailBlend blend = vm.blend;
    final String syrups = blend.spec.syrups
        .map((MocktailSyrup s) => s.name)
        .join(' + ');
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  syrups,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metricValue,
                ),
                const SizedBox(height: 2),
                Text(
                  '${blend.summary.split(' · ').first} · '
                  '${blend.spec.glassMl} ml · '
                  '${blend.spec.method.label}',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          if (vm.glassCount > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Gelas ${vm.glassNumber}/${vm.glassCount}',
                style: const TextStyle(
                  color: AppColors.sage,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.vm});

  final MocktailBrewViewModel vm;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.sage,
      child: Column(
        children: <Widget>[
          ValueListenableBuilder<Duration>(
            valueListenable: vm.elapsed,
            builder: (BuildContext context, Duration elapsed, _) =>
                _Dial(vm: vm, elapsed: elapsed),
          ),
          const SizedBox(height: 16),
          _Instruction(vm: vm),
          const SizedBox(height: 20),
          _Controls(vm: vm),
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.vm, required this.elapsed});

  final MocktailBrewViewModel vm;
  final Duration elapsed;

  static const double _size = 290;

  @override
  Widget build(BuildContext context) {
    final MocktailBlend blend = vm.blend;
    final BrewTimerStatus status = vm.status;
    final int index = blend.stepIndexAt(elapsed);
    final MocktailStep step = blend.stepDetails[index];
    final int stepMs = step.durationSeconds * 1000;
    final int stepElapsedMs = (elapsed - blend.stepStartOf(index))
        .inMilliseconds
        .clamp(0, stepMs);
    final int remaining = ((stepMs - stepElapsedMs) / 1000).ceil();
    final bool finished = status == BrewTimerStatus.finished;
    final String caption = switch (status) {
      BrewTimerStatus.idle => 'SIAP',
      BrewTimerStatus.paused => 'DIJEDA · ${step.title.toUpperCase()}',
      BrewTimerStatus.finished => 'SELESAI',
      BrewTimerStatus.running => step.title.toUpperCase(),
    };

    return Semantics(
      label: 'Timer mocktail, ${step.title}',
      value: finished
          ? 'Selesai'
          : 'Sisa ${formatClock(remaining)} pada langkah ${step.title}',
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: const Size.square(_size),
              painter: TimerRingPainter(
                stepFraction: stepMs == 0 ? 0 : stepElapsedMs / stepMs,
                totalFraction:
                    elapsed.inMilliseconds / (blend.totalSeconds * 1000),
                paused: status == BrewTimerStatus.paused,
              ),
            ),
            SizedBox(
              width: _size - 100,
              height: _size - 100,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    MocktailSceneView(
                      blend: blend,
                      elapsed: vm.elapsed,
                      height: 100,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (status == BrewTimerStatus.running) ...<Widget>[
                          const PulsingDot(color: AppColors.sage, size: 7),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          caption,
                          style: AppTextStyles.sectionLabel.copyWith(
                            color: status == BrewTimerStatus.paused
                                ? AppColors.caramel
                                : AppColors.sage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      finished ? '00:00' : formatClock(remaining),
                      style: AppTextStyles.timerDigits.copyWith(fontSize: 44),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total ${formatClock(elapsed.inSeconds)} / '
                      '${formatClock(blend.totalSeconds)}',
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.vm});

  final MocktailBrewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final String text = vm.status == BrewTimerStatus.finished
        ? (vm.hasNextGlass
              ? 'Gelas ${vm.glassNumber} selesai. Lanjut ke gelas berikutnya '
                    'atau ulangi.'
              : 'Mocktail siap! Sajikan selagi dingin dan nikmati.')
        : vm.currentStep.text;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: TextAlign.center,
        style: AppTextStyles.body,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.vm});

  final MocktailBrewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final BrewTimerStatus status = vm.status;

    if (status == BrewTimerStatus.finished) {
      return Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: AppButton(
              label: vm.hasNextGlass ? 'Ulangi' : 'Reset',
              color: AppColors.secondaryButton,
              textColor: AppColors.textPrimary,
              onPressed: vm.reset,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: vm.hasNextGlass
                ? AppButton(
                    label: 'Gelas ${vm.glassNumber + 1} dari ${vm.glassCount}',
                    color: AppColors.caramel,
                    textColor: AppColors.onAccent,
                    onPressed: vm.nextGlass,
                  )
                : AppButton(
                    label: 'Ulangi',
                    color: AppColors.caramel,
                    textColor: AppColors.onAccent,
                    onPressed: vm.start,
                  ),
          ),
        ],
      );
    }

    final String primary = switch (status) {
      BrewTimerStatus.idle => 'Mulai',
      BrewTimerStatus.running => 'Jeda',
      BrewTimerStatus.paused => 'Lanjutkan',
      BrewTimerStatus.finished => 'Ulangi',
    };
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: AppButton(
            label: 'Reset',
            color: AppColors.secondaryButton,
            textColor: AppColors.textPrimary,
            enabled: status != BrewTimerStatus.idle,
            onPressed: vm.reset,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: AppButton(
            label: primary,
            color: status == BrewTimerStatus.running
                ? AppColors.sage
                : AppColors.caramel,
            textColor: AppColors.onAccent,
            onPressed: vm.toggle,
          ),
        ),
      ],
    );
  }
}

/// Daftar bahan yang bisa dicentang; tertutup secara default.
class _PrepCard extends StatefulWidget {
  const _PrepCard({required this.vm});

  final MocktailBrewViewModel vm;

  @override
  State<_PrepCard> createState() => _PrepCardState();
}

class _PrepCardState extends State<_PrepCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final MocktailBrewViewModel vm = widget.vm;
    final List<MocktailPrepItem> items = vm.prepItems;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _open,
            label: 'Siapkan bahan, ${vm.checkedCount} dari ${items.length}',
            child: PressableScale(
              pressedScale: 0.99,
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.checklist_rounded,
                      color: AppColors.sage,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Siapkan bahan', style: AppTextStyles.body),
                    ),
                    Text(
                      '${vm.checkedCount}/${items.length}',
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: vm.allChecked ? AppColors.sage : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < items.length; i++)
                          _PrepRow(
                            item: items[i],
                            checked: vm.isChecked(i),
                            onTap: () => vm.toggleChecked(i),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PrepRow extends StatelessWidget {
  const _PrepRow({
    required this.item,
    required this.checked,
    required this.onTap,
  });

  final MocktailPrepItem item;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor = checked
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    return Semantics(
      button: true,
      checked: checked,
      label: item.amount.isEmpty ? item.name : '${item.name} ${item.amount}',
      child: PressableScale(
        pressedScale: 0.98,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked
                      ? AppColors.sage
                      : AppColors.sage.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: checked ? 1 : 0.5),
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: AppColors.onAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              if (item.color != null) ...<Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(item.color!),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  item.name,
                  style: AppTextStyles.body.copyWith(
                    color: textColor,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
              if (item.amount.isNotEmpty)
                Text(
                  item.amount,
                  style: AppTextStyles.metricValue.copyWith(color: textColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { pending, active, done }

/// Daftar langkah dengan penanda selesai, aktif, dan menunggu. Ketuk satu
/// langkah untuk melompat ke sana.
class _StepList extends StatelessWidget {
  const _StepList({required this.vm});

  final MocktailBrewViewModel vm;

  _StepState _stateOf(int index) {
    if (vm.status == BrewTimerStatus.finished) {
      return _StepState.done;
    }
    if (vm.status == BrewTimerStatus.idle) {
      return _StepState.pending;
    }
    if (index < vm.currentStepIndex) {
      return _StepState.done;
    }
    return index == vm.currentStepIndex
        ? _StepState.active
        : _StepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final List<MocktailStep> steps = vm.blend.stepDetails;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            _StepRow(
              step: steps[i],
              state: _stateOf(i),
              isLast: i == steps.length - 1,
              onTap: () => vm.jumpTo(i),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.state,
    required this.isLast,
    required this.onTap,
  });

  final MocktailStep step;
  final _StepState state;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = state == _StepState.active;
    final bool done = state == _StepState.done;
    final Color accent = done
        ? AppColors.sage
        : active
        ? AppColors.caramel
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: 'Langkah ${step.title}, ${formatClock(step.durationSeconds)}',
      hint: 'Ketuk untuk lompat ke langkah ini',
      child: PressableScale(
        pressedScale: 0.99,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0x1FF3E6D6))),
          ),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: active || done ? 0.2 : 0.08),
                  border: Border.all(color: accent),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.circle,
                  size: done ? 18 : 8,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  step.title,
                  style: AppTextStyles.metricValue.copyWith(
                    color: active || done
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                formatClock(step.durationSeconds),
                style: AppTextStyles.metricValue.copyWith(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
