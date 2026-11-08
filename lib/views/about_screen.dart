import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/layout.dart';
import '../core/theme/app_theme.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/ambient_background.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/glass_card.dart';
import 'widgets/motion.dart';
import 'widgets/section_label.dart';
import 'widgets/settings_row.dart';

/// Halaman "Tentang": identitas dan versi aplikasi, profil pengembang, fitur,
/// dan tech stack dalam satu tempat.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const StaggerIn(child: _AppCard()),
                  const SizedBox(height: 20),
                  const StaggerIn(index: 1, child: _FeaturesCard()),
                  const SizedBox(height: 20),
                  const StaggerIn(index: 2, child: _DeveloperCard()),
                  const SizedBox(height: 20),
                  StaggerIn(
                    index: 3,
                    child: _Section(
                      label: 'Tautan',
                      children: <Widget>[
                        SettingsRow(
                          icon: Icons.code_rounded,
                          title: 'GitHub',
                          subtitle: AppInfo.githubHandle,
                          trailing: const _OpenIcon(),
                          onTap: () => _openLink(context, AppInfo.githubUrl),
                        ),
                        SettingsRow(
                          icon: Icons.camera_alt_outlined,
                          title: 'Instagram',
                          subtitle: AppInfo.instagramHandle,
                          trailing: const _OpenIcon(),
                          onTap: () => _openLink(context, AppInfo.instagramUrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const StaggerIn(index: 4, child: _TechStack()),
                ],
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: 'Tentang',
                subtitle: '${AppInfo.name} v${AppInfo.version}',
                leading: GlassBackButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Membuka [url] di aplikasi atau browser; bila gagal, tautan disalin.
Future<void> _openLink(BuildContext context, String url) async {
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    opened = false;
  }
  if (opened || !context.mounted) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) {
    return;
  }
  AdaptiveSnackBar.show(
    context,
    message: 'Tidak bisa membuka tautan. Tautan disalin.',
    type: AdaptiveSnackBarType.info,
    duration: const Duration(seconds: 3),
  );
}

class _OpenIcon extends StatelessWidget {
  const _OpenIcon();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.north_east_rounded,
    size: 18,
    color: AppColors.textSecondary,
  );
}

/// Logo aplikasi dari `assets/images/icons.jpg` dalam petak putih
/// berujung bulat, supaya latar putih gambar terlihat disengaja.
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo ${AppInfo.name}',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.caramel.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset(
            AppInfo.logoAsset,
            fit: BoxFit.cover,
            cacheWidth: (_size * 3).round(),
            errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
                const ColoredBox(
                  color: AppColors.caramel,
                  child: Icon(
                    Icons.coffee_rounded,
                    color: AppColors.onAccent,
                    size: 44,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// Kartu identitas aplikasi: logo, nama, versi, dan deskripsi.
class _AppCard extends StatelessWidget {
  const _AppCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.caramel,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            const _AppLogo(),
            const SizedBox(height: 16),
            const Text(
              AppInfo.name,
              style: TextStyle(
                fontFamily: appDisplayFontFamily,
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.caramel.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'Versi ${AppInfo.version}',
                style: TextStyle(
                  color: AppColors.caramel,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              AppInfo.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.caramel,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              AppInfo.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 22),
            const SizedBox(
              height: 1,
              child: ColoredBox(color: Color(0x1FF3E6D6)),
            ),
            const SizedBox(height: 16),
            const Row(
              children: <Widget>[
                Expanded(
                  child: _Fact(
                    label: 'VERSI',
                    value: '${AppInfo.version} (${AppInfo.buildNumber})',
                  ),
                ),
                Expanded(
                  child: _Fact(label: 'TAHUN', value: AppInfo.releaseYear),
                ),
                Expanded(
                  child: _Fact(label: 'PLATFORM', value: AppInfo.platforms),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu pengembang: foto, nama, dan peran.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 6),
          child: SectionLabel('Pengembang BrewLogic'),
        ),
        SizedBox(
          width: double.infinity,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                const _Avatar(),
                const SizedBox(height: 16),
                const Text(
                  AppInfo.developerName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: appDisplayFontFamily,
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppInfo.developerRole,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.caramel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppInfo.developerLocation,
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Foto pengembang dalam lingkaran dengan cincin dan cahaya amber. Jika
/// berkas foto tidak ada, tampil inisial.
class _Avatar extends StatelessWidget {
  const _Avatar();

  static const double _size = 112;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Foto ${AppInfo.developerName}',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.caramel.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.caramel.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            AppInfo.developerPhotoAsset,
            fit: BoxFit.cover,
            cacheWidth: (_size * 3).round(),
            errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
                const _InitialsFallback(),
          ),
        ),
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.caramel.withValues(alpha: 0.1),
      child: const Center(
        child: Text(
          AppInfo.developerInitials,
          style: TextStyle(
            color: AppColors.caramel,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 6),
          child: SectionLabel('Fitur utama'),
        ),
        SizedBox(
          width: double.infinity,
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double tile = (box.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final FeatureItem f in AppInfo.features)
                      SizedBox(
                        width: tile,
                        child: _FeatureTile(item: f),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item});

  final FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.caramel.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(item.icon, size: 19, color: AppColors.caramel),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.label,
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu fakta ringkas di kartu aplikasi (versi, tahun, platform).
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(label, style: AppTextStyles.sectionLabel.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Daftar tech stack yang bisa dilipat; tertutup secara bawaan agar halaman
/// tidak panjang.
class _TechStack extends StatefulWidget {
  const _TechStack();

  @override
  State<_TechStack> createState() => _TechStackState();
}

class _TechStackState extends State<_TechStack> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 6),
          child: SectionLabel('Tech stack'),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: <Widget>[
              Semantics(
                button: true,
                expanded: _open,
                label: 'Tech stack, ${AppInfo.techStack.length} item',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${AppInfo.techStack.length} teknologi dipakai',
                            style: AppTextStyles.body,
                          ),
                        ),
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
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _open
                    ? Column(
                        children: <Widget>[
                          for (final TechItem item
                              in AppInfo.techStack) ...<Widget>[
                            const SizedBox(
                              height: 1,
                              child: ColoredBox(color: Color(0x1FF3E6D6)),
                            ),
                            SettingsRow(
                              icon: item.icon,
                              title: item.name,
                              subtitle: item.category,
                              trailing: _Value(item.detail, maxWidth: 120),
                            ),
                          ],
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: SectionLabel(label),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  const SizedBox(
                    height: 1,
                    child: ColoredBox(color: Color(0x1FF3E6D6)),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.maxWidth = 150});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        text,
        textAlign: TextAlign.end,
        style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
      ),
    );
  }
}
