import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion/app_motion_tokens.dart';
import '../../../core/motion/motion_preferences.dart';
import '../service_mode_controller.dart';
import 'service_mode_card.dart';
import 'service_mode_transition_controller.dart';

class ServiceModePortal extends StatefulWidget {
  const ServiceModePortal({
    super.key,
    required this.currentMode,
    required this.officialServiceEnabled,
    this.motionLab = false,
    this.reduceMotionOverride,
    this.lowPerformance = false,
  });

  final AiServiceMode currentMode;
  final bool officialServiceEnabled;
  final bool motionLab;
  final bool? reduceMotionOverride;
  final bool lowPerformance;

  @override
  State<ServiceModePortal> createState() => _ServiceModePortalState();
}

class _ServiceModePortalState extends State<ServiceModePortal> {
  late final ServiceModeTransitionController _controller;
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _controller = ServiceModeTransitionController(widget.currentMode)..open();
    _pages = PageController(
      initialPage: widget.currentMode == AiServiceMode.byok ? 0 : 1,
      viewportFraction: .86,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _select(AiServiceMode mode) {
    if (_controller.locked) return;
    _controller.select(mode);
    final settings = MotionPreferences.of(context);
    if (settings.hapticsEnabled) HapticFeedback.selectionClick();
    final target = mode == AiServiceMode.byok ? 0 : 1;
    if (_pages.hasClients && (_pages.page ?? target).round() != target) {
      _pages.animateToPage(
        target,
        duration: AppMotionTokens.selection,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _confirm() {
    _controller.confirm();
    final settings = MotionPreferences.of(context);
    if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_controller.selected);
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final prefs = MotionPreferences.of(
      context,
      simulateLowPerformance: widget.lowPerformance,
    );
    final reduce = widget.reduceMotionOverride ?? prefs.reduceMotion;
    final blur = !reduce && !widget.lowPerformance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur ? 10 : 0,
                sigmaY: blur ? 10 : 0,
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 680,
                  maxHeight: 610,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: blur ? .91 : 1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  english ? 'AI service portal' : 'AI 服务传送门',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  english
                                      ? 'Switching keeps your materials and configuration.'
                                      : '切换不会删除资料、API 配置或试卷草稿。',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => PageView(
                          controller: _pages,
                          onPageChanged: (index) => _select(
                            index == 0
                                ? AiServiceMode.byok
                                : AiServiceMode.official,
                          ),
                          children: [
                            for (final mode in AiServiceMode.values)
                              AnimatedScale(
                                duration: AppMotionTokens.resolve(
                                  reduceMotion: reduce,
                                  regular: AppMotionTokens.selection,
                                ),
                                scale: _controller.selected == mode ? 1 : .94,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    12,
                                    8,
                                    18,
                                  ),
                                  child: ServiceModePortalCard(
                                    mode: mode,
                                    selected: _controller.selected == mode,
                                    officialServiceEnabled:
                                        widget.officialServiceEnabled,
                                    onTap: () => _select(mode),
                                    heroEnabled:
                                        !widget.motionLab &&
                                        mode == widget.currentMode,
                                    reduceMotion: reduce,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _confirm,
                          icon: Icon(
                            _controller.selected == AiServiceMode.byok
                                ? Icons.key_rounded
                                : Icons.cloud_outlined,
                          ),
                          label: Text(
                            _controller.selected == AiServiceMode.byok
                                ? (english ? 'Use my API Key' : '使用自己的 API Key')
                                : (english
                                      ? 'Enter official service preview'
                                      : '进入官方服务说明'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
