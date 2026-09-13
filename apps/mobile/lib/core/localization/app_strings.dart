import 'package:flutter/material.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get isPersian => locale.languageCode == 'fa';
  String t(String key) => _values[key]?[isPersian ? 'fa' : 'en'] ?? key;
  String get appName => 'VibeTable';
  String get play => t('play'); String get shop => t('shop'); String get social => t('social'); String get profile => t('profile'); String get welcome => t('welcome'); String get continueText => t('continue'); String get phone => t('phone'); String get verificationCode => t('verificationCode'); String get sendCode => t('sendCode'); String get verify => t('verify'); String get coins => t('coins'); String get pips => t('pips'); String get games => t('games'); String get friends => t('friends'); String get chat => t('chat'); String get settings => t('settings'); String get signOut => t('signOut'); String get light => t('light'); String get dark => t('dark'); String get language => t('language'); String get ranked => t('ranked'); String get casual => t('casual'); String get findMatch => t('findMatch'); String get cancel => t('cancel'); String get buy => t('buy'); String get equipped => t('equipped'); String get retry => t('retry');
  static const _values = <String, Map<String, String>>{
    'play': {'en': 'Play', 'fa': 'بازی'}, 'shop': {'en': 'Shop', 'fa': 'فروشگاه'}, 'social': {'en': 'Social', 'fa': 'اجتماعی'}, 'profile': {'en': 'Profile', 'fa': 'پروفایل'}, 'welcome': {'en': 'Where every table has a story.', 'fa': 'هر میز، یک داستان تازه دارد.'}, 'continue': {'en': 'Continue', 'fa': 'ادامه'}, 'phone': {'en': 'Phone number', 'fa': 'شماره تلفن'}, 'verificationCode': {'en': 'Verification code', 'fa': 'کد تایید'}, 'sendCode': {'en': 'Send code', 'fa': 'ارسال کد'}, 'verify': {'en': 'Verify', 'fa': 'تایید'}, 'coins': {'en': 'Coins', 'fa': 'سکه'}, 'pips': {'en': 'Pips', 'fa': 'پیپ'}, 'games': {'en': 'Games', 'fa': 'بازی‌ها'}, 'friends': {'en': 'Friends', 'fa': 'دوستان'}, 'chat': {'en': 'Chat', 'fa': 'گفتگو'}, 'settings': {'en': 'Settings', 'fa': 'تنظیمات'}, 'signOut': {'en': 'Sign out', 'fa': 'خروج'}, 'light': {'en': 'Light', 'fa': 'روشن'}, 'dark': {'en': 'Dark', 'fa': 'تیره'}, 'language': {'en': 'Language', 'fa': 'زبان'}, 'ranked': {'en': 'Ranked', 'fa': 'رتبه‌ای'}, 'casual': {'en': 'Casual', 'fa': 'تفریحی'}, 'findMatch': {'en': 'Find a match', 'fa': 'پیدا کردن حریف'}, 'cancel': {'en': 'Cancel', 'fa': 'لغو'}, 'buy': {'en': 'Buy', 'fa': 'خرید'}, 'equipped': {'en': 'Equipped', 'fa': 'فعال'}, 'retry': {'en': 'Try again', 'fa': 'تلاش دوباره'},
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppLocalizationsDelegate();
  @override bool isSupported(Locale locale) => ['en', 'fa'].contains(locale.languageCode);
  @override Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
