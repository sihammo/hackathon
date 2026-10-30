import 'dart:math' as math;

/// One of Algeria's 58 wilayas with the approximate coordinates of its capital.
class Wilaya {
  final int code;
  final String nameFr;
  final String nameAr;
  final double lat;
  final double lng;

  const Wilaya(this.code, this.nameFr, this.nameAr, this.lat, this.lng);

  String name(String lang) => lang == 'ar' ? nameAr : nameFr;

  /// "16 - Alger"
  String label(String lang) => '${code.toString().padLeft(2, '0')} - ${name(lang)}';
}

class Wilayas {
  static const List<Wilaya> all = [
    Wilaya(1, 'Adrar', 'أدرار', 27.874, -0.294),
    Wilaya(2, 'Chlef', 'الشلف', 36.165, 1.335),
    Wilaya(3, 'Laghouat', 'الأغواط', 33.800, 2.865),
    Wilaya(4, 'Oum El Bouaghi', 'أم البواقي', 35.877, 7.113),
    Wilaya(5, 'Batna', 'باتنة', 35.556, 6.174),
    Wilaya(6, 'Béjaïa', 'بجاية', 36.751, 5.056),
    Wilaya(7, 'Biskra', 'بسكرة', 34.850, 5.728),
    Wilaya(8, 'Béchar', 'بشار', 31.617, -2.217),
    Wilaya(9, 'Blida', 'البليدة', 36.470, 2.828),
    Wilaya(10, 'Bouira', 'البويرة', 36.375, 3.902),
    Wilaya(11, 'Tamanrasset', 'تمنراست', 22.785, 5.523),
    Wilaya(12, 'Tébessa', 'تبسة', 35.404, 8.124),
    Wilaya(13, 'Tlemcen', 'تلمسان', 34.878, -1.315),
    Wilaya(14, 'Tiaret', 'تيارت', 35.371, 1.317),
    Wilaya(15, 'Tizi Ouzou', 'تيزي وزو', 36.712, 4.046),
    Wilaya(16, 'Alger', 'الجزائر', 36.754, 3.059),
    Wilaya(17, 'Djelfa', 'الجلفة', 34.673, 3.263),
    Wilaya(18, 'Jijel', 'جيجل', 36.821, 5.766),
    Wilaya(19, 'Sétif', 'سطيف', 36.190, 5.414),
    Wilaya(20, 'Saïda', 'سعيدة', 34.831, 0.151),
    Wilaya(21, 'Skikda', 'سكيكدة', 36.876, 6.909),
    Wilaya(22, 'Sidi Bel Abbès', 'سيدي بلعباس', 35.190, -0.631),
    Wilaya(23, 'Annaba', 'عنابة', 36.900, 7.766),
    Wilaya(24, 'Guelma', 'قالمة', 36.462, 7.426),
    Wilaya(25, 'Constantine', 'قسنطينة', 36.365, 6.615),
    Wilaya(26, 'Médéa', 'المدية', 36.264, 2.754),
    Wilaya(27, 'Mostaganem', 'مستغانم', 35.931, 0.089),
    Wilaya(28, "M'Sila", 'المسيلة', 35.706, 4.542),
    Wilaya(29, 'Mascara', 'معسكر', 35.397, 0.140),
    Wilaya(30, 'Ouargla', 'ورقلة', 31.949, 5.325),
    Wilaya(31, 'Oran', 'وهران', 35.697, -0.633),
    Wilaya(32, 'El Bayadh', 'البيض', 33.683, 1.019),
    Wilaya(33, 'Illizi', 'إليزي', 26.483, 8.467),
    Wilaya(34, 'Bordj Bou Arréridj', 'برج بوعريريج', 36.073, 4.761),
    Wilaya(35, 'Boumerdès', 'بومرداس', 36.766, 3.477),
    Wilaya(36, 'El Tarf', 'الطارف', 36.767, 8.314),
    Wilaya(37, 'Tindouf', 'تندوف', 27.671, -8.147),
    Wilaya(38, 'Tissemsilt', 'تيسمسيلت', 35.607, 1.811),
    Wilaya(39, 'El Oued', 'الوادي', 33.368, 6.867),
    Wilaya(40, 'Khenchela', 'خنشلة', 35.436, 7.143),
    Wilaya(41, 'Souk Ahras', 'سوق أهراس', 36.286, 7.951),
    Wilaya(42, 'Tipaza', 'تيبازة', 36.589, 2.447),
    Wilaya(43, 'Mila', 'ميلة', 36.450, 6.264),
    Wilaya(44, 'Aïn Defla', 'عين الدفلى', 36.264, 1.968),
    Wilaya(45, 'Naâma', 'النعامة', 33.267, -0.313),
    Wilaya(46, 'Aïn Témouchent', 'عين تموشنت', 35.297, -1.140),
    Wilaya(47, 'Ghardaïa', 'غرداية', 32.490, 3.674),
    Wilaya(48, 'Relizane', 'غليزان', 35.737, 0.556),
    Wilaya(49, 'Timimoun', 'تيميمون', 29.263, 0.241),
    Wilaya(50, 'Bordj Badji Mokhtar', 'برج باجي مختار', 21.328, 0.955),
    Wilaya(51, 'Ouled Djellal', 'أولاد جلال', 34.418, 5.068),
    Wilaya(52, 'Béni Abbès', 'بني عباس', 30.131, -2.166),
    Wilaya(53, 'In Salah', 'عين صالح', 27.197, 2.481),
    Wilaya(54, 'In Guezzam', 'عين قزام', 19.567, 5.770),
    Wilaya(55, 'Touggourt', 'تقرت', 33.105, 6.065),
    Wilaya(56, 'Djanet', 'جانت', 24.554, 9.485),
    Wilaya(57, "El M'Ghair", 'المغير', 33.950, 5.924),
    Wilaya(58, 'El Meniaa', 'المنيعة', 30.580, 2.880),
  ];

