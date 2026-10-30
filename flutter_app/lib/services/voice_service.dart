import 'dart:js_interop' as js_util;
import 'package:flutter/foundation.dart';

@js_util.JS('speakWarning')
external void _jsSpeakWarning(js_util.JSString text, js_util.JSString lang);

/// Voice service for speaking proximity warnings and emergency notices.
class VoiceService {
  static void speak(String text, {String lang = 'fr-FR'}) {
    if (kIsWeb) {
      try {
        _jsSpeakWarning(text.toJS, lang.toJS);
      } catch (e) {
        debugPrint('Voice synthesis error: $e');
      }
    }
  }

  static void speakBlackPointWarning({bool isArabic = false}) {
    if (isArabic) {
      speak(
        'انتبه! أنت تقترب من منطقة حوادث سابقة. يُرجى تخفيف السرعة والحذر.',
        lang: 'ar-SA',
      );
    } else {
      speak(
        "Attention ! Vous approchez d'un point noir accidentogène. Un accident a déjà eu lieu ici. Veuillez ralentir.",
        lang: 'fr-FR',
      );
    }
  }

  static void speakSafeRouteSelected({required String destination, int blackPointsAvoided = 3, bool isArabic = false}) {
    if (isArabic) {
      speak(
        'تم تشغيل المسار الآمن باللون الأخضر. هذا المسار يتفادى $blackPointsAvoided مناطق حوادث سابقة. قيادة موفقة!',
        lang: 'ar-SA',
      );
    } else {
      speak(
        "Itinéraire sécurisé activé vers $destination. Ce trajet vert évite $blackPointsAvoided zones d'accidents récurrents. Bonne route !",
        lang: 'fr-FR',
      );
    }
  }
}
