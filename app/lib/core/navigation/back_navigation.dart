import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hisaabchat/core/navigation/browser_history.dart';

/// One Back, every platform: closes the top screen (form, sheet, dialog,
/// chat, Settings page) if there is one, otherwise goes to Home; returns
/// false when there was nothing to go back from.
typedef BackHandler = Future<bool> Function();

/// "Go back": Esc on Windows and web.
class BackIntent extends Intent {
  const BackIntent();
}

/// Windows and web: Esc and the mouse's side "back" button do what Android's
/// Back does. (Android's own Back already arrives through the router; on web
/// the mouse button is left to the browser, which [WebModalHistory] handles.)
class BackShortcuts extends StatelessWidget {
  const BackShortcuts({required this.onBack, required this.child, super.key});

  final BackHandler onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: kIsWeb
          ? null
          : (event) {
              if (event.buttons & kBackMouseButton != 0) unawaited(onBack());
            },
      // Esc closes whatever is on top: a dialog, sheet, menu, full-screen form
      // or chat (full pages ignore the default "dismiss" Esc, hence our own).
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{SingleActivator(LogicalKeyboardKey.escape): BackIntent()},
        child: Actions(
          actions: <Type, Action<Intent>>{BackIntent: CallbackAction<BackIntent>(onInvoke: (_) => onBack())},
          child: child,
        ),
      ),
    );
  }
}

/// Web: gives every screen opened on top of a page (forms, sheets, dialogs,
/// menus; they have no URL of their own) a browser-history entry, so the
/// browser's Back closes it instead of changing the page underneath or
/// leaving the site. Closing it any other way removes that entry again.
///
/// Register with the binding *before* the router is created, so it sees the
/// browser's Back before go_router does.
class WebModalHistory extends NavigatorObserver with WidgetsBindingObserver {
  WebModalHistory({required this.enabled, this.historyBack = browserHistoryBack});

  /// Only on web (overridden in tests).
  final bool enabled;

  /// Steps the browser back (injectable for tests).
  final void Function() historyBack;

  /// Where the page underneath is (the router's current URL).
  Uri Function() currentLocation = () => Uri.parse('/');

  final List<Route<dynamic>> _open = [];

  /// Pops we caused because the browser went back (no extra history step).
  int _closingFromBrowser = 0;

  /// Browser Back events we caused ourselves (to drop an entry); swallowed.
  int _ignoreBrowserBack = 0;

  static bool _isOverlay(Route<dynamic> route) => route.settings is! Page<dynamic>;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!enabled || !_isOverlay(route)) return;
    _open.add(route);
    unawaited(SystemNavigator.routeInformationUpdated(uri: currentLocation()));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!enabled || !_open.remove(route)) return;
    if (_closingFromBrowser > 0) {
      _closingFromBrowser--;
    } else {
      // Closed by the app (Save, ×, tap outside): drop its history entry.
      _ignoreBrowserBack++;
      historyBack();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Removed by a page change: its entry is left behind on purpose, since
    // stepping back now would undo that page change.
    _open.remove(route);
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    if (!enabled) return SynchronousFuture(false);
    if (_ignoreBrowserBack > 0) {
      _ignoreBrowserBack--;
      return SynchronousFuture(true);
    }
    if (_open.isNotEmpty) {
      final top = _open.last;
      _closingFromBrowser++;
      final navigator = top.navigator;
      if (navigator != null && top.isCurrent) {
        unawaited(navigator.maybePop());
      } else {
        _closingFromBrowser--;
        _open.remove(top);
      }
      return SynchronousFuture(true);
    }
    return SynchronousFuture(false);
  }
}
