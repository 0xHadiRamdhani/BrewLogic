import 'package:flutter/widgets.dart';

/// Teks yang memudar dan menskala saat nilainya berubah (implicit animation).
class AnimatedValueText extends StatelessWidget {
  const AnimatedValueText({
    super.key,
    required this.text,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.duration = const Duration(milliseconds: 280),
  });

  final String text;
  final TextStyle style;
  final Alignment alignment;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            alignment: alignment,
            scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          alignment: alignment,
          children: <Widget>[...previous, ?current],
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }
}
