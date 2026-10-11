// `window.history.back()` on web; does nothing on other platforms.
export 'browser_history_stub.dart' if (dart.library.js_interop) 'browser_history_web.dart';
