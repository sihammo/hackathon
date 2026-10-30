import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language (Arabic / French), persisted on the phone.
class LocaleController extends ChangeNotifier {
  static const supported = [Locale('ar'), Locale('fr')];
  static const _key = 'app_language';

  final SharedPreferences _prefs;
  late String lang;

  LocaleController(this._prefs) {
    lang = _prefs.getString(_key) ?? 'fr';
  }

  Locale get locale => Locale(lang);

  Future<void> setLanguage(String l) async {
    if (l == lang) return;
    lang = l;
    await _prefs.setString(_key, l);
    notifyListeners();
  }
}

extension Tr on BuildContext {
  String get lang => Localizations.localeOf(this).languageCode;

  /// Translated string for [key]; falls back to French, then to the key.
  String tr(String key) => AppStrings.get(lang, key);
}

class AppStrings {
  static String get(String lang, String key) =>
      (lang == 'ar' ? _ar[key] : _fr[key]) ?? _fr[key] ?? key;

  static const Map<String, String> _fr = {
    // General
    'app_name': 'Slamtek',
    'app_tagline': "Alerte automatique en cas d'accident de la route",
    'hello': 'Bonjour',
    'cancel': 'Annuler',
    'confirm': 'Confirmer',
    'save': 'Enregistrer',
    'saved': 'Enregistré',
    'close': 'Fermer',
    'yes': 'Oui',
    'no': 'Non',
    'all': 'Tous',
    'default': 'Par défaut',
    'not_set': 'Non défini',
    'ignore': 'Ignorer',
    'results': 'résultat(s)',
    'days': 'jours',
    'show_all': 'Tout afficher',
    'show_less': 'Afficher moins',

    // Auth
    'username': "Nom d'utilisateur",
    'username_hint': '3 à 20 caractères : lettres, chiffres, _ ou .',
    'password': 'Mot de passe',
    'password_hint': '6 caractères minimum',
    'password_confirm': 'Confirmer le mot de passe',
    'login': 'Se connecter',
    'create_account': 'Créer mon compte',
    'full_name': 'Nom complet',
    'phone': 'Numéro de téléphone',
    'wilaya': 'Wilaya',
    'logout': 'Se déconnecter',
    'logout_confirm': 'Voulez-vous vous déconnecter ?',
    'err_required': 'Champ obligatoire',
    'err_bad_credentials': "Nom d'utilisateur ou mot de passe incorrect",
    'err_username_taken': "Ce nom d'utilisateur est déjà pris",
    'err_username_format': "Nom d'utilisateur invalide (3 à 20 caractères : a-z, 0-9, _ ou .)",
    'err_weak_password': 'Mot de passe trop court (6 caractères minimum)',
    'err_password_mismatch': 'Les mots de passe ne correspondent pas',
    'err_phone': 'Numéro de téléphone invalide',
    'err_disabled': 'Ce compte a été désactivé par un administrateur',
    'err_too_many': 'Trop de tentatives. Réessayez plus tard.',
    'err_network': 'Problème de connexion Internet',
    'err_no_profile': 'Profil introuvable pour ce compte',
    'err_generic': "Une erreur s'est produite",

    // Navigation
    'nav_home': 'Accueil',
    'nav_map': 'Carte',
    'nav_history': 'Historique',
    'nav_contacts': 'Contacts',
    'nav_settings': 'Paramètres',

    // Home / device
    'device': 'Boîtier Slamtek',
    'connected': 'Connecté',
    'connecting': 'Connexion…',
    'disconnected': 'Déconnecté',
    'gps_fix': 'GPS actif',
    'gps_no_fix': 'GPS : recherche de satellites…',
    'pair_device': 'Associer le boîtier',
    'change_device': 'Changer de boîtier',
    'reconnect': 'Reconnecter',
    'calibrate': 'Calibrer la position',
    'calibrated': 'Position de référence calibrée',
    'device_not_connected': "Le boîtier n'est pas connecté",
    'device_paired': 'Boîtier associé',
    'connection_failed': 'Échec de la connexion au boîtier',
    'forget_device': 'Oublier le boîtier',
    'forget_device_confirm': 'Dissocier ce boîtier du téléphone ?',
    'bluetooth_off': 'Activez le Bluetooth pour rechercher le boîtier',
    'scan_hint': 'Allumez le boîtier Slamtek et gardez le téléphone à proximité.',
    'scan_again': 'Rechercher à nouveau',
    'no_device_found': 'Aucun boîtier Slamtek trouvé pour le moment',
    'connect': 'Connecter',
    'permissions_needed': 'Autorisations nécessaires',
    'permissions_desc':
        "Slamtek a besoin du Bluetooth, de la localisation, des SMS et des appels pour prévenir les secours.",
    'grant_permissions': 'Autoriser',

    // Vehicle
    'vehicle_type': 'Type de véhicule',
    'car': 'Voiture',
    'motorcycle': 'Moto',
    'car_desc': 'Seuil de choc élevé + détection de tonneau.',
    'moto_desc': 'Seuil de choc plus bas + détection de chute (inclinaison).',
    'vehicle_sent': 'Réglage envoyé au boîtier',
    'vehicle_not_sent': "Réglage enregistré, mais non envoyé au boîtier",

    // Wilaya / numbers
    'emergency_numbers': "Numéros d'urgence",
    'police': 'Police',
    'civil_protection': 'Protection civile',
    'numbers_not_configured': "Les numéros de cette wilaya ne sont pas encore configurés par l'administrateur.",
    'wilaya_auto_note': "Lors d'un accident, la wilaya est déterminée à partir de la position GPS.",
    'wilaya_detected': 'Wilaya détectée',
    'wilaya_detected_desc': 'Votre position GPS indique : {w}. Utiliser cette wilaya ?',
    'use_this_wilaya': 'Utiliser cette wilaya',
    'detect_wilaya': 'Détecter avec le GPS',

    // Test mode
    'test_mode': 'Mode test',
    'test_mode_desc':
        'Remplace les numéros de la police et de la protection civile par le numéro de test.',
    'test_mode_active': 'MODE TEST — aucun service réel ne sera contacté',
    'test_mode_banner': 'Mode test activé : la police et la protection civile ne seront jamais contactées.',
    'test_mode_replaces': 'En mode test, ce numéro remplace la police et la protection civile.',
    'test_mode_forced': "Le mode test est imposé par l'administrateur.",
    'test_mode_off_confirm':
        "Désactiver le mode test ? Les VRAIS numéros de la police et de la protection civile seront contactés en cas d'alerte.",
    'test_mode_sent_note': 'Mode test : le numéro de test a remplacé les services d’urgence.',
    'test_number': 'Numéro de test',
    'test_number_hint': 'Ex. votre propre numéro ou celui d’un coéquipier',
    'test_number_missing': 'Aucun numéro de test défini : seuls vos contacts ont été prévenus.',
    'test_tools': 'Outils de test',
    'simulate_accident': 'Simuler un accident',
    'device_test_alert': 'Alerte test depuis le boîtier',
    'force_test_mode': 'Imposer le mode test à tous',
    'force_test_mode_desc': "Tant qu'il est activé, aucun utilisateur ne peut contacter les vrais services.",
    'default_test_number': 'Numéro de test par défaut',
    'default_test_number_desc': "Utilisé si l'utilisateur n'a pas défini son propre numéro de test.",

    // Alarm
    'accident_detected': 'ACCIDENT DÉTECTÉ',
    'alert_in_seconds': 'Les secours et vos contacts seront alertés dans {s} s',
    'im_ok_cancel': 'JE VAIS BIEN – ANNULER',
    'send_now': 'Envoyer maintenant',
    'sending_alert': "Envoi de l'alerte…",
    'alert_sent': 'Alerte envoyée',
    'alert_failed': "L'alerte n'a pas pu être envoyée",
    'alert_cancelled': 'Alerte annulée',
    'alert_cancelled_desc': "Content de savoir que vous allez bien. L'événement a été enregistré.",
    'sms_sent_to': 'SMS envoyé à',
    'sms_failed': 'Échec SMS',
    'called': 'Appel vers',
    'location_included': 'Position GPS incluse (lien Google Maps)',
    'location_unavailable': 'Position GPS indisponible',
    'alert_saved': 'Alerte enregistrée',
    'alert_not_saved': "Alerte non enregistrée (pas d'Internet)",
    'trigger': 'Déclencheur',
    'trigger_impact': 'Choc violent',
    'trigger_fall': 'Chute (moto couchée)',
    'trigger_rollover': 'Tonneau',
    'trigger_test': 'Test depuis le boîtier',
    'trigger_simulation': 'Simulation',
    'peak_g': 'Choc maximal',
    'tilt': 'Inclinaison',

    // Contacts
    'emergency_contacts': "Contacts d'urgence",
    'contacts_desc': "Ces personnes recevront un SMS avec votre position en cas d'accident.",
    'add_contact': 'Ajouter',
    'edit_contact': 'Modifier le contact',
    'contact_name': 'Nom',
    'relation': 'Lien',
    'relation_hint': 'Ex. père, sœur, ami',
    'no_contacts': "Aucun contact d'urgence. Ajoutez au moins une personne.",
    'delete_contact_confirm': 'Supprimer ce contact ?',

    // History / details
    'my_alerts': 'Mes alertes',
    'no_alerts': 'Aucune alerte',
    'alert_details': "Détails de l'alerte",
    'summary': 'Résumé',
    'date': 'Date',
    'response_time': "Temps d'intervention",
    'open_in_maps': 'Ouvrir dans Google Maps',
    'mark_as': 'Marquer',
    'status': 'Statut',
    'status_cancelled': 'Annulée',
    'status_sent': 'Envoyée',
    'status_received': 'Reçue',
    'status_dispatched': 'Équipe envoyée',
    'status_arrived': 'Arrivée sur place',
    'status_resolved': 'Résolue',

    // Map
    'hotspots_legend': "Lieux d'accidents",

    // Settings
    'profile': 'Profil',
    'language': 'Langue',

    // Admin
    'admin_dashboard': 'Tableau de bord',
    'admin_alerts': 'Alertes',
    'admin_map': 'Carte',
    'admin_users': 'Utilisateurs',
    'admin_wilayas': 'Numéros',
    'users': 'Utilisateurs',
    'devices': 'Boîtiers',
    'alerts': 'Alertes',
    'total': 'Total',
    'new_7d': 'Nouveaux (7 j)',
    'new_30d': 'Nouveaux (30 j)',
    'disabled': 'Désactivé',
    'active': 'Actif',
    'registered': 'Enregistrés',
    'online': 'Connectés',
    'today': "Aujourd'hui",
    'last_7d': '7 derniers jours',
    'last_30d': '30 derniers jours',
    'include_test_alerts': 'Inclure les alertes de test',
    'cancelled_by_user': "Annulées par l'utilisateur",
    'alerts_over_time': 'Alertes dans le temps',
    'alerts_by_wilaya': 'Alertes par wilaya',
    'response_times': "Temps d'intervention moyen",
    'response_time_desc': "Temps entre l'alerte et l'arrivée de l'équipe sur place.",
    'no_response_data': "Pas encore de données d'intervention",
    'filter_date': 'Date',
    'clear_filters': 'Effacer',
    'search_users': 'Rechercher (nom, utilisateur, téléphone, wilaya)',
    'no_users': 'Aucun utilisateur',
    'role': 'Rôle',
    'role_admin': 'Administrateur',
    'role_user': 'Utilisateur',
    'created_at': 'Inscrit le',
    'enable_user_confirm': 'Réactiver ce compte ?',
    'disable_user_confirm': 'Désactiver ce compte ? La personne ne pourra plus se connecter.',
    'search_wilaya': 'Rechercher une wilaya',
    'wilayas_missing': 'Wilayas sans numéros',
    'seed_defaults': 'Créer les numéros par défaut (17 / 14)',
    'seed_confirm':
        'Créer les wilayas manquantes avec les numéros nationaux (Police 17, Protection civile 14) ? Vous pourrez ensuite les modifier.',
    'seed_done': 'Wilayas créées',
    'not_configured': 'Non configuré',
    'numbers_sms_note':
        'Les numéros courts (17, 14) acceptent les appels mais pas les SMS. Préférez une ligne directe pour recevoir le SMS.',
    'black_point_alert': "Point Noir - Zone d'accident",
    'black_point_warning': "Attention ! Vous êtes à proximité d'un endroit où un accident s'est déjà produit. Ralentissez !",
    'listen_voice_alert': "Écouter l'alerte vocale",
    'user_location': "Position en temps réel",
    'safe_zone': "Zone sécurisée",
    'black_point_simulate': "Simuler approche Point Noir",
    'safe_zone_simulate': "Zone sécurisée",
    'trik_sure': "Trik Sûre (Itinéraire sans accidents)",
    'trik_sure_desc': "Trouver la route qui évite les zones d'accidents",
    'safe_route_rec': "Itinéraire Sécurisé (Recommandé)",
    'risky_route': "Itinéraire Standard (À Risque)",
    'start_safe_nav': "Démarrer le Guidage Sécurisé",
  };

