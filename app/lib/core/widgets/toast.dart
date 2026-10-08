import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';

enum ToastKind { success, error, info }

/// App-wide toast (replaces SnackBars).
///
/// A floating pill that slides up from the bottom, shows an icon for its
/// kind and an optional green action ("Undo"). It always sits above any
/// [ToastAvoid] region on screen (the chat composer, the bottom tab bar, the
/// + button) so it never covers what you're typing or tapping.
abstract final class AppToast {
  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) => of(context).show(message, kind: kind, actionLabel: actionLabel, onAction: onAction, duration: duration);

  static void success(BuildContext context, String message) => show(context, message, kind: ToastKind.success);

  static void error(BuildContext context, String message) => show(context, message, kind: ToastKind.error);

  /// The host, for showing a toast after an `await` (read it before awaiting).
  static ToastHostState of(BuildContext context) {
    final host = context.findAncestorStateOfType<ToastHostState>();
    assert(host != null, 'No ToastHost above this context. Wrap the app with ToastHost.');
    return host!;
  }
}

/// Marks a region the toast must stay above.
class ToastAvoid extends StatefulWidget {
  const ToastAvoid({required this.child, super.key});

  final Widget child;

  @override
  State<ToastAvoid> createState() => _ToastAvoidState();
}

class _ToastAvoidState extends State<ToastAvoid> {
  ToastHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = context.findAncestorStateOfType<ToastHostState>();
    if (host != _host) {
      _host?._avoid.remove(this);
      _host = host?.._avoid.add(this);
    }
  }

  @override
  void dispose() {
    _host?._avoid.remove(this);
    super.dispose();
  }

  /// Top edge in global coordinates, or null when not on screen.
  double? get top {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return null;
    // Skip regions hidden behind another route or in an inactive tab.
    if (!(ModalRoute.of(context)?.isCurrent ?? true) || !TickerMode.valuesOf(context).enabled) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

@immutable
class _ToastData {
  const _ToastData({required this.id, required this.message, required this.kind, this.actionLabel, this.onAction});

  final int id;
  final String message;
  final ToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Hosts toasts above the whole app (installed in `MaterialApp.builder`).
class ToastHost extends StatefulWidget {
  const ToastHost({required this.child, super.key});

  final Widget child;

  @override
  State<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends State<ToastHost> with SingleTickerProviderStateMixin {
  final Set<_ToastAvoidState> _avoid = {};
  late final AnimationController _controller;
  _ToastData? _current;
  Timer? _timer;

  /// Re-measures while a toast is visible: a route may finish closing (and
  /// reveal a composer) after the toast appeared.
  Timer? _tracker;
  double? _offset;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy controller would first be built inside dispose().
    _controller = AnimationController(vsync: this, duration: Motion.medium, reverseDuration: Motion.short);
  }

  void show(
    String message, {
    ToastKind kind = ToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    if (!mounted) return;
    _timer?.cancel();
    final data = _ToastData(
      id: _nextId++,
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    if (kind == ToastKind.error) unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _current = data;
      _offset = _bottomOffset();
    });
    _tracker?.cancel();
    _tracker = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final offset = _bottomOffset();
      if (mounted && offset != _offset) setState(() => _offset = offset);
    });
    _controller.duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.medium;
    unawaited(_controller.forward(from: 0));
    // Errors and undoable actions stay a little longer.
    final visibleFor =
        duration ??
        (actionLabel != null || kind == ToastKind.error ? const Duration(seconds: 5) : const Duration(seconds: 3));
    _timer = Timer(visibleFor, () => hide(data.id));
  }

  Future<void> hide([int? id]) async {
    if (_current == null || (id != null && _current!.id != id)) return;
    _timer?.cancel();
    final hidingId = _current!.id;
    await _controller.reverse();
    if (mounted && _current?.id == hidingId) _clear();
  }

  void _clear() {
    _tracker?.cancel();
    setState(() => _current = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tracker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Distance from the bottom of the screen: above the highest keep-clear
  /// region (which already sits above the keyboard), else above the keyboard.
  double _bottomOffset() {
    final media = MediaQuery.of(context);
    final tops = _avoid.map((a) => a.top).whereType<double>();
    if (tops.isEmpty) return math.max(media.viewInsets.bottom, media.viewPadding.bottom) + 16;
    return math.max(media.size.height - tops.reduce(math.min), media.viewPadding.bottom) + 12;
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final compact = WindowClass.of(context) == WindowClass.compact;
    return Stack(
      children: [
        widget.child,
        if (current != null)
          AnimatedPositioned(
            duration: context.motion(Motion.medium),
            curve: Motion.standard,
            // Phones: centered. Wider windows: bottom-left next to the rail (WhatsApp Web).
            left: compact ? 16 : 64 + 16,
            right: 16,
            bottom: _offset ?? 16,
            child: Align(
              alignment: compact ? Alignment.bottomCenter : Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 480 : 400),
                child: _ToastView(
                  key: ValueKey(current.id),
                  data: current,
                  animation: _controller,
                  onDismissed: _clear,
                  onAction: () {
                    current.onAction?.call();
                    unawaited(hide(current.id));
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({
    required this.data,
    required this.animation,
    required this.onDismissed,
    required this.onAction,
    super.key,
  });

  final _ToastData data;
  final Animation<double> animation;
  final VoidCallback onDismissed;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, Color iconColor) = switch (data.kind) {
      ToastKind.success => (AppIcons.ok, colors.toastSuccess),
      ToastKind.error => (AppIcons.failed, colors.toastError),
      ToastKind.info => (AppIcons.info, colors.toastInfo),
    };
    final curved = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.toastBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 6, data.actionLabel == null ? 16 : 6, 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(icon, color: iconColor, fill: 1, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.message,
                    style: TextStyle(color: colors.onToast, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ),
                if (data.actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.toastAction,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    child: Text(data.actionLabel!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: Dismissible(
              key: ValueKey('toast-${data.id}'),
              onDismissed: (_) => onDismissed(),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}
