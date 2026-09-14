import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_store.dart';
import '../data/models.dart';

class PosScope extends InheritedNotifier<PosStore> {
  const PosScope({super.key, required PosStore store, required super.child})
    : super(notifier: store);
  static PosStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PosScope>()!.notifier!;
}

extension PosContext on BuildContext {
  PosStore get store => PosScope.of(this);
  String tr(String key) => translate(store.language, key);
}

String translate(String language, String key) {
  final values = translations[key];
  if (values == null) return key;
  return values[switch (language) {
    'ar' => 1,
    'ku' => 2,
    _ => 0,
  }];
}

String money(int value, String currency) => currency == 'USD'
    ? '\$${NumberFormat('#,##0.00', 'en').format(value / 100)} USD'
    : '${NumberFormat(value % 100 == 0 ? '#,##0' : '#,##0.00', 'en').format(value / 100)} $currency';

String? secondaryMoney(int value, StoreSettings settings) {
  final amount = settings.secondaryAmount(value);
  return amount == null
      ? null
      : '≈ ${money(amount, settings.secondaryCurrency!)}';
}

String displayExchangeRate(StoreSettings settings) =>
    '1 USD = ${money(settings.usdToIqdRate!, 'IQD')}';
int? parseMoney(String value) {
  final normalized = value.trim().replaceAll('٫', '.').replaceAllMapped(
    RegExp('[٠-٩۰-۹]'),
    (m) {
      final c = m[0]!.codeUnitAt(0);
      return '${c >= 0x6f0 ? c - 0x6f0 : c - 0x660}';
    },
  );
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

String dateLabel(DateTime date) =>
    DateFormat('dd MMM yyyy · HH:mm').format(date);

// Kurdish uses the Badini dialect in Arabic script (ku-Arab), not Sorani.
// Keep every application string in the same catalog so missing translations are testable.
final Map<String, List<String>> translations = {
  "extraPermissions": [
    "Extra permissions",
    "صلاحيات إضافية",
    "دەستهەلاتێن زێدە",
  ],
  "extraPermissionsHint": [
    "Optional access for this cashier in their assigned market. Leave all unchecked for standard cashier access.",
    "صلاحيات اختيارية لهذا البائع ضمن متجره. اتركها دون تحديد لصلاحيات البائع الأساسية.",
    "دەستهەلاتێن هەلبژارتی بۆ ڤی فرۆشیاری ل مارکێتا وی. بۆ دەستهەلاتێن بنەڕەتی هەمیان ڤالا بهێلە.",
  ],
  "permission_viewReports": [
    "View all sales and profit reports",
    "عرض كل المبيعات وتقارير الأرباح",
    "بینینا هەمی فرۆتن و راپۆرتێن قازانجی",
  ],
  "permission_viewReports_hint": [
    "Includes staff reports, all market receipts and CSV export.",
    "يشمل تقارير الموظفين وكل إيصالات المتجر وتصدير CSV.",
    "راپۆرتێن کارمەندان و هەمی پسوولێن مارکێتی و دەرئێخستنا CSV.",
  ],
  "permission_manageCatalog": [
    "Manage inventory and categories",
    "إدارة المخزون والأقسام",
    "بەڕێڤەبرنا کۆگەه و بەشان",
  ],
  "permission_manageCatalog_hint": [
    "Add, edit and delete products/categories, prices, costs, stock, photos and icons.",
    "إضافة وتعديل وحذف المنتجات والأقسام والأسعار والتكاليف والمخزون والصور والرموز.",
    "زێدەکرن و گوهۆڕین و ژێبرنا کەل و پەل و بەش و نرخ و تێچوون و کۆگەه و وێنە و هێمایان.",
  ],
  "permission_applyDiscounts": [
    "Apply discounts",
    "تطبيق التخفيضات",
    "دانانا داشکاندنان",
  ],
  "permission_applyDiscounts_hint": [
    "Allow discounts during checkout.",
    "السماح بالتخفيضات أثناء البيع.",
    "دەستهەلاتا دانانا داشکاندنان دەمێ فرۆتنێ.",
  ],
  "permission_voidSales": [
    "Void sales and restock",
    "إلغاء المبيعات وإعادة المخزون",
    "هەلوەشاندنا فرۆتنێ و ڤەگەڕاندنا کۆگەهێ",
  ],
  "permission_voidSales_hint": [
    "Void visible receipts. Enable reports to include other staff’s sales.",
    "إلغاء الإيصالات المتاحة. فعّل التقارير لتشمل مبيعات الموظفين الآخرين.",
    "هەلوەشاندنا پسوولێن دیار. راپۆرتان چالاک بکە بۆ فرۆتنێن کارمەندێن دی.",
  ],

  "adminMarketHint": [
    "This admin will sign in to the selected market. Create markets from the Markets page.",
    "سيدخل هذا المدير إلى المتجر المحدد. يمكنك إنشاء المتاجر من صفحة المتاجر.",
    "ئەڤ بەڕێڤەبەرە دێ بچیتە مارکێتا هەلبژارتی. ل پەڕا مارکێتان مارکێتەکێ دروست بکە.",
  ],
  "adminBranding": ["Market logo & background", "شعار المتجر والخلفية", "لۆگۆ و پاشبنەمایێ مارکێتێ"],
  "adminBrandingHint": [
    "Optional. These images belong to the selected market. Its welcome screen uses them when a team member enters their username. The logo also appears inside the market and on receipts.",
    "اختياري. تخص هذه الصور المتجر المحدد وتظهر في شاشة الترحيب عند إدخال اسم مستخدم أحد موظفيه. يظهر الشعار أيضًا داخل المتجر وعلى الإيصالات.",
    "هەلبژارتییە. ئەڤ وێنە بۆ مارکێتا هەلبژارتی نە. دەمێ کارمەند ناڤێ بەکارهێنەری بنڤیسیت ل پەڕا بخێرهاتنێ دیار دبن. لۆگۆ د ناڤ مارکێتێ و ل سەر پسوولان ژی دیار دبیت.",
  ],
  "background": ["Background", "الخلفية", "پاشبنەما"],
  "logo": ["Logo", "الشعار", "لۆگۆ"],
  "uploadBackground": ["Upload background", "رفع خلفية", "بارکرنا پاشبنەمایی"],
  "removeBackground": ["Remove background", "إزالة الخلفية", "ژێبرنا پاشبنەمایی"],
  "categories": ["Categories", "الأقسام", "بەش"],
  "categoriesSubtitle": [
    "Organize items with names, photos and icons.",
    "نظّم المنتجات بالأسماء والصور والرموز.",
    "کەل و پەلان ب ناڤ و وێنە و هێمایان رێک بخە.",
  ],
  "addCategory": ["Add category", "إضافة قسم", "بەشەکێ زێدە بکە"],
  "editCategory": ["Edit category", "تعديل القسم", "بەشی بگوهۆڕە"],
  "categoryName": ["Category name", "اسم القسم", "ناڤێ بەشی"],
  "customCategoryIcon": [
    "Custom category icon",
    "رمز قسم مخصص",
    "هێمایێ تایبەت یێ بەشی",
  ],
  "customCategoryIconHint": [
    "Type or paste one emoji. Remove the category photo to display the icon.",
    "اكتب أو الصق رمزًا تعبيريًا واحدًا. احذف صورة القسم لإظهار الرمز.",
    "ئێک ئیمۆجی بنڤیسە یان دابنێ. وێنەیێ بەشی ژێببە دا هێما دیار ببیت.",
  ],
  "useCategoryIcon": [
    "Use category icon",
    "استخدام رمز القسم",
    "هێمایێ بەشی بکار بینە",
  ],
  "useCategoryIconHint": [
    "Turn off to choose this product’s own photo or icon.",
    "أوقف هذا الخيار لاختيار صورة أو رمز خاص بالمنتج.",
    "ڤێ هەلبژاردنێ بگرە دا وێنە یان هێمایێ تایبەت یێ بەرهەمی هەلبژێری.",
  ],
  "customProductIcon": [
    "Custom product icon",
    "رمز منتج مخصص",
    "هێمایێ تایبەت یێ بەرهەمی",
  ],
  "aboutUs": ["About Us", "من نحن", "دەربارەی مە"],
  "aboutAppName": ["App name", "اسم التطبيق", "ناڤێ ئەپێ"],
  "aboutPurpose": ["What we do", "ماذا نقدم", "ئەو کارێ ئەم دکەین"],
  "aboutPurposeValue": [
    "Supermarket checkout, inventory, staff access and sales reporting.",
    "نقاط بيع السوبرماركت والمخزون وصلاحيات الموظفين وتقارير المبيعات.",
    "فرۆتنا مارکێتێ، کۆگە، دەستهەلاتێن کارمەندان و ڕاپۆرتێن فرۆتنێ.",
  ],
  "aboutStorage": ["Data storage", "تخزين البيانات", "پاشەکەوتکرنا داتایان"],
  "aboutStorageValue": [
    "Offline on this device. Each device operates independently.",
    "محليًا على هذا الجهاز دون اتصال. يعمل كل جهاز بشكل مستقل.",
    "بێ ئینتەرنێت ل ڤی ئامێری. هەر ئامێرەک ب سەربەخۆیی کار دکەت.",
  ],
  "panelSettings": ["Panel settings", "إعدادات اللوحة", "ڕێکخستنێن پانێلێ"],
  "panelSettingsHint": [
    "Language and app updates for this device.",
    "اللغة وتحديثات التطبيق لهذا الجهاز.",
    "زمان و نویکرنێن ئەپێ بۆ ڤی ئامێری.",
  ],
  "appUpdates": ["App updates", "تحديثات التطبيق", "نویکرنێن ئەپێ"],
  "backups": ["Backups", "النسخ الاحتياطية", "کۆپیێن پاشەکەفتێ"],
  "createBackup": [
    "Create backup",
    "إنشاء نسخة احتياطية",
    "کۆپیا پاشەکەفتێ دروست بکە",
  ],
  "restoreBackup": [
    "Restore backup",
    "استعادة نسخة احتياطية",
    "کۆپیا پاشەکەفتێ بگەڕینەڤە",
  ],
  "backupScopeHint": [
    "Back up all markets on this device, including products, sales, staff accounts, logos and settings. Keep backup files private.",
    "انسخ جميع المتاجر على هذا الجهاز، بما فيها المنتجات والمبيعات وحسابات الموظفين والشعارات والإعدادات. احتفظ بملفات النسخ بشكل خاص.",
    "کۆپیا هەمی مارکێتێن ڤی ئامێری بگرە، ب بەرهەم و فرۆتن و هەژمارێن کارمەندان و لوگۆ و ڕێکخستنان ڤە. فایلێن کۆپیێ تایبەت بهێلە.",
  ],
  "restoreBackupHint": [
    "This replaces ALL markets, sales, inventory, accounts and settings on this device with the backup. Save a current backup first. Unsaved work will be lost and you will be signed out. Sign in using an account from the restored backup.",
    "ستستبدل النسخة جميع المتاجر والمبيعات والمخزون والحسابات والإعدادات على هذا الجهاز. احفظ نسخة حالية أولًا. ستفقد العمل غير المحفوظ وسيتم تسجيل خروجك. سجّل الدخول بحساب موجود في النسخة المستعادة.",
    "ئەڤ کۆپیە دێ هەمی مارکێت و فرۆتن و کۆگە و هەژمار و ڕێکخستنێن ڤی ئامێری بگوهۆڕیت. بەری وێ کۆپیەکا نوکە پاشەکەوت بکە. کارێ نە پاراستی دێ ژ دەست بچیت و دێ دەربکەڤی. ب هەژمارەکێ ناڤ کۆپیێ بچۆ ژوورڤە.",
  ],
  "backupSaved": [
    "Backup saved.",
    "تم حفظ النسخة الاحتياطية.",
    "کۆپیا پاشەکەفتێ هاتە پاراستن.",
  ],
  "backupDownloadStarted": [
    "Backup download started. Check your browser's downloads.",
    "بدأ تنزيل النسخة الاحتياطية. تحقق من تنزيلات المتصفح.",
    "داگرتنا کۆپیێ دەست پێ کر. داگرتنێن وێبگەڕێ بپشکنە.",
  ],
  "backupRestored": [
    "Backup restored",
    "تمت استعادة النسخة",
    "کۆپی هاتە گەڕاندنەڤە",
  ],
  "invalidBackup": [
    "This is not a valid Bazaar_POS backup. No data was replaced.",
    "هذا الملف ليس نسخة احتياطية صالحة لـ Bazaar_POS. لم يتم استبدال أي بيانات.",
    "ئەڤ فایلە کۆپیەکا دروست یا Bazaar_POS نینە. چ داتا نەهاتە گوهۆڕین.",
  ],
  "backupTooLarge": [
    "Backups must be smaller than 100 MB.",
    "يجب أن يكون حجم النسخة الاحتياطية أقل من 100 ميغابايت.",
    "پێدڤیە قەبارەیا کۆپیێ ژ ١٠٠ مێگابایت کێمتر بیت.",
  ],
  "backupActionFailed": [
    "The backup action could not finish. Check storage or your internet connection, then try again.",
    "تعذر إكمال العملية. تحقق من مساحة التخزين أو اتصال الإنترنت وحاول مجددًا.",
    "کارێ کۆپیێ نەهاتە تمامکرن. بۆشایا پاشەکەوتکرنێ یان ئینتەرنێتێ بپشکنە و دوبارە تاقی بکە.",
  ],
  "googleDrive": ["Google Drive", "Google Drive", "Google Drive"],
  "driveBackupHint": [
    "Connect your Google account to store backups in Bazaar_POS's private Drive folder. Restore recent backups here. Reconnect when the sign-in session expires.",
    "اربط حساب Google لحفظ النسخ في مجلد التطبيق الخاص على Drive. استعد النسخ الحديثة من هنا. أعد الاتصال عند انتهاء جلسة تسجيل الدخول.",
    "هەژمارا Google گرێ بدە دا کۆپیان د فولدەرا تایبەت یا ئەپێ ل Drive پاشەکەوت بکەی. کۆپیێن نوی ژ ڤێرە بگەڕینەڤە. دەمێ دانیشتن ب دوماهیک هات دوبارە گرێ بدە.",
  ],
  "driveNeedsSetup": [
    "Google Drive sign-in needs to be configured by the app owner. Local backups are available now.",
    "يحتاج مالك التطبيق إلى إعداد تسجيل الدخول إلى Google Drive. النسخ المحلية متاحة الآن.",
    "خاوەنێ ئەپێ پێدڤیە چوونا ژوورڤە یا Google Drive ڕێک بخەت. کۆپیێن ناڤ ئامێری نوکە بەردەستن.",
  ],
  "driveUnsupported": [
    "Direct Drive sign-in is available on desktop and web. On this device, create a local backup and upload it with Google Drive.",
    "الاتصال المباشر بـ Drive متاح على الكمبيوتر والويب. على هذا الجهاز، أنشئ نسخة محلية وارفعها باستخدام Google Drive.",
    "چوونا ڕاستەوخۆ یا Drive ل کۆمپیوتەر و وێبێ بەردەستە. ل ڤی ئامێری کۆپیەکا ناڤ ئامێری دروست بکە و ب Google Drive بار بکە.",
  ],
  "connectGoogleDrive": [
    "Connect Google account",
    "ربط حساب Google",
    "هەژمارا Google گرێ بدە",
  ],
  "prepareGoogleDrive": [
    "Prepare Google sign-in",
    "تهيئة تسجيل الدخول إلى Google",
    "چوونا Google ئامادە بکە",
  ],
  "connectedGoogleAccount": [
    "Connected account",
    "الحساب المرتبط",
    "هەژمارا گرێدای",
  ],
  "disconnectGoogleDrive": ["Disconnect", "قطع الاتصال", "پەیوەندیێ ببڕە"],
  "backupToDrive": [
    "Back up to Google Drive",
    "نسخ احتياطي إلى Google Drive",
    "کۆپیێ ل Google Drive پاشەکەوت بکە",
  ],
  "restoreFromDrive": [
    "Restore from Google Drive",
    "استعادة من Google Drive",
    "ژ Google Drive بگەڕینەڤە",
  ],
  "driveBackups": [
    "Recent Drive backups",
    "نسخ Drive الحديثة",
    "کۆپیێن نوی یێن Drive",
  ],
  "driveBackupSaved": [
    "Backup saved to Google Drive.",
    "تم حفظ النسخة على Google Drive.",
    "کۆپی ل Google Drive هاتە پاراستن.",
  ],
  "noDriveBackups": [
    "No backups found for this Google account.",
    "لم يتم العثور على نسخ لهذا الحساب.",
    "چ کۆپی بۆ ڤێ هەژمارا Google نەهاتن دیتن.",
  ],
  "driveSignInCancelled": [
    "Google sign-in was cancelled or timed out.",
    "تم إلغاء تسجيل الدخول أو انتهت مهلته.",
    "چوونا Google هاتە بەتاڵکرن یان دەمێ وێ ب دوماهیک هات.",
  ],
  "driveOpenFailed": [
    "Could not open the browser for Google sign-in.",
    "تعذر فتح المتصفح لتسجيل الدخول إلى Google.",
    "وێبگەڕ بۆ چوونا Google نەهاتە ڤەکرن.",
  ],
  "driveConnectionFailed": [
    "Could not connect to Google. Check your connection and sign-in setup.",
    "تعذر الاتصال بـ Google. تحقق من الاتصال وإعداد تسجيل الدخول.",
    "پەیوەندی ب Google نەسەرکەفت. پەیوەندی و ڕێکخستنێن چوونێ بپشکنە.",
  ],
  "drivePermissionMissing": [
    "Google Drive did not allow this request. Check backup permission, API setup and available Drive space.",
    "لم يسمح Google Drive بهذا الطلب. تحقق من إذن النسخ وإعداد API والمساحة المتاحة.",
    "Google Drive ڕێک نەدا ڤی داخوازێ. دەستهەلات و ڕێکخستن و بۆشایا Drive بپشکنە.",
  ],
  "driveSessionExpired": [
    "Your Google session expired. Connect your account again.",
    "انتهت جلسة Google. اربط حسابك مجددًا.",
    "دانیشتنا Google ب دوماهیک هات. هەژمارێ دوبارە گرێ بدە.",
  ],
  "driveRequestFailed": [
    "Google Drive could not complete the request. Try again later.",
    "تعذر إكمال الطلب على Google Drive. حاول لاحقًا.",
    "Google Drive نەشیا داخوازێ تمام بکەت. پاشی دوبارە تاقی بکە.",
  ],
  "driveRevokeFailed": [
    "Disconnected on this device. Google could not revoke access; you can remove the app in your Google account permissions.",
    "تم قطع الاتصال على هذا الجهاز. تعذر إلغاء إذن Google؛ يمكنك إزالة التطبيق من أذونات حساب Google.",
    "پەیوەندی ل ڤی ئامێری هاتە بڕین. Google نەشیا دەستهەلاتێ بسڕیت؛ دشێی ئەپێ ژ دەستهەلاتێن هەژمارا Google بسڕی.",
  ],
  "installedVersion": [
    "Installed version",
    "الإصدار المثبت",
    "وەشانێ دامەزراندی",
  ],
  "appBuild": ["Build", "البناء", "بنیات"],
  "updateSource": ["Update source", "مصدر التحديث", "ژێدەرێ نویکرنێ"],
  "checkGitHubUpdates": [
    "Check GitHub for updates",
    "التحقق من تحديثات GitHub",
    "ل نویکرنان ل GitHub بگەڕە",
  ],
  "downloadUpdate": ["Download update", "تنزيل التحديث", "نویکرنێ دابگرە"],
  "installUpdate": ["Update now", "التحديث الآن", "نوکە نوی بکە"],
  "directUpdateHint": [
    "Download and install updates here. The app restarts or reloads when the update is ready.",
    "نزّل التحديثات وثبّتها من هنا. يُعاد تشغيل التطبيق أو تحميله عندما يصبح التحديث جاهزًا.",
    "نویکرنان ل ڤێرە دابگرە و دابمەزرینە. دەمێ نویکرن ئامادە بیت ئەپ دوبارە ڤەدبیت.",
  ],
  "installUpdateConfirm": [
    "Finish the current sale and save your edits before updating. The app will restart or reload. Saved market data stays on this device.",
    "أكمل عملية البيع واحفظ تعديلاتك قبل التحديث. سيُعاد تشغيل التطبيق أو تحميله. تبقى بيانات السوق المحفوظة على هذا الجهاز.",
    "بەری نویکرنێ فرۆتنا نوکە تمام بکە و گوهۆڕینان پاشەکەوت بکە. ئەپ دوبارە ڤەدبیت. داتایێن مارکێتێ ل ڤی ئامێری دمینن.",
  ],
  "updateDownloading": ["Downloading update…", "جارٍ تنزيل التحديث…", "نویکرن دهێتە داگرتن…"],
  "updateVerifying": ["Verifying update…", "جارٍ التحقق من التحديث…", "نویکرن دهێتە پشکنین…"],
  "updateInstalling": ["Installing update…", "جارٍ تثبيت التحديث…", "نویکرن دهێتە دامەزراندن…"],
  "updateRestarting": ["Update ready. Reloading…", "التحديث جاهز. جارٍ إعادة التحميل…", "نویکرن ئامادەیە. دوبارە بار دبیت…"],
  "updateInstallerOpened": [
    "Follow the update window to download, install and restart the app.",
    "اتبع نافذة التحديث لتنزيل التحديث وتثبيته وإعادة تشغيل التطبيق.",
    "د پەنجەرەیا نویکرنێ دا نویکرنێ دابگرە و دابمەزرینە و ئەپێ دوبارە ڤەکە.",
  ],
  "updateInstallerUnavailable": [
    "Direct installation is unavailable in this build. Download the latest installer to enable it.",
    "التثبيت المباشر غير متاح في هذه النسخة. نزّل أحدث ملف تثبيت لتفعيله.",
    "دامەزراندنا ڕاستەوخۆ د ڤی وەشانی دا بەردەست نینە. نووترین فایلێ دامەزراندنێ دابگرە.",
  ],
  "updateInstallFailed": [
    "The update could not finish. Check your connection and try again. You can also check this server and reload an update that has finished installing.",
    "تعذر إكمال التحديث. تحقق من الاتصال وحاول مجددًا. يمكنك أيضًا التحقق من هذا الخادم وتحميل تحديث اكتمل تثبيته.",
    "نویکرن تمام نەبوو. پەیوەندیێ بپشکنە و دوبارە تاقی بکە. دشی ڤی سێرڤەری بپشکنی و نویکرنا دامەزراندی بار بکی.",
  ],
  "updateArchiveInvalid": [
    "This update package could not be verified. The current app was kept.",
    "تعذر التحقق من حزمة التحديث. تم الاحتفاظ بالتطبيق الحالي.",
    "پشتڕاستکرنا فایلێ نویکرنێ نەسەرکەفت. ئەپا نوکە هاتە پاراستن.",
  ],
  "updateDigestMissing": [
    "This release has no download checksum. The publisher must upload a new web package to GitHub.",
    "لا يحتوي الإصدار على بصمة تحقق للتنزيل. يجب على الناشر رفع حزمة ويب جديدة إلى GitHub.",
    "نیشانا پشکنینا داگرتنێ د ڤی وەشانی دا نینە. بەلاڤکەر پێدڤیە فایلەکێ نوی یێ وێبێ ل GitHub بار بکەت.",
  ],
  "updateNotNewer": [
    "This server already has this version or a newer one. Check this server to reload it.",
    "يحتوي هذا الخادم على هذا الإصدار أو إصدار أحدث. تحقق من هذا الخادم لإعادة تحميله.",
    "ڤی سێرڤەری ئەڤ وەشان یان وەشانەکا نویتر هەیە. ڤی سێرڤەری بپشکنە دا بار بکی.",
  ],
  "updateReleaseChanged": [
    "The release changed. Check GitHub for updates again before installing.",
    "تغيّر الإصدار. تحقق من تحديثات GitHub مجددًا قبل التثبيت.",
    "وەشان گوهۆڕی. بەری دامەزراندنێ دوبارە ل نویکرنان ل GitHub بگەڕە.",
  ],
  "updateBusy": ["An update is already in progress.", "يوجد تحديث قيد التنفيذ بالفعل.", "نویکرنەک ل کارە."],
  "githubReleases": ["GitHub releases", "إصدارات GitHub", "وەشانێن GitHub"],
  "latestVersion": ["Latest version", "أحدث إصدار", "نووترین وەشان"],
  "releaseNotes": ["What's new", "ما الجديد", "چی نوی یە"],
  "githubNativeUpdateHint": [
    "Download the latest installer from GitHub, then open it to update this app. Finish current sales and save edits before installing.",
    "نزّل أحدث ملف تثبيت من GitHub ثم افتحه لتحديث التطبيق. أكمل المبيعات الحالية واحفظ تعديلاتك قبل التثبيت.",
    "نووترین فایلێ دامەزراندنێ ژ GitHub دابگرە و ڤەکە دا ئەپێ نوی بکەی. بەری دامەزراندنێ فرۆتنان تمام بکە و گوهۆڕینان پاشەکەوت بکە.",
  ],
  "githubWebUpdateHint": [
    "Get the latest web update from GitHub. The store owner must install it on this server before you can reload it below. Keep the same browser address to retain saved market data.",
    "احصل على أحدث تحديث للويب من GitHub. يجب على صاحب المتجر تثبيته على هذا الخادم قبل إعادة تحميله أدناه. استخدم عنوان المتصفح نفسه للاحتفاظ ببيانات السوق المحفوظة.",
    "نووترین نویکرنا وێبێ ژ GitHub دابگرە. خاوەنێ مارکێتێ پێدڤیە ل ڤی سێرڤەری دامەزرینیت، پاشی ل خوارێ دوبارە بار بکە. هەمان ناڤنیشانێ وێبێ بکار بینە دا داتایێن پاشەکەوتکری بمینن.",
  ],
  "githubUpdateAvailable": [
    "A newer version is available on GitHub.",
    "يتوفر إصدار أحدث على GitHub.",
    "وەشانەکا نوی ل GitHub بەردەستە.",
  ],
  "githubUpToDate": [
    "Your app is up to date with the latest GitHub release.",
    "تطبيقك محدّث إلى أحدث إصدار على GitHub.",
    "ئەپا تە ب نووترین وەشانێ GitHub هاتیە نویکرن.",
  ],
  "noGitHubRelease": [
    "No public release is available. The repository may be private or may not have a published release yet.",
    "لا يتوفر إصدار عام. قد يكون المستودع خاصًا أو لم يُنشر فيه إصدار بعد.",
    "وەشانەکا گشتی بەردەست نینە. ڕەنگە کۆگە تایبەت بیت یان هێشتا وەشانەک نەهاتیە بەلاڤکرن.",
  ],
  "githubRateLimited": [
    "GitHub could not allow this check. Wait a few minutes and try again, or open GitHub releases.",
    "لم يسمح GitHub بهذا التحقق. انتظر بضع دقائق وحاول مجددًا أو افتح إصدارات GitHub.",
    "GitHub ڕێک نەدا ڤێ گەڕیانێ. چەند خولەکان چاڤەڕێ بکە و دوبارە تاقی بکە یان وەشانێن GitHub ڤەکە.",
  ],
  "githubCheckFailed": [
    "Could not reach GitHub. Check your internet connection and try again.",
    "تعذر الاتصال بـ GitHub. تحقق من اتصال الإنترنت وحاول مجددًا.",
    "پەیوەندی ب GitHub نەسەرکەفت. پەیوەندیا ئینتەرنێتێ بپشکنە و دوبارە تاقی بکە.",
  ],
  "invalidGitHubRelease": [
    "This release has invalid update information. Open GitHub releases for details.",
    "يحتوي هذا الإصدار على معلومات تحديث غير صالحة. افتح إصدارات GitHub للتفاصيل.",
    "پێزانینێن نویکرنا ڤی وەشانی نەدروستن. بۆ وردەکاریان وەشانێن GitHub ڤەکە.",
  ],
  "invalidGitHubRepository": [
    "The update repository is not configured correctly.",
    "لم تتم تهيئة مستودع التحديث بشكل صحيح.",
    "کۆگەها نویکرنێ ب دروستی نەهاتیە ڕێکخستن.",
  ],
  "installedVersionFailed": [
    "Could not read the installed version. Try checking again or restart the app.",
    "تعذرت قراءة الإصدار المثبت. حاول التحقق مجددًا أو أعد تشغيل التطبيق.",
    "خواندنا وەشانێ دامەزراندی نەسەرکەفت. دوبارە بپشکنە یان ئەپێ دوبارە ڤەکە.",
  ],
  "githubNoInstallerHint": [
    "This release has no direct download for this device. Open GitHub releases for installation instructions.",
    "لا يحتوي هذا الإصدار على تنزيل مباشر لهذا الجهاز. افتح إصدارات GitHub للاطلاع على تعليمات التثبيت.",
    "ئەڤ وەشانە داگرتنا ڕاستەوخۆ بۆ ڤی ئامێری نینە. بۆ ڕێنمایێن دامەزراندنێ وەشانێن GitHub ڤەکە.",
  ],
  "githubOpenFailed": [
    "Could not open the browser. Allow pop-ups or copy this link into your browser.",
    "تعذر فتح المتصفح. اسمح بالنوافذ المنبثقة أو انسخ هذا الرابط إلى متصفحك.",
    "ڤەکرنا وێبگەڕێ نەسەرکەفت. ڕێکێ بدە پەنجەرەیێن نوی یان ڤی بەستەری کۆپی بکە د وێبگەڕێ خۆ دا.",
  ],
  "checkWebUpdates": [
    "Check this server",
    "التحقق من هذا الخادم",
    "ڤی سێرڤەری بپشکنە",
  ],
  "webUpdateHint": [
    "Check this server for a newer app build. Saved market data stays on this device.",
    "تحقق من وجود نسخة أحدث على هذا الخادم. تبقى بيانات السوق المحفوظة على هذا الجهاز.",
    "ل ڤی سێرڤەری ل وەشانەکا نوی بگەڕە. داتایێن مارکێتێ ل ڤی ئامێری دمینن.",
  ],
  "checkUpdates": [
    "Check for updates",
    "التحقق من التحديثات",
    "ل نویکرنان بگەڕە",
  ],
  "checkingUpdates": ["Checking…", "جارٍ التحقق…", "ل گەڕیانێیە…"],
  "updateAvailable": [
    "A newer build is available.",
    "تتوفر نسخة أحدث.",
    "وەشانەکا نوی بەردەستە.",
  ],
  "appUpToDate": [
    "You have the latest build on this server.",
    "لديك أحدث نسخة على هذا الخادم.",
    "نووترین وەشانێ ڤی سێرڤەری ل دەف تەیە.",
  ],
  "updateCheckFailed": [
    "Could not check for updates. Make sure the app server is running, then try again.",
    "تعذر التحقق من التحديثات. تأكد من تشغيل خادم التطبيق ثم حاول مجددًا.",
    "گەڕیان بۆ نویکرنان نەسەرکەفت. پشتڕاست بە کو سێرڤەر کار دکەت و دوبارە تاقی بکە.",
  ],
  "loadUpdate": ["Load update", "تحميل التحديث", "نویکرنێ بار بکە"],
  "updateReloadHint": [
    "The app will reload and you may need to sign in again. Finish any current sale and save your edits first. Unsaved work will be lost; saved data stays on this device.",
    "سيُعاد تحميل التطبيق وقد تحتاج لتسجيل الدخول مجددًا. أكمل البيع الحالي واحفظ تعديلاتك أولًا. ستفقد العمل غير المحفوظ، وتبقى البيانات المحفوظة على هذا الجهاز.",
    "ئەڤ ئەپە دێ دوبارە بار ببیت و ڕەنگە پێدڤی ب چوونا ژوورڤە بیت. فرۆتنا نوکە تمام بکە و گوهۆڕینان پاشەکەوت بکە. کارێ نە پاشەکەوتکری دێ ژ دەست بچیت.",
  ],
  "categoryIconShared": [
    "This product uses the category’s uploaded icon. Change it in Categories or turn off Use category icon.",
    "يستخدم هذا المنتج رمز القسم. غيّره في الأقسام أو أوقف استخدام رمز القسم.",
    "ئەڤ بەرهەمە هێمایێ بەشی بکار دئینیت. د بەشان دا بگوهۆڕە یان هەلبژاردنا هێمایێ بەشی بگرە.",
  ],
  "categoryIcon": ["Category icon", "رمز القسم", "هێمایێ بەشی"],
  "noCategoriesHint": [
    "Create a category to organize products.",
    "أنشئ قسماً لتنظيم المنتجات.",
    "بەشەکێ دروست بکە بۆ رێکخستنا کەل و پەلان.",
  ],
  "addCategoryFirst": [
    "Add a category before adding products.",
    "أضف قسماً قبل إضافة المنتجات.",
    "بەری کەل و پەلان بەشەکێ زێدە بکە.",
  ],
  "categoryInUse": [
    "Move the products to another category before deleting this one.",
    "انقل المنتجات إلى قسم آخر قبل حذف هذا القسم.",
    "بەری ژێبرنا ڤی بەشی کەل و پەلان بگوهێزە بەشەکێ دی.",
  ],
  "photo": ["Photo", "الصورة", "وێنە"],
  "uploadPhoto": ["Upload photo", "رفع صورة", "وێنەی بار بکە"],
  "changePhoto": ["Change photo", "تغيير الصورة", "وێنەی بگوهۆڕە"],
  "removePhoto": ["Remove photo", "حذف الصورة", "وێنەی ژێ ببە"],
  "photoHint": [
    "PNG, JPG or WebP. Photos are saved on this device.",
    "PNG أو JPG أو WebP. تُحفظ الصور على هذا الجهاز.",
    "PNG، JPG یان WebP. وێنە ل سەر ڤی ئامێری دهێنە پاراستن.",
  ],
  "photoTooLarge": [
    "Choose a smaller image (up to 20 MB before resizing).",
    "اختر صورة أصغر (حتى 20 ميغابايت قبل التصغير).",
    "وێنەیەکا بچووکتر هەلبژێرە (هەتا ٢٠ مێگابایت بەری بچووککرنێ).",
  ],
  "invalidPhoto": [
    "Choose a valid PNG, JPG or WebP image.",
    "اختر صورة PNG أو JPG أو WebP صالحة.",
    "وێنەیەکا دروست یا PNG، JPG یان WebP هەلبژێرە.",
  ],
  "iconHint": [
    "Shown when no photo is selected.",
    "يظهر عند عدم اختيار صورة.",
    "دەردکەڤیت دەمێ وێنە نەهێتە هەلبژارتن.",
  ],
  "invalidCategory": [
    "Enter a category name.",
    "أدخل اسم القسم.",
    "ناڤێ بەشی بنڤیسە.",
  ],
  "duplicateCategory": [
    "This category name already exists in this market.",
    "اسم القسم موجود في هذا المتجر.",
    "ناڤێ ڤی بەشی ل ڤی مارکێتی هەیە.",
  ],
  "categorySaved": ["Category saved", "تم حفظ القسم", "بەش هاتە پاراستن"],
  "categoryDeleted": ["Category deleted", "تم حذف القسم", "بەش هاتە ژێبرن"],
  "itemsSold": ["Items sold", "القطع المباعة", "ژمارا کەل و پەلێن فرۆتی"],
  "staffPerformance": [
    "Sales by staff",
    "المبيعات حسب الموظف",
    "فرۆتن ب گۆرەی کارمەندی",
  ],
  "reportSubtitle": [
    "Revenue, profit and the people behind every sale.",
    "الإيرادات والأرباح والموظف المسؤول عن كل عملية بيع.",
    "داهات و قازانج و کارمەندێ هەر فرۆتنەکێ.",
  ],
  "profitExplanation": [
    "Gross profit excludes tax and subtracts discounts and item costs.",
    "الربح الإجمالي لا يشمل الضريبة ويخصم التخفيضات وتكلفة المنتجات.",
    "قازانجێ گشتی باجێ ناگرێتە خۆ و داشکاندن و نرخێ تێچوونێ ژێ دهێنە کێمکرن.",
  ],
  "soldItems": ["Sold items", "المنتجات المباعة", "کەل و پەلێن فرۆتی"],
  "selectReportCurrency": ["Report currency", "عملة التقرير", "دراڤێ راپۆرتێ"],
  "marketOwner": ["Market owner", "مالك المتجر", "خودانێ مارکێتی"],
  "marketOwnerPermissions": [
    "View profit, sales, sold items and staff reports; view, print and export receipts. No changes to products, staff or transactions.",
    "عرض الأرباح والمبيعات والمنتجات المباعة وتقارير الموظفين، وعرض الإيصالات وطباعتها وتصديرها، دون تعديل البيانات.",
    "بینینا قازانج و فرۆتن و کەل و پەلێن فرۆتی و راپۆرتێن کارمەندان و پسوولان، بێ گوهۆرینا داتایان.",
  ],
  "markets": ["Markets", "المتاجر", "مارکێت"],
  "market": ["Market", "المتجر", "مارکێت"],
  "marketsSubtitle": [
    "Independent markets, staff and receipts on this device.",
    "متاجر وموظفون وإيصالات مستقلة على هذا الجهاز.",
    "مارکێت و کارمەند و پسوولێن جودا ل سەر ڤی ئامێری.",
  ],
  "addMarket": ["Add market", "إضافة متجر", "مارکێتەکێ زێدە بکە"],
  "manageMarket": ["Manage market", "إدارة المتجر", "مارکێتی بەڕێڤە ببە"],
  "currentMarket": ["Current market", "المتجر الحالي", "مارکێتا نوکە"],
  "mainCurrency": ["Main currency", "العملة الأساسية", "دراڤێ سەرەکی"],
  "displayBothCurrencies": [
    "Display USD and IQD",
    "عرض الدولار والدينار معًا",
    "دۆلار و دیناری پێکڤە پیشان بدە",
  ],
  "displayBothCurrenciesHint": [
    "Optional for USD or IQD markets. Show a second price using your exchange rate.",
    "اختياري للمتاجر بالدولار أو الدينار. اعرض سعرًا ثانيًا باستخدام سعر الصرف الذي تحدده.",
    "هەلبژارتییە بۆ مارکێتێن دۆلار یان دیناری. نرخەکێ دوویێ ب نرخێ گوهۆڕینا خۆ پیشان بدە.",
  ],
  "usdIqdExchangeRate": [
    "IQD for 1 USD",
    "دينار عراقي مقابل دولار واحد",
    "دینارێ عێراقی بۆ ١ دۆلار",
  ],
  "exchangeRateHint": [
    "Enter your display rate. Update it in market Settings when needed; it is not fetched automatically.",
    "أدخل سعر الصرف للعرض. حدّثه من إعدادات المتجر عند الحاجة؛ لا يتم جلبه تلقائيًا.",
    "نرخێ گوهۆڕینێ بۆ پیشاندانێ بنڤیسە. دەمێ پێدڤی بیت ل ڕێکخستنێن مارکێتێ نوی بکە؛ ئۆتۆماتیکی ناهێتە وەرگرتن.",
  ],
  "invalidExchangeRate": [
    "Enter a positive USD/IQD exchange rate with up to two decimal places.",
    "أدخل سعر صرف موجبًا للدولار مقابل الدينار بمنزلتين عشريتين كحد أقصى.",
    "نرخەکێ گوهۆڕینا دۆلار و دیناری یێ ژ سفرێ مەزن بنڤیسە، ب هەتا دوو ژماران پشتی خاڵێ.",
  ],
  "paymentsInMainCurrency": [
    "Payments and change use",
    "الدفع والباقي بالعملة",
    "پارەدان و پاشماوە ب",
  ],
  "referenceTotal": ["Reference total", "الإجمالي التقريبي", "کۆما نزیکەیی"],
  "displayOnly": ["For display only", "للعرض فقط", "تەنێ بۆ پیشاندانێ"],
  "marketSetupHint": [
    "Add a market with its logo and currency preferences, then set receipt details in Settings and add staff in Team. Usernames must be unique across markets.",
    "أضف متجرًا مع شعاره وتفضيلات العملة، ثم اضبط الإيصال في الإعدادات وأضف الموظفين في الفريق. يجب أن تكون أسماء المستخدمين فريدة بين المتاجر.",
    "مارکێتەکێ ب لوگۆ و هەلبژاردنێن دراڤی زێدە بکە، پاشی ل ڕێکخستنان پسوولێ ڕێک بخە و ل تیمێ کارمەندان زێدە بکە. ناڤێن بەکارهێنەران دڤێت جودا بن.",
  ],
  "invalidMarket": [
    "Enter a market name and choose a currency.",
    "أدخل اسم المتجر واختر العملة.",
    "ناڤێ مارکێتی بنڤیسە و دراڤی هەلبژێرە.",
  ],
  "marketAdded": ["Market created", "تم إنشاء المتجر", "مارکێت هاتە دروستکرن"],
  "currencyUSD": [
    "USD — US dollar (\$)",
    "USD — الدولار الأمريكي (\$)",
    "USD — دۆلارێ ئەمریکی (\$)",
  ],
  "currencyIQD": [
    "IQD — Iraqi dinar",
    "IQD — الدينار العراقي",
    "IQD — دینارێ عێراقی",
  ],
  "currencyEUR": ["EUR — Euro (€)", "EUR — اليورو (€)", "EUR — یۆرۆ (€)"],

  "appSubtitle": [
    "SUPERMARKET POS",
    "نظام مبيعات السوبرماركت",
    "سیستەمێ فرۆتنێ یێ مارکێتێ",
  ],
  "welcomeTitle": [
    "A fresh start\nfor your store.",
    "بداية جديدة\nلمتجرك.",
    "دەستپێکەکا نوو\nبۆ مارکێتا تە.",
  ],
  "welcomeSubtitle": [
    "From the first customer to the last receipt. Everything you need for a better day at the counter.",
    "من أول عميل إلى آخر إيصال. كل ما تحتاجه ليوم أفضل في متجرك.",
    "ژ ئێکەم کریاری هەتا دوماهی پسوولێ. هەمی تشت بۆ ڕۆژەکا باشتر ل مارکێتا تە.",
  ],
  "offlineReady": [
    "Made for your everyday.",
    "مصمم ليومك.",
    "بۆ هەر ڕۆژەکا تە.",
  ],
  "offlineDescription": [
    "Fast checkout. Clear inventory. Your store, in your language.",
    "بيع سريع. مخزون واضح. متجرك بلغتك.",
    "فرۆتنا بلەز. کۆگەها ڕوون. مارکێتا تە ب زمانێ تە.",
  ],
  "freshPerspective": [
    "FRESH PERSPECTIVE. EVERY DAY.",
    "رؤية جديدة. كل يوم.",
    "نێرینەکا نوو. هەر ڕۆژ.",
  ],
  "localOnly": [
    "Saved on this device",
    "محفوظ على هذا الجهاز",
    "ل سەر ڤی ئامێری هاتیە پاراستن",
  ],
  "setupTitle": ["Make it your own", "اجعله متجرك", "بکە یا خۆ"],
  "setupSubtitle": [
    "Set up your store and create your super manager account.",
    "أعدّ متجرك وأنشئ حساب المدير العام.",
    "مارکێتا خۆ ئامادە بکە و هەژمارا بەڕێڤەبەرێ گشتی دروست بکە.",
  ],
  "loginTitle": ["Welcome back", "أهلاً بعودتك", "ب خێر هاتیەڤە"],
  "loginSubtitle": [
    "Sign in to start a good day at your store.",
    "سجّل الدخول لبدء يوم جميل في متجرك.",
    "بچۆ ژوور بۆ دەستپێکرنا ڕۆژەکا خۆش ل مارکێتا خۆ.",
  ],
  "storeName": ["Store name", "اسم المتجر", "ناڤێ مارکێتێ"],
  "fullName": ["Full name", "الاسم الكامل", "ناڤێ تەمام"],
  "username": ["Username", "اسم المستخدم", "ناڤێ بەکارهێنەری"],
  "password": ["Password", "كلمة المرور", "پەیڤا نهێنی"],
  "confirmPassword": [
    "Confirm password",
    "تأكيد كلمة المرور",
    "دووپاتکرنا پەیڤا نهێنی",
  ],
  "passwordHint": [
    "At least 8 characters",
    "8 أحرف على الأقل",
    "کێمترین ٨ پیت",
  ],
  "usernameHint": [
    "3–40 letters, numbers, . _ or -",
    "3–40 حرفاً لاتينياً أو رقماً أو . _ -",
    "٣–٤٠ پیتێن لاتینی یان ژمارە یان . _ -",
  ],
  "currency": ["Currency", "العملة", "دراڤ"],
  "sampleProducts": [
    "Start with sample products",
    "ابدأ بمنتجات تجريبية",
    "ب بەرهەمێن نموونە دەست پێ بکە",
  ],
  "sampleHint": [
    "12 editable products. No sample sales.",
    "12 منتجاً قابلاً للتعديل، دون مبيعات وهمية.",
    "١٢ بەرهەمێن دەستکاری دکرێن. بێ فرۆتنێن نموونە.",
  ],
  "createStore": ["Create my store", "إنشاء متجري", "مارکێتا من دروست بکە"],
  "signIn": ["Sign in", "تسجيل الدخول", "چوونا ژوور"],
  "loginOption": ["Log in", "تسجيل الدخول", "چوونا ژوور"],
  "signOut": ["Sign out", "تسجيل الخروج", "دەرکەفتن"],
  "workspace": ["WORKSPACE", "مساحة العمل", "جهێ کاری"],
  "management": ["MANAGEMENT", "الإدارة", "بەڕێڤەبرن"],
  "register": ["Point of sale", "نقطة البيع", "خالا فرۆتنێ"],
  "overview": ["Overview", "نظرة عامة", "نێرینا گشتی"],
  "inventory": ["Inventory", "المخزون", "کۆگەه"],
  "sales": ["Sales history", "سجل المبيعات", "تۆمارا فرۆتنان"],
  "team": ["Team & access", "الفريق والصلاحيات", "تیم و دەستهەلات"],
  "settings": ["Store settings", "إعدادات المتجر", "ڕێکخستنێن مارکێتێ"],
  "audit": ["Activity log", "سجل النشاط", "تۆمارا چالاکیان"],
  "cashier": ["Cashier", "موظف المبيعات", "کارمەندێ فرۆتنێ"],
  "admin": ["Admin", "مدير", "بەڕێڤەبەر"],
  "superManager": ["Super manager", "المدير العام", "بەڕێڤەبەرێ گشتی"],
  "language": ["Language", "اللغة", "زمان"],
  "newSale": [
    "Let's make today a good day.",
    "لنجعل اليوم يوماً جميلاً.",
    "وەرن ئەڤڕۆ بکەینە ڕۆژەکا خۆش.",
  ],
  "registerSubtitle": [
    "Fresh picks, quick checkout, happy customers.",
    "منتجات طازجة، بيع سريع، عملاء سعداء.",
    "بەرهەمێن تازە، فرۆتنا بلەز، کریارێن دڵخۆش.",
  ],
  "searchProducts": [
    "Search products or scan a barcode…",
    "ابحث عن منتج أو امسح الباركود…",
    "ل بەرهەمی بگەڕێ یان بارکۆدی بخوینە…",
  ],
  "all": ["All items", "كل المنتجات", "هەمی بەرهەم"],
  "produce": ["Produce", "الخضار والفواكه", "سەوزە و فێکی"],
  "dairy": ["Dairy & eggs", "الألبان والبيض", "شیرەمەنی و هێک"],
  "bakery": ["Bakery", "المخبوزات", "نان و پەتی"],
  "meat": ["Meat & poultry", "اللحوم والدواجن", "گۆشت و مریشک"],
  "pantry": ["Pantry", "المواد الغذائية", "خوارن"],
  "drinks": ["Drinks", "المشروبات", "ڤەخوارن"],
  "household": ["Household", "مستلزمات المنزل", "پێدڤیێن مالێ"],
  "inStock": ["in stock", "في المخزون", "ل کۆگەهێ"],
  "outOfStock": ["Out of stock", "نفد المخزون", "ل کۆگەهێ نینە"],
  "lowStock": ["Low stock", "مخزون منخفض", "کۆگەها کێم"],
  "currentOrder": ["Current order", "الطلب الحالي", "داخوازییا نوکە"],
  "walkIn": ["Walk-in customer", "عميل مباشر", "کریارێ ڕاستەوخۆ"],
  "clear": ["Clear", "مسح", "پاککرن"],
  "emptyCartTitle": [
    "Your next sale starts here",
    "تبدأ مبيعاتك القادمة هنا",
    "فرۆتنا تە یا داهاتی ل ڤێرێ دەست پێ دکەت",
  ],
  "emptyCartHint": [
    "Tap a product to add it to this order.",
    "اضغط على منتج لإضافته إلى الطلب.",
    "ل بەرهەمەکی بدە بۆ زێدەکرنێ ل داخوازیێ.",
  ],
  "items": ["items", "منتجات", "بەرهەم"],
  "subtotal": ["Subtotal", "المجموع الفرعي", "کۆما سەرەتایی"],
  "discount": ["Discount", "الخصم", "داشکاندن"],
  "tax": ["Tax", "الضريبة", "باج"],
  "total": ["Total", "الإجمالي", "کۆم"],
  "checkout": ["Charge", "تحصيل", "وەرگرتنا پارەی"],
  "reviewOrder": ["Review order", "مراجعة الطلب", "پێداچوونا داخوازیێ"],
  "payment": ["Payment", "الدفع", "دان"],
  "cash": ["Cash", "نقداً", "نەقد"],
  "card": [
    "Card · external terminal",
    "بطاقة · جهاز خارجي",
    "کارت · ئامێرەکێ دەرەکی",
  ],
  "cardNote": [
    "Complete payment on your card terminal first. This app records the payment only.",
    "أكمل الدفع على جهاز البطاقة أولاً. هذا التطبيق يسجّل الدفعة فقط.",
    "پێشتر پارەی ل ئامێرێ کارتێ بدە. ئەڤ ئەپە تەنێ دانێ تۆمار دکەت.",
  ],
  "amountReceived": ["Cash received", "النقد المستلم", "پارەیێ وەرگرتی"],
  "change": ["Change due", "الباقي", "پارەیێ ماوە"],
  "completeSale": ["Complete sale", "إتمام البيع", "فرۆتنێ تەمام بکە"],
  "saleComplete": ["Sale completed", "تم البيع", "فرۆتن تەمام بوو"],
  "receipt": ["Receipt", "الإيصال", "پسوولە"],
  "printReceipt": ["Print receipt", "طباعة الإيصال", "چاپکرنا پسوولێ"],
  "savePdf": ["Save PDF", "حفظ PDF", "پاراستنا PDF"],
  "close": ["Close", "إغلاق", "گرتن"],
  "cancel": ["Cancel", "إلغاء", "هەلوەشاندن"],
  "save": ["Save changes", "حفظ التغييرات", "گوهۆڕینان بپارێزە"],
  "add": ["Add", "إضافة", "زێدەکرن"],
  "edit": ["Edit", "تعديل", "دەستکاری"],
  "remove": ["Remove", "إزالة", "ژێبرن"],
  "delete": ["Delete", "حذف", "ژێبرن"],
  "confirmDelete": [
    "Delete this item?",
    "حذف هذا العنصر؟",
    "ئەڤ تشتە بهێتە ژێبرن؟",
  ],
  "deleteHint": [
    "This cannot be undone. Existing sale receipts will be kept.",
    "لا يمكن التراجع. ستُحفظ إيصالات المبيعات السابقة.",
    "ئەڤە نایێتە زڤڕاندن. پسوولێن فرۆتنێن بەرێ دێ هێنە پاراستن.",
  ],
  "saved": ["Changes saved", "تم حفظ التغييرات", "گوهۆڕین هاتنە پاراستن"],
  "inventorySubtitle": [
    "Everything on your shelves, in one place.",
    "كل ما على رفوفك في مكان واحد.",
    "هەمی تشتێن سەر ڕەفێن تە ل ئێک جهی.",
  ],
  "addProduct": ["Add product", "إضافة منتج", "زێدەکرنا بەرهەمی"],
  "editProduct": ["Edit product", "تعديل المنتج", "دەستکاریکرنا بەرهەمی"],
  "product": ["Product", "المنتج", "بەرهەم"],
  "productName": [
    "Product name (English)",
    "اسم المنتج (الإنجليزية)",
    "ناڤێ بەرهەمی (ئینگلیزی)",
  ],
  "arabicName": ["Arabic name", "الاسم بالعربية", "ناڤ ب عەرەبی"],
  "kurdishName": [
    "Kurdish Badini name",
    "الاسم بالكردية البادينية",
    "ناڤ ب کوردیا بادینی",
  ],
  "barcode": [
    "Barcode / SKU",
    "الباركود / رمز المنتج",
    "بارکۆد / کۆدێ بەرهەمی",
  ],
  "category": ["Category", "الفئة", "جۆر"],
  "price": ["Selling price", "سعر البيع", "بهایێ فرۆتنێ"],
  "cost": ["Cost price", "سعر التكلفة", "بهایێ کڕینێ"],
  "stock": ["Stock quantity", "كمية المخزون", "ژمارا کۆگەهێ"],
  "unit": ["Pack / unit label", "العبوة / الوحدة", "ناڤێ یەکەیێ"],
  "lowStockThreshold": [
    "Low stock alert at",
    "التنبيه عند انخفاض المخزون إلى",
    "ئاگەهدارییا کۆگەها کێم ل",
  ],
  "productIcon": ["Product icon", "رمز المنتج", "نیشانێ بەرهەمی"],
  "stockValue": [
    "Inventory cost value",
    "قيمة تكلفة المخزون",
    "بهایێ کڕینا کۆگەهێ",
  ],
  "products": ["Products", "المنتجات", "بەرهەم"],
  "needsAttention": ["Need attention", "تحتاج انتباهاً", "پێدڤی ب بالدانێ"],
  "noResults": [
    "Nothing here yet",
    "لا توجد نتائج بعد",
    "هێشتا تشتەک ل ڤێرێ نینە",
  ],
  "noProductsHint": [
    "Add products in Inventory to get started.",
    "أضف منتجات في المخزون للبدء.",
    "بۆ دەستپێکرنێ بەرهەمان ل کۆگەهێ زێدە بکە.",
  ],
  "search": ["Search…", "بحث…", "لێگەڕیان…"],
  "teamSubtitle": [
    "The right access for every member of your team.",
    "الصلاحيات المناسبة لكل عضو في فريقك.",
    "دەستهەلاتا گونجای بۆ هەر ئەندامەکێ تیما تە.",
  ],
  "addUser": ["Add team member", "إضافة عضو للفريق", "زێدەکرنا ئەندامێ تیمێ"],
  "editUser": [
    "Edit team member",
    "تعديل عضو الفريق",
    "دەستکاریکرنا ئەندامێ تیمێ",
  ],
  "role": ["Role", "الدور", "ڕۆل"],
  "active": ["Active", "نشط", "چالاک"],
  "inactive": ["Inactive", "غير نشط", "ناچالاک"],
  "accountActive": ["Account enabled", "الحساب مفعّل", "هەژمار چالاکە"],
  "newPasswordHint": [
    "Leave blank to keep the current password",
    "اتركه فارغاً للاحتفاظ بكلمة المرور",
    "ڤالا بهێلە بۆ پاراستنا پەیڤا نهێنی یا نوکە",
  ],
  "cashierPermissions": [
    "Checkout and own sales history",
    "البيع وسجل مبيعاته فقط",
    "فرۆتن و تۆمارا فرۆتنێن خۆ",
  ],
  "adminPermissions": [
    "This market's products, categories, photos, sales, branding and cashier accounts",
    "منتجات وأقسام وصور ومبيعات وشعار هذا المتجر وحسابات البائعين",
    "کەل و پەل، بەش، وێنە، فرۆتن، لوگۆ و هەژمارێن فرۆشیارێن ڤی مارکێتی",
  ],
  "ownerPermissions": [
    "Manage every market, its branding and all admin, owner and sales accounts",
    "إدارة جميع المتاجر وشعاراتها وحسابات المديرين والمالكين والبائعين",
    "بەڕێڤەبرنا هەمی مارکێتان و لوگۆ و هەژمارێن بەڕێڤەبەر و خودان و فرۆشیاران",
  ],
  "salesSubtitle": [
    "Every transaction, all in one place.",
    "كل عملية بيع في مكان واحد.",
    "هەر فرۆتنەک ل ئێک جهی.",
  ],
  "today": ["Today", "اليوم", "ئەڤڕۆ"],
  "week": ["Last 7 days", "آخر 7 أيام", "دوماهی ٧ ڕۆژ"],
  "month": ["This month", "هذا الشهر", "ئەڤ هەیڤە"],
  "allTime": ["All time", "كل الفترات", "هەمی دەم"],
  "custom": ["Choose dates", "اختيار التواريخ", "هەلبژارتنا ڕۆژان"],
  "export": ["Export CSV", "تصدير CSV", "دەرئێخستنا CSV"],
  "status": ["Status", "الحالة", "ڕەوش"],
  "completed": ["Completed", "مكتمل", "تەما‌مبووی"],
  "voided": ["Voided", "ملغى", "هەلوەشاندی"],
  "voidSale": [
    "Void & restock",
    "إلغاء وإعادة المخزون",
    "هەلوەشاندن و زڤڕاندنا کۆگەهێ",
  ],
  "voidReason": ["Reason for voiding", "سبب الإلغاء", "ئەگەرێ هەلوەشاندنێ"],
  "voidHint": [
    "Stock will be returned for products still in your catalog. Handle any refund separately.",
    "سيُعاد المخزون للمنتجات الموجودة. أعد المبلغ للعميل بشكل منفصل.",
    "کۆگەه بۆ بەرهەمێن هەیی دێ زڤڕیتەڤە. پارەی جودا بۆ کریاری بزڤڕینە.",
  ],
  "revenue": ["Net sales", "صافي المبيعات", "فرۆتنا پاقژ"],
  "transactions": ["Transactions", "عمليات البيع", "فرۆتن"],
  "averageSale": ["Average sale", "متوسط البيع", "ناڤەندا فرۆتنێ"],
  "profit": ["Gross profit", "الربح الإجمالي", "قازانجێ گشتی"],
  "overviewSubtitle": [
    "A little clarity for a better business day.",
    "رؤية أوضح ليوم عمل أفضل.",
    "ڕوونییەکا زێدە بۆ ڕۆژەکا باشتر یا کاری.",
  ],
  "salesTrend": ["Sales this week", "مبيعات هذا الأسبوع", "فرۆتنێن ڤێ حەفتیێ"],
  "recentSales": ["Recent sales", "أحدث المبيعات", "فرۆتنێن نوو"],
  "viewAll": ["View all", "عرض الكل", "هەمییان ببینە"],
  "stockWatch": [
    "Keep an eye on these",
    "راقب هذه المنتجات",
    "بالا خۆ بدە ڤان",
  ],
  "healthyStock": [
    "Your shelves are looking good.",
    "مخزونك بحالة جيدة.",
    "کۆگەها تە باشە.",
  ],
  "settingsSubtitle": [
    "Your store. Your identity. Your way.",
    "متجرك وهويتك وطريقتك.",
    "مارکێتا تە. ناسناما تە. ڕێکا تە.",
  ],
  "brand": [
    "Brand & store details",
    "العلامة التجارية وبيانات المتجر",
    "براند و پێزانینێن مارکێتێ",
  ],
  "uploadLogo": ["Upload logo", "رفع الشعار", "بارکرنا لۆگۆی"],
  "logoHint": [
    "PNG or JPG · up to 2 MB",
    "PNG أو JPG · حتى 2 ميغابايت",
    "PNG یان JPG · هەتا ٢ مێگابایت",
  ],
  "removeLogo": ["Remove logo", "إزالة الشعار", "ژێبرنا لۆگۆی"],
  "tagline": ["Store tagline", "شعار المتجر النصي", "دروشما مارکێتێ"],
  "address": ["Address", "العنوان", "ناڤنیشان"],
  "phone": ["Phone number", "رقم الهاتف", "ژمارا تەلەفۆنێ"],
  "taxRate": ["Tax rate (%)", "نسبة الضريبة (%)", "ڕێژەیا باجی (%)"],
  "receiptSettings": ["Receipt design", "تصميم الإيصال", "دیزاینا پسوولێ"],
  "receiptHeader": ["Receipt header", "رأس الإيصال", "سەرێ پسوولێ"],
  "receiptFooter": ["Receipt footer", "تذييل الإيصال", "بنێ پسوولێ"],
  "showCashier": [
    "Show cashier on receipt",
    "إظهار البائع على الإيصال",
    "ناڤێ فرۆشیاری ل پسوولێ پیشان بدە",
  ],
  "paperWidth": ["Paper width", "عرض الورق", "پانییا کاغەزی"],
  "preview": ["Live preview", "معاينة مباشرة", "پێشبینینا ڕاستەوخۆ"],
  "previewHint": [
    "Example only · changes apply to new sales",
    "نموذج فقط · التغييرات للمبيعات الجديدة",
    "تەنێ نموونە · گوهۆڕین بۆ فرۆتنێن نوو نە",
  ],
  "currencyHint": [
    "Currency is fixed once products or sales exist.",
    "تُثبّت العملة بعد إضافة منتجات أو مبيعات.",
    "پشتی زێدەکرنا بەرهەم یان فرۆتنێ دراڤ ناهێتە گوهۆڕین.",
  ],
  "auditSubtitle": [
    "A record of important changes on this device.",
    "سجل التغييرات المهمة على هذا الجهاز.",
    "تۆمارا گوهۆڕینێن گرنگ ل سەر ڤی ئامێری.",
  ],
  "setup": ["Store created", "تم إنشاء المتجر", "مارکێت هاتە دروستکرن"],
  "userAdded": ["Team member added", "تمت إضافة عضو", "ئەندام هاتە زێدەکرن"],
  "userUpdated": [
    "Team member updated",
    "تم تعديل عضو",
    "ئەندام هاتە دەستکاریکرن",
  ],
  "userDeleted": ["Team member deleted", "تم حذف عضو", "ئەندام هاتە ژێبرن"],
  "productSaved": ["Product saved", "تم حفظ المنتج", "بەرهەم هاتە پاراستن"],
  "productDeleted": ["Product deleted", "تم حذف المنتج", "بەرهەم هاتە ژێبرن"],
  "settingsUpdated": [
    "Settings updated",
    "تم تحديث الإعدادات",
    "ڕێکخستن هاتنە گوهۆڕین",
  ],
  "saleCompleted": ["Sale completed", "تم البيع", "فرۆتن تەمام بوو"],
  "saleVoided": ["Sale voided", "تم إلغاء البيع", "فرۆتن هاتە هەلوەشاندن"],
  "required": ["This field is required", "هذا الحقل مطلوب", "ئەڤ خانە پێدڤیە"],
  "invalidNumber": [
    "Enter a valid positive number (up to 2 decimals)",
    "أدخل رقماً موجباً صالحاً (حتى منزلتين عشريتين)",
    "ژمارەکا دروست یا ئەرێنی بنڤیسە (هەتا ٢ ژمارێن دەهەکی)",
  ],
  "passwordMismatch": [
    "Passwords do not match",
    "كلمتا المرور غير متطابقتين",
    "پەیڤێن نهێنی وەک ئێک نینن",
  ],
  "permissionDenied": [
    "You do not have permission for this action.",
    "ليس لديك صلاحية لهذه العملية.",
    "دەستهەلاتا تە بۆ ڤی کاری نینە.",
  ],
  "invalidUser": [
    "Enter a name and a valid username.",
    "أدخل اسماً واسم مستخدم صالحاً.",
    "ناڤ و ناڤەکێ دروست یێ بەکارهێنەری بنڤیسە.",
  ],
  "passwordLength": [
    "Use a password of at least 8 characters.",
    "استخدم كلمة مرور من 8 أحرف على الأقل.",
    "پەیڤەکا نهێنی ب کێمترین ٨ پیتان بنڤیسە.",
  ],
  "invalidCredentials": [
    "Username or password is incorrect, or the account is disabled.",
    "اسم المستخدم أو كلمة المرور غير صحيحة، أو الحساب معطّل.",
    "ناڤ یان پەیڤا نهێنی نەدروستە، یان هەژمار ناچالاکە.",
  ],
  "tooManyAttempts": [
    "Too many attempts. Try again in 30 seconds.",
    "محاولات كثيرة. أعد المحاولة بعد 30 ثانية.",
    "هەوڵێن زۆر. پشتی ٣٠ چرکەیان دیسان هەوڵ بدە.",
  ],
  "duplicateUsername": [
    "This username is already in use.",
    "اسم المستخدم مستخدم بالفعل.",
    "ئەڤ ناڤێ بەکارهێنەری یێ هەییە.",
  ],
  "invalidProduct": [
    "Check the product details and quantities.",
    "تحقق من تفاصيل المنتج والكميات.",
    "پێزانین و ژمارێن بەرهەمی بپشکنە.",
  ],
  "duplicateBarcode": [
    "Another product uses this barcode.",
    "منتج آخر يستخدم هذا الباركود.",
    "بەرهەمەکێ دی ئەڤ بارکۆدە بکار دئینیت.",
  ],
  "invalidSettings": [
    "Check the store name, tax rate and receipt settings.",
    "تحقق من الاسم والضريبة وإعدادات الإيصال.",
    "ناڤ، باج و ڕێکخستنێن پسوولێ بپشکنە.",
  ],
  "currencyLocked": [
    "Currency cannot change after products or sales are added.",
    "لا يمكن تغيير العملة بعد إضافة منتجات أو مبيعات.",
    "پشتی زێدەکرنا بەرهەم یان فرۆتنێ دراڤ ناهێتە گوهۆڕین.",
  ],
  "emptyCart": [
    "Add a product to the order first.",
    "أضف منتجاً إلى الطلب أولاً.",
    "پێشتر بەرهەمەکی ل داخوازیێ زێدە بکە.",
  ],
  "insufficientStock": [
    "A product is unavailable or there is not enough stock.",
    "منتج غير متوفر أو المخزون غير كافٍ.",
    "بەرهەم نینە یان کۆگەه بەس نینە.",
  ],
  "invalidDiscount": [
    "Discount must be between zero and the subtotal.",
    "يجب أن يكون الخصم بين صفر والمجموع الفرعي.",
    "داشکاندن دڤێت د ناڤبەرا سفر و کۆما سەرەتایی دا بیت.",
  ],
  "invalidPayment": [
    "Choose a valid payment method.",
    "اختر طريقة دفع صالحة.",
    "ڕێکەکا دروست یا دانێ هەلبژێرە.",
  ],
  "insufficientPayment": [
    "The amount received is less than the total.",
    "المبلغ المستلم أقل من الإجمالي.",
    "پارەیێ وەرگرتی ژ کۆمێ کێمترە.",
  ],
  "invalidVoid": [
    "Enter a reason. A sale can only be voided once.",
    "أدخل السبب. يمكن إلغاء البيع مرة واحدة فقط.",
    "ئەگەری بنڤیسە. فرۆتن تەنێ جارەکێ دهێتە هەلوەشاندن.",
  ],
  "logoTooLarge": [
    "Choose a PNG or JPG image smaller than 2 MB.",
    "اختر صورة PNG أو JPG أصغر من 2 ميغابايت.",
    "وێنەیەکێ PNG یان JPG ژ ٢ مێگابایت بچووکتر هەلبژێرە.",
  ],
  "somethingWrong": [
    "Unable to complete this action. Please try again.",
    "تعذر إكمال العملية. حاول مجدداً.",
    "ئەڤ کارە نەهاتە تەمامکرن. دیسان هەوڵ بدە.",
  ],
  "fileSaved": ["File saved", "تم حفظ الملف", "فایل هاتە پاراستن"],
  "removeItem": ["Remove item", "إزالة المنتج", "ژێبرنا بەرهەمی"],
  "increaseQuantity": ["Increase quantity", "زيادة الكمية", "زێدەکرنا ژمارێ"],
  "decreaseQuantity": ["Decrease quantity", "تقليل الكمية", "کێمکرنا ژمارێ"],
  "menu": ["Open menu", "فتح القائمة", "ڤەکرنا لیستێ"],
  "back": ["Back", "رجوع", "پاشڤە"],
  "paid": ["Paid", "مدفوع", "هاتیە دان"],
  "localNote": [
    "Offline workspace · this device only",
    "مساحة عمل دون إنترنت · هذا الجهاز فقط",
    "جهێ کاری بێ ئینتەرنێت · تەنێ ئەڤ ئامێرە",
  ],
  "signOutHint": [
    "Any unfinished order will be cleared.",
    "سيُمسح أي طلب غير مكتمل.",
    "هەر داخوازییەکا نەتمام دێ هێتە پاککرن.",
  ],
};