  static const Map<String, String> _ar = {
    // General
    'app_name': 'سلامتك',
    'app_tagline': 'تنبيه تلقائي عند وقوع حادث مرور',
    'hello': 'مرحبا',
    'cancel': 'إلغاء',
    'confirm': 'تأكيد',
    'save': 'حفظ',
    'saved': 'تم الحفظ',
    'close': 'إغلاق',
    'yes': 'نعم',
    'no': 'لا',
    'all': 'الكل',
    'default': 'افتراضي',
    'not_set': 'غير محدد',
    'ignore': 'تجاهل',
    'results': 'نتيجة',
    'days': 'يوم',
    'show_all': 'عرض الكل',
    'show_less': 'عرض أقل',

    // Auth
    'username': 'اسم المستخدم',
    'username_hint': 'من 3 إلى 20 حرفا: حروف لاتينية، أرقام، _ أو .',
    'password': 'كلمة المرور',
    'password_hint': '6 أحرف على الأقل',
    'password_confirm': 'تأكيد كلمة المرور',
    'login': 'تسجيل الدخول',
    'create_account': 'إنشاء حسابي',
    'full_name': 'الاسم الكامل',
    'phone': 'رقم الهاتف',
    'wilaya': 'الولاية',
    'logout': 'تسجيل الخروج',
    'logout_confirm': 'هل تريد تسجيل الخروج؟',
    'err_required': 'حقل إلزامي',
    'err_bad_credentials': 'اسم المستخدم أو كلمة المرور غير صحيحة',
    'err_username_taken': 'اسم المستخدم هذا مستعمل',
    'err_username_format': 'اسم مستخدم غير صالح (3 إلى 20 حرفا: a-z، 0-9، _ أو .)',
    'err_weak_password': 'كلمة المرور قصيرة جدا (6 أحرف على الأقل)',
    'err_password_mismatch': 'كلمتا المرور غير متطابقتين',
    'err_phone': 'رقم هاتف غير صالح',
    'err_disabled': 'تم تعطيل هذا الحساب من طرف المسؤول',
    'err_too_many': 'محاولات كثيرة. حاول لاحقا.',
    'err_network': 'مشكلة في الاتصال بالإنترنت',
    'err_no_profile': 'لم يتم العثور على ملف هذا الحساب',
    'err_generic': 'حدث خطأ',

    // Navigation
    'nav_home': 'الرئيسية',
    'nav_map': 'الخريطة',
    'nav_history': 'السجل',
    'nav_contacts': 'جهات الاتصال',
    'nav_settings': 'الإعدادات',

    // Home / device
    'device': 'جهاز سلامتك',
    'connected': 'متصل',
    'connecting': 'جار الاتصال…',
    'disconnected': 'غير متصل',
    'gps_fix': 'GPS يعمل',
    'gps_no_fix': 'GPS: جار البحث عن الأقمار الصناعية…',
    'pair_device': 'ربط الجهاز',
    'change_device': 'تغيير الجهاز',
    'reconnect': 'إعادة الاتصال',
    'calibrate': 'معايرة الوضعية',
    'calibrated': 'تمت معايرة الوضعية المرجعية',
    'device_not_connected': 'الجهاز غير متصل',
    'device_paired': 'تم ربط الجهاز',
    'connection_failed': 'فشل الاتصال بالجهاز',
    'forget_device': 'إلغاء ربط الجهاز',
    'forget_device_confirm': 'إلغاء ربط هذا الجهاز بالهاتف؟',
    'bluetooth_off': 'شغّل البلوتوث للبحث عن الجهاز',
    'scan_hint': 'شغّل جهاز سلامتك وأبق الهاتف قريبا منه.',
    'scan_again': 'إعادة البحث',
    'no_device_found': 'لم يتم العثور على أي جهاز سلامتك حاليا',
    'connect': 'اتصال',
    'permissions_needed': 'الأذونات المطلوبة',
    'permissions_desc':
        'يحتاج سلامتك إلى البلوتوث والموقع والرسائل القصيرة والمكالمات لتنبيه فرق الإسعاف.',
    'grant_permissions': 'السماح',

    // Vehicle
    'vehicle_type': 'نوع المركبة',
    'car': 'سيارة',
    'motorcycle': 'دراجة نارية',
    'car_desc': 'عتبة صدمة مرتفعة + كشف الانقلاب.',
    'moto_desc': 'عتبة صدمة أقل + كشف السقوط (الميلان).',
    'vehicle_sent': 'تم إرسال الإعداد إلى الجهاز',
    'vehicle_not_sent': 'تم حفظ الإعداد لكن لم يُرسل إلى الجهاز',

    // Wilaya / numbers
    'emergency_numbers': 'أرقام الطوارئ',
    'police': 'الشرطة',
    'civil_protection': 'الحماية المدنية',
    'numbers_not_configured': 'لم يقم المسؤول بعد بإعداد أرقام هذه الولاية.',
    'wilaya_auto_note': 'عند وقوع حادث، تُحدَّد الولاية انطلاقا من موقع GPS.',
    'wilaya_detected': 'الولاية المكتشفة',
    'wilaya_detected_desc': 'موقعك الحالي يشير إلى: {w}. هل تريد استعمال هذه الولاية؟',
    'use_this_wilaya': 'استعمال هذه الولاية',
    'detect_wilaya': 'الكشف عبر GPS',

    // Test mode
    'test_mode': 'وضع الاختبار',
    'test_mode_desc': 'يستبدل أرقام الشرطة والحماية المدنية برقم الاختبار.',
    'test_mode_active': 'وضع الاختبار — لن يتم الاتصال بأي مصلحة حقيقية',
    'test_mode_banner': 'وضع الاختبار مفعّل: لن يتم الاتصال أبدا بالشرطة أو الحماية المدنية.',
    'test_mode_replaces': 'في وضع الاختبار، يحل هذا الرقم محل الشرطة والحماية المدنية.',
    'test_mode_forced': 'وضع الاختبار مفروض من طرف المسؤول.',
    'test_mode_off_confirm':
        'إيقاف وضع الاختبار؟ سيتم الاتصال بالأرقام الحقيقية للشرطة والحماية المدنية عند التنبيه.',
    'test_mode_sent_note': 'وضع الاختبار: رقم الاختبار حل محل مصالح الطوارئ.',
    'test_number': 'رقم الاختبار',
    'test_number_hint': 'مثلا رقمك أو رقم أحد أعضاء الفريق',
    'test_number_missing': 'لم يتم تحديد رقم اختبار: تم تنبيه جهات اتصالك فقط.',
    'test_tools': 'أدوات الاختبار',
    'simulate_accident': 'محاكاة حادث',
    'device_test_alert': 'تنبيه تجريبي من الجهاز',
    'force_test_mode': 'فرض وضع الاختبار على الجميع',
    'force_test_mode_desc': 'ما دام مفعّلا، لا يمكن لأي مستخدم الاتصال بالمصالح الحقيقية.',
    'default_test_number': 'رقم الاختبار الافتراضي',
    'default_test_number_desc': 'يُستعمل إذا لم يحدد المستخدم رقم اختبار خاصا به.',

    // Alarm
    'accident_detected': 'تم كشف حادث',
    'alert_in_seconds': 'سيتم تنبيه الإسعاف وجهات اتصالك بعد {s} ثانية',
    'im_ok_cancel': 'أنا بخير – إلغاء',
    'send_now': 'إرسال الآن',
    'sending_alert': 'جار إرسال التنبيه…',
    'alert_sent': 'تم إرسال التنبيه',
    'alert_failed': 'تعذر إرسال التنبيه',
    'alert_cancelled': 'تم إلغاء التنبيه',
    'alert_cancelled_desc': 'سعداء أنك بخير. تم تسجيل الحدث.',
    'sms_sent_to': 'رسالة أُرسلت إلى',
    'sms_failed': 'فشل الإرسال',
    'called': 'مكالمة إلى',
    'location_included': 'تم إرفاق موقع GPS (رابط Google Maps)',
    'location_unavailable': 'موقع GPS غير متوفر',
    'alert_saved': 'تم حفظ التنبيه',
    'alert_not_saved': 'لم يتم حفظ التنبيه (لا يوجد إنترنت)',
    'trigger': 'سبب التنبيه',
    'trigger_impact': 'صدمة قوية',
    'trigger_fall': 'سقوط (الدراجة على جانبها)',
    'trigger_rollover': 'انقلاب',
    'trigger_test': 'اختبار من الجهاز',
    'trigger_simulation': 'محاكاة',
    'peak_g': 'أقصى صدمة',
    'tilt': 'الميلان',

    // Contacts
    'emergency_contacts': 'جهات الاتصال للطوارئ',
    'contacts_desc': 'سيتلقى هؤلاء الأشخاص رسالة بموقعك عند وقوع حادث.',
    'add_contact': 'إضافة',
    'edit_contact': 'تعديل جهة الاتصال',
    'contact_name': 'الاسم',
    'relation': 'صلة القرابة',
    'relation_hint': 'مثلا أب، أخت، صديق',
    'no_contacts': 'لا توجد جهات اتصال للطوارئ. أضف شخصا واحدا على الأقل.',
    'delete_contact_confirm': 'حذف جهة الاتصال هذه؟',

    // History / details
    'my_alerts': 'تنبيهاتي',
    'no_alerts': 'لا توجد تنبيهات',
    'alert_details': 'تفاصيل التنبيه',
    'summary': 'ملخص',
    'date': 'التاريخ',
    'response_time': 'مدة التدخل',
    'open_in_maps': 'فتح في Google Maps',
    'mark_as': 'تحديد كـ',
    'status': 'الحالة',
    'status_cancelled': 'ملغى',
    'status_sent': 'مُرسل',
    'status_received': 'مُستلم',
    'status_dispatched': 'تم إرسال الفريق',
    'status_arrived': 'وصل إلى المكان',
    'status_resolved': 'تمت المعالجة',

    // Map
    'hotspots_legend': 'أماكن الحوادث',

    // Settings
    'profile': 'الملف الشخصي',
    'language': 'اللغة',

    // Admin
    'admin_dashboard': 'لوحة القيادة',
    'admin_alerts': 'التنبيهات',
    'admin_map': 'الخريطة',
    'admin_users': 'المستخدمون',
    'admin_wilayas': 'الأرقام',
    'users': 'المستخدمون',
    'devices': 'الأجهزة',
    'alerts': 'التنبيهات',
    'total': 'المجموع',
    'new_7d': 'جدد (7 أيام)',
    'new_30d': 'جدد (30 يوما)',
    'disabled': 'معطل',
    'active': 'نشط',
    'registered': 'مسجلة',
    'online': 'متصلة',
    'today': 'اليوم',
    'last_7d': 'آخر 7 أيام',
    'last_30d': 'آخر 30 يوما',
    'include_test_alerts': 'تضمين تنبيهات الاختبار',
    'cancelled_by_user': 'ألغاها المستخدم',
    'alerts_over_time': 'التنبيهات عبر الزمن',
    'alerts_by_wilaya': 'التنبيهات حسب الولاية',
    'response_times': 'متوسط مدة التدخل',
    'response_time_desc': 'المدة بين التنبيه ووصول الفريق إلى المكان.',
    'no_response_data': 'لا توجد بيانات تدخل بعد',
    'filter_date': 'التاريخ',
    'clear_filters': 'مسح',
    'search_users': 'بحث (الاسم، المستخدم، الهاتف، الولاية)',
    'no_users': 'لا يوجد مستخدمون',
    'role': 'الدور',
    'role_admin': 'مسؤول',
    'role_user': 'مستخدم',
    'created_at': 'تاريخ التسجيل',
    'enable_user_confirm': 'إعادة تفعيل هذا الحساب؟',
    'disable_user_confirm': 'تعطيل هذا الحساب؟ لن يتمكن صاحبه من تسجيل الدخول.',
    'search_wilaya': 'البحث عن ولاية',
    'wilayas_missing': 'ولايات بدون أرقام',
    'seed_defaults': 'إنشاء الأرقام الافتراضية (17 / 14)',
    'seed_confirm':
        'إنشاء الولايات الناقصة بالأرقام الوطنية (الشرطة 17، الحماية المدنية 14)؟ يمكنك تعديلها لاحقا.',
    'seed_done': 'تم إنشاء الولايات',
    'not_configured': 'غير مُعد',
    'numbers_sms_note':
        'الأرقام القصيرة (17، 14) تستقبل المكالمات لكن لا تستقبل الرسائل القصيرة. يُفضل خط مباشر لاستقبال الرسالة.',
    'black_point_alert': 'نقطة سوداء - منطقة حوادث',
    'black_point_warning': 'انتبه! أنت قريب من موقع وقع فيه حادث من قبل. يُرجى تخفيف السرعة والحذر!',
    'listen_voice_alert': 'استمع إلى التنبيه الصوتي',
    'user_location': 'الموقع الجغرافي المباشر',
    'safe_zone': 'منطقة آمنة',
    'black_point_simulate': 'محاكاة الاقتراب من نقطة سوداء',
    'safe_zone_simulate': 'منطقة آمنة',
    'trik_sure': 'طريق آمن (مسار بلا حوادث)',
    'trik_sure_desc': 'البحث عن مسار يتفادى أماكن الحوادث السابقة',
    'safe_route_rec': 'المسار الآمن (موصى به)',
    'risky_route': 'المسار العادي (به حوادث)',
    'start_safe_nav': 'بدء الإرشاد الصوتي الآمن',
  };

  /// Used by tests to check that both languages define the same keys.
  static Set<String> get frKeys => _fr.keys.toSet();
  static Set<String> get arKeys => _ar.keys.toSet();
}
