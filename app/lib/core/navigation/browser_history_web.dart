import 'dart:js_interop';

@JS('window.history.back')
external void _historyBack();

/// Steps the browser back one history entry (fires `popstate`).
void browserHistoryBack() => _historyBack();
