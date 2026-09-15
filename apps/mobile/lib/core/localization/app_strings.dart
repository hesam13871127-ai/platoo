import 'package:flutter/material.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get isPersian => locale.languageCode == 'fa';
  String t(String key) => _values[key]?[isPersian ? 'fa' : 'en'] ?? key;
  String get appName => 'VibeTable';
  String get play => t('play');
  String get shop => t('shop');
  String get social => t('social');
  String get profile => t('profile');
  String get welcome => t('welcome');
  String get continueText => t('continue');
  String get phone => t('phone');
  String get verificationCode => t('verificationCode');
  String get sendCode => t('sendCode');
  String get verify => t('verify');
  String get coins => t('coins');
  String get pips => t('pips');
  String get games => t('games');
  String get friends => t('friends');
  String get chat => t('chat');
  String get settings => t('settings');
  String get signOut => t('signOut');
  String get light => t('light');
  String get dark => t('dark');
  String get language => t('language');
  String get ranked => t('ranked');
  String get casual => t('casual');
  String get findMatch => t('findMatch');
  String get cancel => t('cancel');
  String get buy => t('buy');
  String get equipped => t('equipped');
  String get retry => t('retry');

  // Shop & Inventory enhancements
  String get myInventory => t('myInventory');
  String get catalog => t('catalog');
  String get all => t('all');
  String get avatars => t('avatars');
  String get frames => t('frames');
  String get emotes => t('emotes');
  String get tables => t('tables');
  String get dice => t('dice');
  String get bundles => t('bundles');
  String get equip => t('equip');
  String get unequip => t('unequip');
  String get owned => t('owned');
  String get getCoins => t('getCoins');
  String get gift => t('gift');
  String get giftToFriend => t('giftToFriend');
  String get sendGift => t('sendGift');
  String get selectFriend => t('selectFriend');
  String get giftNote => t('giftNote');
  String get giftSentSuccess => t('giftSentSuccess');
  String get purchaseSuccess => t('purchaseSuccess');
  String get limitedEdition => t('limitedEdition');
  String get soldOut => t('soldOut');
  String get leftInStock => t('leftInStock');
  String get currentlyEquipped => t('currentlyEquipped');
  String get noItemsCategory => t('noItemsCategory');
  String get browseShop => t('browseShop');
  String get giftHistory => t('giftHistory');
  String get received => t('received');
  String get sent => t('sent');
  String get searchShop => t('searchShop');
  String get unlocked => t('unlocked');
  String get equipNow => t('equipNow');
  String get itemDetails => t('itemDetails');

  // Admin & Staff Hub
  String get adminConsole => t('adminConsole');
  String get adminStaffHub => t('adminStaffHub');
  String get adminStaffSubtitle => t('adminStaffSubtitle');
  String get openConsole => t('openConsole');

  static const _values = <String, Map<String, String>>{
    'play': {'en': 'Play', 'fa': 'بازی'},
    'shop': {'en': 'Shop', 'fa': 'فروشگاه'},
    'social': {'en': 'Social', 'fa': 'اجتماعی'},
    'profile': {'en': 'Profile', 'fa': 'پروفایل'},
    'welcome': {'en': 'Where every table has a story.', 'fa': 'هر میز، یک داستان تازه دارد.'},
    'continue': {'en': 'Continue', 'fa': 'ادامه'},
    'phone': {'en': 'Phone number', 'fa': 'شماره تلفن'},
    'verificationCode': {'en': 'Verification code', 'fa': 'کد تایید'},
    'sendCode': {'en': 'Send code', 'fa': 'ارسال کد'},
    'verify': {'en': 'Verify', 'fa': 'تایید'},
    'coins': {'en': 'Coins', 'fa': 'سکه'},
    'pips': {'en': 'Pips', 'fa': 'پیپ'},
    'games': {'en': 'Games', 'fa': 'بازی‌ها'},
    'friends': {'en': 'Friends', 'fa': 'دوستان'},
    'chat': {'en': 'Chat', 'fa': 'گفتگو'},
    'settings': {'en': 'Settings', 'fa': 'تنظیمات'},
    'signOut': {'en': 'Sign out', 'fa': 'خروج'},
    'light': {'en': 'Light', 'fa': 'روشن'},
    'dark': {'en': 'Dark', 'fa': 'تیره'},
    'language': {'en': 'Language', 'fa': 'زبان'},
    'ranked': {'en': 'Ranked', 'fa': 'رتبه‌ای'},
    'casual': {'en': 'Casual', 'fa': 'تفریحی'},
    'findMatch': {'en': 'Find a match', 'fa': 'پیدا کردن حریف'},
    'cancel': {'en': 'Cancel', 'fa': 'لغو'},
    'buy': {'en': 'Buy', 'fa': 'خرید'},
    'equipped': {'en': 'Equipped', 'fa': 'فعال'},
    'retry': {'en': 'Try again', 'fa': 'تلاش دوباره'},
    'myInventory': {'en': 'My Inventory', 'fa': 'وسایل من'},
    'catalog': {'en': 'Shop Catalog', 'fa': 'کاتالوگ فروشگاه'},
    'all': {'en': 'All', 'fa': 'همه'},
    'avatars': {'en': 'Avatars', 'fa': 'آواتارها'},
    'frames': {'en': 'Frames', 'fa': 'فریم‌ها'},
    'emotes': {'en': 'Emotes', 'fa': 'ایموت‌ها'},
    'tables': {'en': 'Tables', 'fa': 'میزها'},
    'dice': {'en': 'Dice', 'fa': 'تاس‌ها'},
    'bundles': {'en': 'Bundles', 'fa': 'بسته‌ها'},
    'equip': {'en': 'Equip', 'fa': 'فعال‌سازی'},
    'unequip': {'en': 'Unequip', 'fa': 'غیرفعال‌سازی'},
    'owned': {'en': 'Owned', 'fa': 'در وسایل شما'},
    'getCoins': {'en': 'Get coins', 'fa': 'خرید سکه'},
    'gift': {'en': 'Gift', 'fa': 'هدیه'},
    'giftToFriend': {'en': 'Send as gift', 'fa': 'ارسال به عنوان هدیه'},
    'sendGift': {'en': 'Send Gift', 'fa': 'ارسال هدیه'},
    'selectFriend': {'en': 'Select friend', 'fa': 'انتخاب دوست'},
    'giftNote': {'en': 'Add a personal note…', 'fa': 'افزودن یادداشت دلخواه…'},
    'giftSentSuccess': {'en': 'Gift sent successfully!', 'fa': 'هدیه با موفقیت ارسال شد!'},
    'purchaseSuccess': {'en': 'Purchase successful!', 'fa': 'خرید با موفقیت انجام شد!'},
    'limitedEdition': {'en': 'Limited', 'fa': 'محدود'},
    'soldOut': {'en': 'Sold Out', 'fa': 'تمام شد'},
    'leftInStock': {'en': 'left in stock', 'fa': 'عدد باقی مانده'},
    'currentlyEquipped': {'en': 'Currently Equipped', 'fa': 'تزئینات فعال'},
    'noItemsCategory': {'en': 'No items in this category', 'fa': 'آیتمی در این دسته وجود ندارد'},
    'browseShop': {'en': 'Browse Shop', 'fa': 'مشاهده فروشگاه'},
    'giftHistory': {'en': 'Gift History', 'fa': 'تاریخچه هدایا'},
    'received': {'en': 'Received', 'fa': 'دریافتی'},
    'sent': {'en': 'Sent', 'fa': 'ارسال‌شده'},
    'searchShop': {'en': 'Search cosmetics…', 'fa': 'جست‌وجوی تزئینات…'},
    'unlocked': {'en': 'Unlocked!', 'fa': 'بازگشایی شد!'},
    'equipNow': {'en': 'Equip Now', 'fa': 'فعال کردن اکنون'},
    'itemDetails': {'en': 'Item Details', 'fa': 'جزئیات آیتم'},
    'adminConsole': {'en': 'Admin Console', 'fa': 'پنل مدیریت'},
    'adminStaffHub': {'en': 'Staff & Admin Console', 'fa': 'مرکز مدیریت و نظارت'},
    'adminStaffSubtitle': {'en': 'System controls, moderation & live telemetry', 'fa': 'کنترل سیستم، نظارت بر گزارش‌ها و آمار زنده'},
    'openConsole': {'en': 'Open Console', 'fa': 'ورود به پنل مدیریت'},
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppLocalizationsDelegate();
  @override bool isSupported(Locale locale) => ['en', 'fa'].contains(locale.languageCode);
  @override Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
