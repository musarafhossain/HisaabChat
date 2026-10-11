import 'dart:js_interop';
import 'dart:ui';

@JS('document.querySelector')
external JSObject? _querySelector(String selector);

extension type _Element(JSObject _) implements JSObject {
  external void setAttribute(String name, String value);
}

String? _current;

/// Updates `<meta name="theme-color">`: the color of Chrome's top bar on
/// phones and of the installed web app's title bar.
void setBrowserThemeColor(Color color) {
  final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  if (hex == _current) return;
  final meta = _querySelector('meta[name="theme-color"]');
  if (meta == null) return;
  _Element(meta).setAttribute('content', hex);
  _current = hex;
}