  static Wilaya? byCode(int? code) {
    if (code == null || code < 1 || code > all.length) return null;
    return all[code - 1];
  }

  static String nameOf(int? code, String lang) => byCode(code)?.name(lang) ?? '—';

  /// Nearest wilaya capital. Approximate near borders; used as a fallback
  /// when reverse geocoding is not available.
  static Wilaya nearest(double lat, double lng) {
    Wilaya best = all.first;
    double bestD = double.infinity;
    for (final w in all) {
      final d = _haversineKm(lat, lng, w.lat, w.lng);
      if (d < bestD) {
        bestD = d;
        best = w;
      }
    }
    return best;
  }

  /// Match a reverse-geocoded administrative area ("Wilaya d'Oran",
  /// "Province de Béjaïa", "ولاية وهران"...) to a wilaya.
  static Wilaya? matchName(String? area) {
    if (area == null || area.trim().isEmpty) return null;
    final n = _norm(area);
    Wilaya? best;
    int bestLen = 0;
    for (final w in all) {
      final names = [w.nameFr, w.nameAr, ...?_aliases[w.code]];
      for (final cand in names.map(_norm)) {
        if (cand.isNotEmpty && n.contains(cand) && cand.length > bestLen) {
          best = w;
          bestLen = cand.length;
        }
      }
    }
    return best;
  }

  /// Other spellings returned by geocoders (English locale, transliterations).
  static const Map<int, List<String>> _aliases = {
    2: ['Ech Chlef', 'Ech Cheliff'],
    11: ['Tamanghasset'],
    16: ['Algiers', 'Alger'],
    42: ['Tipasa'],
    48: ['Ghilizane'],
    54: ['In Guezzam', 'Ain Guezzam'],
    53: ['Ain Salah'],
  };

  static String _norm(String s) {
    const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      final i = from.indexOf(c);
      if (i >= 0) {
        b.write(to[i]);
      } else if (RegExp(r"[a-z0-9؀-ۿ]").hasMatch(c)) {
        b.write(c);
      }
    }
    return b.toString();
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double d) => d * math.pi / 180;
}
