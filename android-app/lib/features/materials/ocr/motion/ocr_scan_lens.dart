import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/motion/app_motion_tokens.dart';
import '../../../../core/motion/motion_preferences.dart';

class OcrScanLensPage extends StatelessWidget {
  const OcrScanLensPage({
    super.key,
    required this.imagePath,
    required this.recognizedText,
  });

  final String imagePath;
  final String recognizedText;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(english ? 'Recognition comparison' : '识别过程对照'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: OcrScanLens(
          imagePath: imagePath,
          recognizedText: recognizedText,
        ),
      ),
    );
  }
}

class OcrScanLens extends StatefulWidget {
  const OcrScanLens({
    super.key,
    required this.imagePath,
    required this.recognizedText,
    this.reduceMotionOverride,
  });

  final String imagePath;
  final String recognizedText;
  final bool? reduceMotionOverride;

  @override
  State<OcrScanLens> createState() => _OcrScanLensState();
}

class _OcrScanLensState extends State<OcrScanLens> {
  double _split = .62;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final reduce =
        widget.reduceMotionOverride ??
        MotionPreferences.of(context).reduceMotion;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                onHorizontalDragUpdate: (details) => setState(
                  () => _split = (details.localPosition.dx / width).clamp(
                    .08,
                    .92,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: scheme.surfaceContainer,
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: scheme.onSurfaceVariant,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                      AnimatedClipRect(
                        fraction: _split,
                        duration: reduce
                            ? Duration.zero
                            : AppMotionTokens.selection,
                        child: ColoredBox(
                          color: scheme.surface.withValues(alpha: .96),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(18),
                            child: SelectableText(
                              widget.recognizedText,
                              style: const TextStyle(height: 1.6),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: width * _split - 2,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 4, color: scheme.primary),
                      ),
                      Positioned(
                        left: width * _split - 22,
                        top: constraints.maxHeight / 2 - 22,
                        child: CircleAvatar(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          child: const Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _Label(
                          text: english ? 'Original' : '原图',
                          color: scheme.onInverseSurface,
                          background: scheme.inverseSurface,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _Label(
                          text: english ? 'Recognized text' : '识别文字',
                          color: scheme.onPrimaryContainer,
                          background: scheme.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          english
              ? 'Drag the divider to compare. Recognition may be inaccurate; review before saving.'
              : '拖动分隔线查看前后差异。OCR 可能存在误识别，请保存前人工校对。',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class AnimatedClipRect extends StatelessWidget {
  const AnimatedClipRect({
    super.key,
    required this.fraction,
    required this.duration,
    required this.child,
  });

  final double fraction;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: fraction),
    duration: duration,
    builder: (context, value, child) =>
        ClipRect(clipper: _FractionClipper(value), child: child),
    child: child,
  );
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    size.width * fraction,
    0,
    size.width * (1 - fraction),
    size.height,
  );

  @override
  bool shouldReclip(covariant _FractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.color,
    required this.background,
  });
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
