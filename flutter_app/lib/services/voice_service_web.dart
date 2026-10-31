import 'dart:js_interop' as js_util;
import 'package:flutter/foundation.dart';

@js_util.JS('speakWarning')
external void _jsSpeakWarning(js_util.JSString text, js_util.JSString lang);

void speakWeb(String text, String lang) {
  try {
    _jsSpeakWarning(text.toJS, lang.toJS);
  } catch (e) {
    debugPrint('Voice synthesis error: $e');
  }
}
