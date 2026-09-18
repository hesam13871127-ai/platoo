import 'package:flutter/material.dart';

/// All product copy that is rendered by the Flutter client goes through this
/// object.  The API deliberately returns stable English identifiers for game
/// and moderation data; this layer owns the user-facing wording so a locale
/// change is immediate and never leaves a screen half translated.
class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;

  bool get isPersian => locale.languageCode == 'fa';

  String t(String key) => _values[key]?[isPersian ? 'fa' : 'en'] ?? key;

  /// Translate a piece of copy supplied by a reusable widget.  Keeping the
  /// English source string at call sites makes this safe for dynamic labels
  /// while preserving the English build byte-for-byte.
  String translateText(String text) {
    if (!isPersian || text.isEmpty) return text;
    final exact = _copy[text];
    if (exact != null) return exact;

    // Common dynamic copy. Values such as player names and numbers are kept
    // intact; only the surrounding product language changes.
    final patterns = <(RegExp, String Function(Match))>[
      (RegExp(r'^Target (\d+)$'), (m) => 'هدف ${m.group(1)}'),
      (RegExp(r'^Your turn — choose how many tricks you expect\.$'), (m) => 'نوبت تو — تعداد ترفندهای مورد انتظار را انتخاب کن.'),
      (RegExp(r'^Your turn — follow hearts ♥\.$'), (m) => 'نوبت تو — از قلب‌ها ♥ پیروی کن.'),
      (RegExp(r'^Your turn — follow diamonds ♦\.$'), (m) => 'نوبت تو — از خشت‌ها ♦ پیروی کن.'),
      (RegExp(r'^Your turn — follow spades ♠\.$'), (m) => 'نوبت تو — از پیک‌ها ♠ پیروی کن.'),
      (RegExp(r'^Your turn — follow clubs ♣\.$'), (m) => 'نوبت تو — از گشنیزها ♣ پیروی کن.'),
      (RegExp(r'^Your turn — follow (.+)\.$'), (m) => 'نوبت تو — از ${m.group(1)} پیروی کن.'),
      (RegExp(r'^Your turn — play a card\.$'), (m) => 'نوبت تو — یک کارت بازی کن.'),
      (RegExp(r'^Your turn — hearts are still locked\.$'), (m) => 'نوبت تو — قلب‌ها هنوز آزاد نشده‌اند.'),
      (RegExp(r'^Lead the 2♣ to start\.$'), (m) => 'برای شروع، ۲♣ را بازی کن.'),
      (RegExp(r'^Waiting for (.+) to bid…$'), (m) => 'در انتظار ${m.group(1)} برای اعلام پیشنهاد…'),
      (RegExp(r'^Round (\d+) / (\d+)$'), (m) => 'دور ${m.group(1)} / ${m.group(2)}'),
      (RegExp(r'^Round (\d+) · (.+) · (.+) · \+(\d+)$'), (m) => 'دور ${m.group(1)} · ${m.group(2)} · ${m.group(3)} · +${m.group(4)}'),
      (RegExp(r'^A checkout must finish on a double or bull\.$'), (m) => 'پایان بازی باید با دابل یا بول باشد.'),
      (RegExp(r'^Dart (\d+) of 3$'), (m) => 'دارت ${m.group(1)} از ۳'),
      (RegExp(r'^Count down from (\d+) to exactly zero · 3 darts per visit\.$'), (m) => 'از ${m.group(1)} تا صفر دقیق بشمار · در هر نوبت ۳ دارت.'),
      (RegExp(r'^🎯 Checkout: throw (\d+) to win!$'), (m) => '🎯 خروج: برای بردن ${m.group(1)} بزن!'),
      (RegExp(r'^⚠️ (\d+) busts from (\d+) — pick a smaller dart\.$'), (m) => '⚠️ امتیاز ${m.group(1)} از ${m.group(2)} بیشتر است — دارت کوچک‌تری انتخاب کن.'),
      (RegExp(r'^Throw for (\d+)$'), (m) => 'پرتاب ${m.group(1)}'),
      (RegExp(r'^Waiting for (.+) to throw…$'), (m) => 'در انتظار پرتاب ${m.group(1)}…'),
      (RegExp(r'^Last visit · (.+): (.+) \(total (\d+)\)$'), (m) => 'نوبت قبل · ${m.group(1)}: ${m.group(2)} (مجموع ${m.group(3)})'),
      (RegExp(r'^worth (\d+) pts$'), (m) => 'ارزش ${m.group(1)} امتیاز'),
      (RegExp(r'^(.+) · (.+) pts$'), (m) => '${m.group(1)} · ${m.group(2)} امتیاز'),
      (RegExp(r'^(.*) \(you\)$'), (m) => '${m.group(1)} (تو)'),
      (RegExp(r'^(\d+) of (\d+)$'), (m) => '${m.group(1)} از ${m.group(2)}'),
      (RegExp(r'^(\d+) cards$'), (m) => '${m.group(1)} کارت'),
      (RegExp(r'^(\d+) tricks$'), (m) => '${m.group(1)} ترفند'),
      (RegExp(r'^(\d+) cups$'), (m) => '${m.group(1)} جام'),
      (RegExp(r'^(\d+) balls$'), (m) => '${m.group(1)} توپ'),
      (RegExp(r'^(\d+) draw$'), (m) => '${m.group(1)} مهره برای کشیدن'),
      (RegExp(r'^(\d+) tiles$'), (m) => '${m.group(1)} مهره'),
      (RegExp(r'^(\d+) members$'), (m) => '${m.group(1)} عضو'),
      (RegExp(r'^(\d+) pending$'), (m) => '${m.group(1)} در انتظار'),
      (RegExp(r'^(\d+) reports$'), (m) => '${m.group(1)} گزارش'),
      (RegExp(r'^(\d+) open$'), (m) => '${m.group(1)} باز'),
      (RegExp(r'^(\d+) coins$'), (m) => '${m.group(1)} سکه'),
      (RegExp(r'^(\d+) pips$'), (m) => '${m.group(1)} پیپ'),
      (RegExp(r'^(\d+) rating$'), (m) => '${m.group(1)} امتیاز'),
      (RegExp(r'^(\d+) players · (.+)$'), (m) => '${m.group(1)} بازیکن · ${m.group(2)}'),
      (RegExp(r'^(\d+)–(\d+) players · teams$'), (m) => '${m.group(1)} تا ${m.group(2)} بازیکن · تیمی'),
      (RegExp(r'^(\d+)–(\d+) players$'), (m) => '${m.group(1)} تا ${m.group(2)} بازیکن'),
      (RegExp(r'^(\d+) friends · (\d+) online$'), (m) => '${m.group(1)} دوست · ${m.group(2)} نفر آنلاین'),
      (RegExp(r'^(.+) · (\d+) tiles$'), (m) => '${m.group(1)} · ${m.group(2)} مهره'),
      (RegExp(r'^(.+) · (\d+) balls$'), (m) => '${m.group(1)} · ${m.group(2)} توپ'),
      (RegExp(r'^(.+) · (\d+) players$'), (m) => '${m.group(1)} · ${m.group(2)} بازیکن'),
      (RegExp(r'^(.+) · stock (\d+)$'), (m) => '${m.group(1)} · موجودی ${m.group(2)}'),
      (RegExp(r'^(.+) · (\d+) coins$'), (m) => '${m.group(1)} · ${m.group(2)} سکه'),
      (RegExp(r'^(.+) · (\d+) pips$'), (m) => '${m.group(1)} · ${m.group(2)} پیپ'),
      (RegExp(r'^(.+) · (\d+) rating$'), (m) => '${m.group(1)} · ${m.group(2)} امتیاز'),
      (RegExp(r'^Rolled (\d+) · tap a glowing token$'), (m) => 'تاس ${m.group(1)} آمد · روی مهره درخشان بزن'),
      (RegExp(r'^Rolled (\d+) · tap a highlighted token$'), (m) => 'تاس ${m.group(1)} آمد · روی مهره مشخص‌شده بزن'),
      (RegExp(r'^Draw (\d+) cards\.$'), (m) => '${m.group(1)} کارت بکش.'),
      (RegExp(r'^Draw (\d+)$'), (m) => 'کشیدن ${m.group(1)}'),
      (RegExp(r'^(\d+) left$'), (m) => '${m.group(1)} باقی‌مانده'),
      (RegExp(r'^Your off · (\d+)/15 — tap to bear off$'), (m) => 'مهره‌های خارج‌شده تو · ${m.group(1)}/۱۵ — برای خارج کردن بزن'),
      (RegExp(r'^Your off · (\d+)/15$'), (m) => 'مهره‌های خارج‌شده تو · ${m.group(1)}/۱۵'),
      (RegExp(r'^Foe off · (\d+)/15$'), (m) => 'مهره‌های خارج‌شده حریف · ${m.group(1)}/۱۵'),
      (RegExp(r'^You · (\d+)$'), (m) => 'تو · ${m.group(1)}'),
      (RegExp(r'^Foe · (\d+)$'), (m) => 'حریف · ${m.group(1)}'),
      (RegExp(r'^You: (.+)$'), (m) => 'تو: ${m.group(1)}'),
      (RegExp(r'^Fleet (\d+)/5$'), (m) => 'ناوگان ${m.group(1)}/۵'),
      (RegExp(r'^Place ship (\d+) of 5 · (\d+) cells in a straight line\.$'), (m) => 'کشتی ${m.group(1)} از ۵ · ${m.group(2)} خانه در یک خط مستقیم.'),
      (RegExp(r'^Enemy fleet: (\d+)/5 ships placed\.$'), (m) => 'ناوگان دشمن: ${m.group(1)} از ۵ کشتی قرار گرفته است.'),
      (RegExp(r'^You posted (.+) — (\d+) of (\d+) players guessed\.$'), (m) => '${m.group(1)} را فرستادی — ${m.group(2)} از ${m.group(3)} بازیکن حدس زدند.'),
      (RegExp(r'^(.+) posted a clue — guess the word!$'), (m) => '${m.group(1)} سرنخی فرستاد — کلمه را حدس بزن!'),
      (RegExp(r'^(.+) takes this one\.$'), (m) => '${m.group(1)} این دور را می‌برد.'),
      (RegExp(r'^(.+) won$'), (m) => '${m.group(1)} برنده شد'),
      (RegExp(r'^(.+) is (a WEREWOLF|NOT a werewolf)\.$'), (m) => '${m.group(1)} ${m.group(2) == 'a WEREWOLF' ? 'گرگینه است' : 'گرگینه نیست'}.'),
      (RegExp(r'^(.+) was the impostor · the word was “(.+)”$'), (m) => '${m.group(1)} مظنون بود · کلمه «${m.group(2)}» بود'),
      (RegExp(r'^(.+) was “(.+)” — (.+)$'), (m) => '${m.group(1)} «${m.group(2)}» بود — ${m.group(3)}'),
      (RegExp(r'^(.+) is now your friend\.$'), (m) => '${m.group(1)} حالا دوستت است.'),
      (RegExp(r'^(.+) equipped!$'), (m) => '${m.group(1)} فعال شد!'),
      (RegExp(r'^(.+) equipped\.$'), (m) => '${m.group(1)} فعال شد.'),
      (RegExp(r'^(.+) unequipped\.$'), (m) => '${m.group(1)} غیرفعال شد.'),
      (RegExp(r'^(.+) was added to your inventory!$'), (m) => '${m.group(1)} به وسایل تو اضافه شد!'),
      (RegExp(r'^(.+) disabled\.$'), (m) => '${m.group(1)} غیرفعال شد.'),
      (RegExp(r'^(.+) activated\.$'), (m) => '${m.group(1)} فعال شد.'),
      (RegExp(r'^By (.+) · (.+)$'), (m) => 'توسط ${m.group(1)} · ${m.group(2)}'),
      (RegExp(r'^(\d+) earlier report\(s\) against this user \(latest: (.+) · (.+)\)$'), (m) => '${m.group(1)} گزارش قبلی درباره این کاربر (آخرین: ${m.group(2)} · ${m.group(3)})'),
      (RegExp(r'^Joined (.+) · last seen (.+)$'), (m) => 'عضویت: ${m.group(1)} · آخرین بازدید: ${m.group(2)}'),
      (RegExp(r'^@(.+) · Lv (\d+) · (\d+) coins$'), (m) => '@${m.group(1)} · سطح ${m.group(2)} · ${m.group(3)} سکه'),
      (RegExp(r'^Lv (\d+) · (\d+) coins$'), (m) => 'سطح ${m.group(1)} · ${m.group(2)} سکه'),
      (RegExp(r'^LV (\d+)$'), (m) => 'سطح ${m.group(1)}'),
      (RegExp(r'^(\d+) wins · (\d+) matches$'), (m) => '${m.group(1)} برد · ${m.group(2)} بازی'),
      (RegExp(r'^(\d+) coins \+ (\d+) bonus$'), (m) => '${m.group(1)} سکه + ${m.group(2)} جایزه'),
      (RegExp(r'^From: (.+)$'), (m) => 'از: ${m.group(1)}'),
      (RegExp(r'^To: (.+)$'), (m) => 'به: ${m.group(1)}'),
      (RegExp(r'^You own (\d+) in your inventory \(Free\)$'), (m) => '${m.group(1)} عدد در وسایلت داری (رایگان)'),
      (RegExp(r'^Your turn — tap enemy waters to fire\.$'), (m) => 'نوبت تو — برای شلیک روی آب‌های دشمن بزن.'),
      (RegExp(r'^Your turn — (.+)$'), (m) => 'نوبت تو — ${m.group(1)}'),
      (RegExp(r'^Your turn · (.+)$'), (m) => 'نوبت تو · ${m.group(1)}'),
      (RegExp(r'^The group, its members, and its chat will be removed for everyone\.$'), (m) => 'گروه، اعضا و گفتگوی آن برای همه حذف می‌شود.'),
      (RegExp(r'^You can be invited back at any time\.$'), (m) => 'هر زمان می‌توانی دوباره دعوت شوی.'),

      (RegExp(r'^Your group: solids · select one of your balls\.$'), (m) => 'گروه تو: توپ‌های ساده · یکی از توپ‌هایت را انتخاب کن.'),
      (RegExp(r'^Your group: stripes · select one of your balls\.$'), (m) => 'گروه تو: توپ‌های راه‌راه · یکی از توپ‌هایت را انتخاب کن.'),
      (RegExp(r'^Your group: (.+) · select one of your balls\.$'), (m) => 'گروه تو: ${m.group(1)} · یکی از توپ‌هایت را انتخاب کن.'),
      (RegExp(r'^(.+) scratched — turn passes\.$'), (m) => '${m.group(1)} خطا کرد — نوبت منتقل می‌شود.'),
      (RegExp(r'^(.+) pocketed (.+)\.$'), (m) => '${m.group(1)} ${m.group(2)} را پاکت کرد.'),
      (RegExp(r'^(.+) committed a foul — a coin returns\.$'), (m) => '${m.group(1)} خطا کرد — یک مهره برمی‌گردد.'),
      (RegExp(r'^(.+) covered the queen and pocketed (.+)\.$'), (m) => '${m.group(1)} ملکه را پوشش داد و ${m.group(2)} را پاکت کرد.'),
      (RegExp(r'^(.+) took the queen — cover needed\.$'), (m) => '${m.group(1)} ملکه را گرفت — نیاز به پوشش دارد.'),
      (RegExp(r'^Break and pocket (\d+)$'), (m) => 'ضربه شروع و پاکت کردن ${m.group(1)}'),
      (RegExp(r'^Pocket ball (\d+)$'), (m) => 'پاکت کردن توپ ${m.group(1)}'),
      (RegExp(r'^Strike · (\d+)/3 coins$'), (m) => 'ضربه · ${m.group(1)} از ۳ مهره'),
      (RegExp(r'^Night (\d+)$'), (m) => 'شب ${m.group(1)}'),
      (RegExp(r'^Seer vision: (.+) is a WEREWOLF\.$'), (m) => 'بینش پیشگو: ${m.group(1)} گرگینه است.'),
      (RegExp(r'^Seer vision: (.+) is NOT a werewolf\.$'), (m) => 'بینش پیشگو: ${m.group(1)} گرگینه نیست.'),
      (RegExp(r'^Draw · (.+)$'), (m) => 'مساوی · ${m.group(1)}'),
      (RegExp(r'^Fleet ready — waiting for the enemy…$'), (m) => 'ناوگان آماده است — در انتظار دشمن…'),
      (RegExp(r'^Waiting for (.+)…$'), (m) => 'در انتظار ${m.group(1)}…'),
      (RegExp(r'^Waiting for (.+) to roll…$'), (m) => 'در انتظار ${m.group(1)} برای پرتاب…'),
      (RegExp(r'^Turn: (.+)$'), (m) => 'نوبت: ${m.group(1)}'),
      (RegExp(r'^Reconnecting… \(attempt (\d+)\)$'), (m) => 'اتصال دوباره… (تلاش ${m.group(1)})'),
      (RegExp(r'^Page (\d+) of (\d+) · (\d+) total$'), (m) => 'صفحه ${m.group(1)} از ${m.group(2)} · مجموع ${m.group(3)}'),
      (RegExp(r'^Move (\d+)$'), (m) => 'حرکت ${m.group(1)}'),
      (RegExp(r'^First to (\d+)$'), (m) => 'اولین نفر تا ${m.group(1)}'),
      (RegExp(r'^Round (\d+) of (\d+)$'), (m) => 'دور ${m.group(1)} از ${m.group(2)}'),
      (RegExp(r'^You have (\d+) coins$'), (m) => '${m.group(1)} سکه داری'),
      (RegExp(r'^\+(\d+) XP$'), (m) => '+${m.group(1)} تجربه'),
      (RegExp(r'^\+(\d+) coins$'), (m) => '+${m.group(1)} سکه'),
      (RegExp(r'^\+(\d+) rating$'), (m) => '+${m.group(1)} امتیاز'),
      (RegExp(r'^-(\d+) rating$'), (m) => '-${m.group(1)} امتیاز'),
      (RegExp(r'^Play (.+)$'), (m) => 'بازی ${m.group(1)}'),
      (RegExp(r'^Open (.+)$'), (m) => 'باز کردن ${m.group(1)}'),
      (RegExp(r'^Hi, (.+)$'), (m) => 'سلام، ${m.group(1)}'),
      (RegExp(r'^Lvl (\d+)$'), (m) => 'سطح ${m.group(1)}'),
      (RegExp(r'^(\d+) players$'), (m) => '${m.group(1)} بازیکن'),
      (RegExp(r'^Waiting for the active player to (.+)…$'), (m) => 'در انتظار بازیکن فعال برای ${m.group(1)}…'),
      (RegExp(r'^Current visit: (.+)$'), (m) => 'نوبت فعلی: ${m.group(1)}'),
      (RegExp(r'^Your turn · (.+)$'), (m) => 'نوبت تو · ${m.group(1)}'),
      (RegExp(r'^You scored (\d+) points$'), (m) => '${m.group(1)} امتیاز گرفتی'),
      (RegExp(r'^(\d+) players · after 15 seconds, the table can start with a ready opponent\.$'), (m) => '${m.group(1)} بازیکن · پس از ۱۵ ثانیه، میز با یک حریف آماده شروع می‌شود.'),
      (RegExp(r'^(\d+) / 500 XP$'), (m) => '${m.group(1)} / ۵۰۰ تجربه'),
      (RegExp(r'^(\d+) XP total$'), (m) => 'مجموع تجربه: ${m.group(1)}'),
      (RegExp(r'^(\d+) online$'), (m) => '${m.group(1)} نفر آنلاین'),
      (RegExp(r'^(\d+) matches$'), (m) => '${m.group(1)} بازی'),
      (RegExp(r'^(\d+) total$'), (m) => 'مجموع ${m.group(1)}'),
      (RegExp(r'^(\d+) active$'), (m) => '${m.group(1)} فعال'),
      (RegExp(r'^(\d+) rewards$'), (m) => '${m.group(1)} جایزه'),
      (RegExp(r'^(\d+) players · teams$'), (m) => '${m.group(1)} بازیکن · تیمی'),
      (RegExp(r'^(.+) players$'), (m) => '${m.group(1)} بازیکن'),
      (RegExp(r'^(.+) · (.+) players$'), (m) => '${m.group(1)} · ${m.group(2)} بازیکن'),
      (RegExp(r'^(.+) scored (\d+) pts$'), (m) => '${m.group(1)} ${m.group(2)} امتیاز گرفت'),
      (RegExp(r'^(.+) · (\d+) pts$'), (m) => '${m.group(1)} · ${m.group(2)} امتیاز'),
      (RegExp(r'^Current: (.+)$'), (m) => 'فعلی: ${m.group(1)}'),
      (RegExp(r'^Match: (.+) · (.+) \((.+)\)$'), (m) => 'بازی: ${m.group(1)} · ${m.group(2)} (${m.group(3)})'),
      (RegExp(r'^Disable (.+)\?$'), (m) => 'غیرفعال کردن ${m.group(1)}؟'),
      (RegExp(r'^Edit (.+)$'), (m) => 'ویرایش ${m.group(1)}'),
      (RegExp(r'^Delete “(.+)”\?$'), (m) => 'حذف «${m.group(1)}»؟'),
      (RegExp(r'^Ranks (\d+)–(\d+)$'), (m) => 'رتبه‌های ${m.group(1)} تا ${m.group(2)}'),
      (RegExp(r'^Joined (.+) · last seen (.+)$'), (m) => 'عضویت: ${m.group(1)} · آخرین بازدید: ${m.group(2)}'),
      (RegExp(r'^Lv (\d+) · (\d+) coins$'), (m) => 'سطح ${m.group(1)} · ${m.group(2)} سکه'),
      (RegExp(r'^Lv (\d+)$'), (m) => 'سطح ${m.group(1)}'),
      (RegExp(r'^(.+) alive$'), (m) => '${m.group(1)} زنده'),
      (RegExp(r'^Waiting for (.+) to shoot…$'), (m) => 'در انتظار شلیک ${m.group(1)}…'),
      (RegExp(r'^Waiting for (.+) to take a shot…$'), (m) => 'در انتظار ضربه ${m.group(1)}…'),
      (RegExp(r'^Waiting for (.+) to finish this hole…$'), (m) => 'در انتظار ${m.group(1)} برای تمام کردن این حفره…'),
      (RegExp(r'^Waiting for (.+) to play…$'), (m) => 'در انتظار بازی ${m.group(1)}…'),
      (RegExp(r'^Waiting for (.+)…$'), (m) => 'در انتظار ${m.group(1)}…'),
      (RegExp(r'^Tap the target to aim, then loose\.$'), (m) => 'برای هدف‌گیری روی هدف بزن و سپس رها کن.'),
      (RegExp(r'^Aiming at (\d+) — wind (.+)$'), (m) => 'هدف‌گیری روی ${m.group(1)} — باد ${m.group(2)}'),
      (RegExp(r'^Wind (\d+) pushing (.+)$'), (m) => 'باد ${m.group(1)} به سمت ${m.group(2)}'),
      (RegExp(r'^(.+) off · (\d+)/15(.*)$'), (m) => '${m.group(1)} خارج‌شده · ${m.group(2)}/۱۵${m.group(3)}'),
      (RegExp(r'^You rallied for (.+)$'), (m) => 'تو برای ${m.group(1)} دعوت فرستادی'),
      (RegExp(r'^(.+) rallied for (.+)$'), (m) => '${m.group(1)} برای ${m.group(2)} دعوت فرستاد'),
      (RegExp(r'^Block (.+)\?$'), (m) => 'مسدود کردن ${m.group(1)}؟'),
      (RegExp(r'^Unfriend (.+)\?$'), (m) => 'حذف ${m.group(1)} از دوستان؟'),
      (RegExp(r'^(.+) will lose access to the group and its chat\.$'), (m) => '${m.group(1)} دسترسی به گروه و گفتگوی آن را از دست می‌دهد.'),
      (RegExp(r'^Hi, (.+)$'), (m) => 'سلام، ${m.group(1)}'),
      (RegExp(r'^Welcome back$'), (m) => 'خوش آمدی'),
    ];
    for (final (pattern, convert) in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return convert(match);
    }
    return text;
  }

  /// Static helper for services and shared widgets that do not keep an
  /// AppStrings instance. It intentionally defaults to English.
  static String translate(String text, Locale locale) => AppStrings(locale).translateText(text);

  String gameName(String id, [String? fallback]) => _gameNames[id]?[isPersian ? 'fa' : 'en'] ?? fallback ?? id;

  String categoryName(String value) => switch (value) {
        'board' => isPersian ? 'بردی' : 'Board',
        'cards' => isPersian ? 'کارتی' : 'Cards',
        'arcade' => isPersian ? 'آرکید' : 'Arcade',
        'party' => isPersian ? 'دورهمی' : 'Party',
        'sports' => isPersian ? 'ورزشی' : 'Sports',
        _ => translateText(value),
      };

  String modeName(String value) => switch (value) {
        'ranked' => ranked,
        'casual' => casual,
        'private' => isPersian ? 'خصوصی' : 'Private',
        _ => translateText(value),
      };

  String get appName => 'VibeTable';
  String get play => t('play');
  String get shop => t('shop');
  String get social => t('social');
  String get profile => t('profile');
  String get groups => t('groups');
  String get admin => t('admin');
  String get home => t('home');
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
  String get loading => t('loading');
  String get close => t('close');
  String get save => t('save');
  String get done => t('done');
  String get back => t('back');
  String get search => t('search');
  String get noResults => t('noResults');
  String get errorGeneric => t('errorGeneric');

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

  // Match/tutorial copy.
  String get yourTurn => t('yourTurn');
  String get matchFinished => t('matchFinished');
  String get matchCancelled => t('matchCancelled');
  String get live => t('live');
  String get makeYourMove => t('makeYourMove');
  String get turnClock => t('turnClock');
  String get openTableChat => t('openTableChat');
  String get howToPlay => t('howToPlay');
  String get leaveTable => t('leaveTable');
  String get refreshMatch => t('refreshMatch');
  String get resignMatch => t('resignMatch');
  String get tutorialGoal => t('tutorialGoal');
  String get tutorialControls => t('tutorialControls');
  String get tutorialClock => t('tutorialClock');
  String get tutorialGotIt => t('tutorialGotIt');
  String get tutorialTitle => t('tutorialTitle');
  String get timeoutRule => t('timeoutRule');

  // Admin & Staff Hub
  String get adminConsole => t('adminConsole');
  String get adminStaffHub => t('adminStaffHub');
  String get adminStaffSubtitle => t('adminStaffSubtitle');
  String get adminStaffEntry => t('adminStaffEntry');
  String get developmentPassword => t('developmentPassword');
  String get username => t('username');
  String get staffRoleHint => t('staffRoleHint');
  String get enterAdminPanel => t('enterAdminPanel');
  String get openConsole => t('openConsole');

  static const _values = <String, Map<String, String>>{
    'play': {'en': 'Play', 'fa': 'بازی'},
    'shop': {'en': 'Shop', 'fa': 'فروشگاه'},
    'social': {'en': 'Social', 'fa': 'اجتماعی'},
    'profile': {'en': 'Profile', 'fa': 'پروفایل'},
    'groups': {'en': 'Groups', 'fa': 'گروه‌ها'},
    'admin': {'en': 'Admin', 'fa': 'مدیریت'},
    'home': {'en': 'Home', 'fa': 'خانه'},
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
    'loading': {'en': 'Loading…', 'fa': 'در حال بارگذاری…'},
    'close': {'en': 'Close', 'fa': 'بستن'},
    'save': {'en': 'Save', 'fa': 'ذخیره'},
    'done': {'en': 'Done', 'fa': 'انجام شد'},
    'back': {'en': 'Back', 'fa': 'بازگشت'},
    'search': {'en': 'Search', 'fa': 'جست‌وجو'},
    'noResults': {'en': 'No results found', 'fa': 'نتیجه‌ای پیدا نشد'},
    'errorGeneric': {'en': 'Something went wrong. Please try again.', 'fa': 'مشکلی پیش آمد. دوباره تلاش کن.'},
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
    'adminStaffEntry': {'en': 'Admin / staff entry', 'fa': 'ورود مدیر / کارکنان'},
    'developmentPassword': {'en': 'Development password', 'fa': 'رمز توسعه'},
    'username': {'en': 'Username', 'fa': 'نام کاربری'},
    'staffRoleHint': {'en': 'Only an account with admin or moderator role can enter the console.', 'fa': 'فقط حساب‌های مدیر یا ناظر می‌توانند وارد پنل شوند.'},
    'enterAdminPanel': {'en': 'Enter admin panel', 'fa': 'ورود به پنل مدیریت'},
    'openConsole': {'en': 'Open Console', 'fa': 'ورود به پنل مدیریت'},
    'yourTurn': {'en': 'Your turn', 'fa': 'نوبت تو'},
    'matchFinished': {'en': 'Match finished', 'fa': 'بازی تمام شد'},
    'matchCancelled': {'en': 'Match cancelled', 'fa': 'بازی لغو شد'},
    'live': {'en': 'Live', 'fa': 'زنده'},
    'makeYourMove': {'en': 'Make your move', 'fa': 'حرکتت را انجام بده'},
    'turnClock': {'en': 'Turn clock', 'fa': 'زمان نوبت'},
    'openTableChat': {'en': 'Open table chat', 'fa': 'باز کردن گفتگوی میز'},
    'howToPlay': {'en': 'How to play & rules', 'fa': 'روش بازی و قوانین'},
    'leaveTable': {'en': 'Leave table', 'fa': 'ترک میز'},
    'refreshMatch': {'en': 'Refresh match', 'fa': 'به‌روزرسانی بازی'},
    'resignMatch': {'en': 'Resign match', 'fa': 'تسلیم شدن'},
    'tutorialGoal': {'en': 'Goal', 'fa': 'هدف'},
    'tutorialControls': {'en': 'Controls', 'fa': 'کنترل‌ها'},
    'tutorialClock': {'en': 'Every turn has a visible clock. Three missed turns in a row forfeit the match.', 'fa': 'هر نوبت زمان مشخص دارد. سه نوبت از دست‌رفته پیاپی باعث باخت می‌شود.'},
    'tutorialGotIt': {'en': 'Got it', 'fa': 'متوجه شدم'},
    'tutorialTitle': {'en': 'Quick table guide', 'fa': 'راهنمای کوتاه میز'},
    'timeoutRule': {'en': 'Three consecutive timeouts = forfeit', 'fa': 'سه پایان زمان پیاپی = باخت'},
  };

  static const _gameNames = <String, Map<String, String>>{
    'ocho': {'en': 'Ocho', 'fa': 'اُچو'},
    'pool_8_ball': {'en': 'Pool 8-ball', 'fa': 'بیلیارد هشت‌توپ'},
    'ludo': {'en': 'Ludo', 'fa': 'منچ'},
    'werewolf': {'en': 'Werewolf', 'fa': 'گرگینه'},
    'chess': {'en': 'Chess', 'fa': 'شطرنج'},
    'four_in_a_row': {'en': '4 in a Row', 'fa': 'چهارتایی'},
    'dice_party': {'en': 'Dice Party', 'fa': 'مهمانی تاس'},
    'carrom': {'en': 'Carrom', 'fa': 'کاروم'},
    'bingo': {'en': 'Bingo', 'fa': 'بینگو'},
    'dominoes': {'en': 'Dominoes', 'fa': 'دومینو'},
    'backgammon': {'en': 'Backgammon', 'fa': 'تخته‌نرد'},
    'checkers': {'en': 'Checkers', 'fa': 'چکرز'},
    'mini_golf': {'en': 'Mini Golf', 'fa': 'مینی‌گلف'},
    'table_soccer': {'en': 'Table Soccer', 'fa': 'فوتبال‌دستی'},
    'archery': {'en': 'Archery', 'fa': 'تیراندازی'},
    'bowling': {'en': 'Bowling', 'fa': 'بولینگ'},
    'darts': {'en': 'Darts', 'fa': 'دارت'},
    'sea_battle': {'en': 'Sea Battle', 'fa': 'نبرد دریایی'},
    'mancala': {'en': 'Mancala', 'fa': 'مانکالا'},
    'hearts': {'en': 'Hearts', 'fa': 'قلب‌ها'},
    'spades': {'en': 'Spades', 'fa': 'پیک'},
    'sketch_guess': {'en': 'Sketch & Guess', 'fa': 'نقاشی و حدس'},
    'trivia_battle': {'en': 'Trivia Battle', 'fa': 'نبرد اطلاعات'},
    'emoji_charades': {'en': 'Emoji Charades', 'fa': 'پانتومیم ایموجی'},
    'word_chain': {'en': 'Word Chain', 'fa': 'زنجیره کلمات'},
    'memory_race': {'en': 'Memory Race', 'fa': 'مسابقه حافظه'},
    'impostor_light': {'en': 'Impostor Light', 'fa': 'مظنون'},
    'quick_challenges': {'en': 'Quick Challenges', 'fa': 'چالش‌های سریع'},
  };

  /// Raw English copy used by legacy board widgets and admin panels. New
  /// screens should prefer a key getter above, but this table keeps older
  /// widgets fully locale-aware without duplicating layout code.
  static const _copy = <String, String>{
    'No admin actions logged yet.': 'هنوز فعالیت مدیری ثبت نشده است.',
    'Before': 'قبل', 'After': 'بعد', 'Close': 'بستن', 'Edit': 'ویرایش', 'Save': 'ذخیره',
    'No mobile board UI — disable until shipped': 'رابط بازی موبایل آماده نیست — تا زمان انتشار غیرفعال کنید',
    'Off  ': 'خاموش  ', 'All': 'همه', 'All clear. No reports here.': 'همه‌چیز مرتب است؛ گزارشی وجود ندارد.',
    'Reporter': 'گزارش‌دهنده', 'Reported': 'گزارش‌شده', 'Resolution': 'نتیجه رسیدگی',
    'investigating': 'در حال بررسی', 'resolved': 'حل‌شده', 'dismissed': 'ردشده',
    'No action on user': 'اقدامی برای کاربر انجام نشود', 'Send warning': 'ارسال اخطار',
    'Apply resolution': 'اعمال نتیجه رسیدگی', 'Activity & Trends': 'فعالیت و روندها',
    'Recent live matches': 'بازی‌های زنده اخیر', 'No matches recorded yet.': 'هنوز بازی‌ای ثبت نشده است.',
    'Quick Navigation': 'دسترسی سریع', 'Users': 'کاربران', 'Reports': 'گزارش‌ها', 'Shop': 'فروشگاه',
    'Cosmetics': 'تزئینات', 'Games': 'بازی‌ها', 'Seasons': 'فصل‌ها', 'Ranked rewards': 'جوایز رتبه‌ای',
    'Audit Log': 'گزارش فعالیت', 'History': 'تاریخچه', 'Active users': 'کاربران فعال',
    'Online today': 'آنلاین امروز', 'Live matches': 'بازی‌های زنده', 'Matches today': 'بازی‌های امروز',
    'Open reports': 'گزارش‌های باز', 'New users (7d)': 'کاربران جدید (۷ روز)',
    'Players': 'بازیکنان', 'Overview unavailable': 'نمای کلی در دسترس نیست', 'Refresh telemetry': 'به‌روزرسانی آمار زنده',
    'Disable': 'غیرفعال کردن', 'Players will no longer see this game or be able to start new matches.': 'بازیکنان دیگر این بازی را نمی‌بینند و نمی‌توانند بازی جدیدی شروع کنند.',
    'Display name': 'نام نمایشی', 'Min players': 'حداقل بازیکن', 'Max players': 'حداکثر بازیکن',
    'Accent color (#RRGGBB)': 'رنگ تأکیدی (#RRGGBB)', 'Icon key': 'کلید آیکن', 'Status': 'وضعیت',
    'Moderation action': 'اقدام مدیریتی', 'Resolution note': 'یادداشت رسیدگی', 'Name': 'نام',
    'Starts (YYYY-MM-DD)': 'شروع (YYYY-MM-DD)', 'Ends (YYYY-MM-DD)': 'پایان (YYYY-MM-DD)',
    'Delete reward': 'حذف جایزه', 'Min rank': 'حداقل رتبه', 'Max rank': 'حداکثر رتبه',
    'Shop item ID (optional)': 'شناسه آیتم فروشگاه (اختیاری)', 'SKU': 'SKU', 'Description': 'توضیحات',
    'Category': 'دسته‌بندی', 'Asset key': 'کلید دارایی', 'Stock (empty = unlimited)': 'موجودی (خالی = نامحدود)',
    'Search username, name, phone, email…': 'جست‌وجوی نام کاربری، نام، تلفن یا ایمیل…',
    'Reason (shown to the user)': 'دلیل (به کاربر نمایش داده می‌شود)', 'Violation of community rules': 'نقض قوانین جامعه',
    'Reason (required)': 'دلیل (الزامی)', 'Coins ±': 'سکه ±', 'Pips ±': 'پیپ ±',
    'Leave the table?': 'میز را ترک می‌کنی؟', 'Stay': 'ماندن', 'Leave': 'ترک کردن',
    'Resign this match?': 'از این بازی تسلیم می‌شوی؟', 'Keep playing': 'ادامه بازی', 'Resign': 'تسلیم شدن',
    'Leave matchmaking?': 'صف پیدا کردن حریف را ترک می‌کنی؟', 'Leave queue': 'ترک صف',
    'Leave table': 'ترک میز', 'How to play & rules': 'روش بازی و قوانین', 'Refresh match': 'به‌روزرسانی بازی',
    'Resign match': 'تسلیم شدن', 'Loading your table…': 'در حال بارگذاری میز…',
    'We could not load this table.': 'بارگذاری این میز ممکن نشد.', 'Connecting to the latest confirmed match state.': 'در حال اتصال به آخرین وضعیت تأییدشده بازی.',
    'Try again': 'تلاش دوباره', 'Sending move…': 'در حال ارسال حرکت…', 'Retry': 'تلاش دوباره',
    'Live connection is healthy': 'اتصال زنده سالم است', 'Connecting to the live table…': 'در حال اتصال به میز زنده…',
    'Reconnecting… tap to retry now': 'در حال اتصال دوباره… برای تلاش فوری ضربه بزن', 'Live updates offline · tap to retry': 'به‌روزرسانی زنده قطع است · برای تلاش دوباره ضربه بزن',
    'Match finished': 'بازی تمام شد', 'Match cancelled': 'بازی لغو شد', 'Waiting for the table state': 'در انتظار وضعیت میز',
    'Your turn': 'نوبت تو', 'Make your move': 'حرکتت را انجام بده', 'Open table chat': 'باز کردن گفتگوی میز',
    'Result saved · rewards are being settled. This card will update automatically.': 'نتیجه ذخیره شد · جوایز در حال تسویه است. این کارت خودکار به‌روز می‌شود.',
    'Back to games': 'بازگشت به بازی‌ها', 'Play again': 'بازی دوباره', 'Rewards added to your profile': 'جوایز به پروفایلت اضافه شد',
    'This match was cancelled after too long without a move. No rating changed.': 'این بازی پس از مدت طولانی بدون حرکت لغو شد. رتبه تغییری نکرد.',
    'Match complete': 'بازی کامل شد', 'the other player': 'بازیکن دیگر', 'Type your word': 'کلمه‌ات را بنویس',
    'Build the chain': 'زنجیره را بساز', 'This table is complete.': 'این میز کامل شده است.',
    'Add a word that starts with the required letter.': 'کلمه‌ای بنویس که با حرف لازم شروع شود.',
    'Waiting for the other player to play…': 'در انتظار حرکت بازیکن دیگر…', 'Type your guess': 'حدست را بنویس',
    'Roll': 'پرتاب', 'Pass': 'رد کردن', 'You': 'تو', 'Foe': 'حریف', 'Power': 'قدرت', 'Miss': 'خطا',
    'Declare foul': 'اعلام خطا', 'Call the queen': 'ملکه را صدا بزن', 'Pocket her with one of your coins to cover': 'ملکه را با یکی از مهره‌هایت پوشش بده',
    'Board clear': 'تخته خالی شد', 'SELECT COINS': 'انتخاب مهره‌ها', 'TARGET COINS': 'هدف‌گیری مهره‌ها', 'Called numbers': 'شماره‌های اعلام‌شده',
    'Your roll — up to 10 pins standing': 'پرتاب تو — حداکثر ۱۰ پین باقی‌مانده', 'Shoot': 'شوت', 'Aim': 'هدف‌گیری',
    'Left': 'چپ', 'Right': 'راست', 'Center': 'مرکز', 'Single': 'تکی', 'Double': 'دوبل', 'Triple': 'سه‌تایی',
    'Clear': 'پاک کردن', 'Submit sketch': 'ارسال نقاشی', 'Submit guess': 'ارسال حدس', 'Draw this:': 'این را بکش:',
    'You will get the first guess when the sketch is submitted.': 'پس از ارسال نقاشی، اولین حدس را دریافت می‌کنی.',
    'All prompts are complete. Highest score wins.': 'همه موضوع‌ها تمام شد. بیشترین امتیاز برنده است.',
    'Table Soccer': 'فوتبال‌دستی', 'Trivia Battle': 'نبرد اطلاعات', 'First to': 'اولین نفر تا',
    'Aim your dart': 'دارتت را هدف بگیر', 'Your role': 'نقش تو', 'YOUR ROLE': 'نقش تو',
    'you': 'تو', 'your vote': 'رأی تو', 'out': 'حذف‌شده', 'role hidden': 'نقش مخفی است',
    'Wait through the night': 'تا پایان شب صبر کن', 'Submit night action': 'ثبت اقدام شب', 'Cast vote': 'ثبت رأی',
    'Draw number': 'کشیدن شماره', 'Waiting for turn': 'در انتظار نوبت', 'Bingo': 'بینگو', 'Archery': 'تیراندازی',
    'Bowling': 'بولینگ', 'Carrom': 'کاروم', 'Checkers': 'چکرز', 'Chess': 'شطرنج', 'Backgammon': 'تخته‌نرد',
    'Werewolf': 'گرگینه', 'Dominoes': 'دومینو', 'Ocho': 'اُچو', 'Sea Battle': 'نبرد دریایی',
    'Roll dice': 'پرتاب تاس', 'Place on the left': 'قرار دادن در چپ', 'Place on the right': 'قرار دادن در راست', 'Draw a tile': 'کشیدن مهره',
    'Choose the opening color': 'انتخاب رنگ شروع', 'Pocket the queen': 'گرفتن ملکه', 'Cover the queen': 'پوشش ملکه', 'Strike': 'ضربه',
    'No items in this category': 'آیتمی در این دسته وجود ندارد', 'Browse Shop': 'مشاهده فروشگاه',
    'Search conversations': 'جست‌وجوی گفتگوها', 'Write a message': 'پیامی بنویس', 'Search players': 'جست‌وجوی بازیکنان',
    'Group name': 'نام گروه', 'Friday night champions': 'قهرمان‌های شب جمعه', 'Description (optional)': 'توضیحات (اختیاری)',
    'What is this group about?': 'این گروه درباره چیست؟', 'Invite to game': 'دعوت به بازی', 'Chat': 'گفتگو',
    'Setting up your table…': 'در حال آماده‌سازی میزت…', 'We could not open VibeTable': 'باز کردن VibeTable ممکن نشد',
    '4 in a Row': 'چهارتایی',
    'FEATURED': 'ویژه',
    'Play now': 'همین حالا بازی کن',
    'TEAMS': 'تیمی',
    'Accept': 'پذیرش',
    'Activate': 'فعال‌سازی',
    'Active in shop': 'فعال در فروشگاه',
    'Add': 'افزودن',
    'Add reward': 'افزودن جایزه',
    'Added': 'اضافه شد',
    'Adjust wallet': 'تنظیم کیف پول',
    'Apply': 'اعمال',
    'Ask an admin to invite friends': 'از مدیر برای دعوت دوستان کمک بگیر',
    'Auto': 'خودکار',
    'Avoid hearts and the Q♠ — lowest score wins.': 'از قلب‌ها و بی‌بی پیک دوری کن — کمترین امتیاز برنده است.',
    'Ban': 'مسدود کردن',
    'Ban user': 'مسدود کردن کاربر',
    'Block': 'مسدود کردن',
    'Call Ocho': 'اعلام اُچو',
    'Call Ocho?': 'اُچو را اعلام می‌کنی؟',
    'Cancel': 'لغو',
    'Challenge': 'چالش',
    'Change role': 'تغییر نقش',
    'Clear selection': 'پاک کردن انتخاب',
    'Create': 'ایجاد',
    'Create a group': 'ایجاد گروه',
    'Decline': 'رد کردن',
    'Delete': 'حذف',
    'Delete forever': 'حذف برای همیشه',
    'Delete reward?': 'جایزه حذف شود؟',
    'Delete season?': 'فصل حذف شود؟',
    'Delete…': 'حذف…',
    'Deactivate': 'غیرفعال کردن',
    'Disband group': 'حذف گروه',
    'Edit season': 'ویرایش فصل',
    'Everyone you know is already here. Search above to find more players.': 'همه آشنایانت اینجا هستند. برای یافتن بازیکنان بیشتر جست‌وجو کن.',
    'Finish & pay rewards': 'پایان و پرداخت جوایز',
    'Finish season?': 'فصل تمام شود؟',
    'Friends join instantly. Anyone you find by search can be added too.': 'دوستان فوراً اضافه می‌شوند. هر بازیکنی را با جست‌وجو پیدا کنی می‌توانی اضافه کنی.',
    'Giftable': 'قابل هدیه',
    'Group': 'گروه',
    'Higher': 'بیشتر',
    'Invite friends': 'دعوت دوستان',
    'Invite to group': 'دعوت به گروه',
    'Join queue': 'ورود به صف',
    'Leave group': 'ترک گروه',
    'Limited': 'محدود',
    'Lower': 'کمتر',
    'Members': 'اعضا',
    'new': 'جدید',
    'New item': 'آیتم جدید',
    'New season': 'فصل جدید',
    'No cards': 'بدون کارت',
    'No friends yet — you can invite people after creating the group.': 'هنوز دوستی نداری — پس از ساخت گروه می‌توانی افراد را دعوت کنی.',
    'No games fit this party size right now.': 'فعلاً بازی مناسبی برای این تعداد نفر پیدا نشد.',
    'No matches played yet.': 'هنوز بازی‌ای انجام نشده است.',
    'No rewards configured yet.': 'هنوز جایزه‌ای تنظیم نشده است.',
    'No seasons yet.': 'هنوز فصلی وجود ندارد.',
    'No shop items yet.': 'هنوز آیتم فروشگاهی وجود ندارد.',
    'No telemetry data available for this timeframe.': 'برای این بازه داده آماری در دسترس نیست.',
    'No users match these filters.': 'کاربری با این فیلترها پیدا نشد.',
    'On the table': 'روی میز',
    'Only scheduled seasons can be deleted.': 'فقط فصل‌های زمان‌بندی‌شده قابل حذف هستند.',
    'Outer 25': '۲۵ بیرونی',
    'Pass · block the round': 'رد کن · دور را مسدود کن',
    'Pick a game — an invite lands in the chat and you jump into the queue.': 'یک بازی انتخاب کن — دعوت در گفتگو می‌آید و وارد صف می‌شوی.',
    'Play together': 'با هم بازی کنید',
    'Play without calling': 'بدون اعلام بازی کن',
    'Pocket': 'وارد پاکت کن',
    'Previous round revealed · next question is live.': 'دور قبل آشکار شد · سؤال بعدی آماده است.',
    'Queue time': 'زمان صف',
    'Queue up for the same game to land at one table.': 'برای همان بازی وارد صف شوید تا کنار هم بنشینید.',
    'Rank rewards will be paid out to winners. This cannot be undone.': 'جوایز رتبه‌ای به برندگان پرداخت می‌شود. این کار قابل بازگشت نیست.',
    'Recent matches': 'بازی‌های اخیر',
    'Recent rolls': 'پرتاب‌های اخیر',
    'Remove': 'حذف کردن',
    'Remove member?': 'عضو حذف شود؟',
    'Rewards': 'جوایز',
    'Role': 'نقش',
    'Search results': 'نتایج جست‌وجو',
    'Showing the saved game catalog while we reconnect.': 'تا زمان اتصال دوباره، فهرست ذخیره‌شده بازی‌ها نمایش داده می‌شود.',
    'Sign out': 'خروج',
    'Sign out?': 'خارج می‌شوی؟',
    'Strokes': 'ضربه‌ها',
    'Standings': 'جدول رتبه‌ها',
    'Staff access required': 'نیازمند دسترسی کارکنان',
    'The currently active season (if any) will be finished first.': 'فصل فعال فعلی، در صورت وجود، ابتدا تمام می‌شود.',
    'The drawer is sketching a secret prompt…': 'نقاش در حال کشیدن موضوع مخفی است…',
    'The match will keep running while you are away. You can return from your active matches later.': 'بازی در نبودت ادامه دارد. بعداً از بازی‌های فعال برگرد.',
    'The opening tile will appear here': 'مهره شروع اینجا نمایش داده می‌شود',
    'This console is only available to authorized moderators and admins.': 'این پنل فقط برای مدیران و ناظران مجاز است.',
    'Top games by matches': 'بازی‌های برتر بر اساس تعداد بازی',
    'Top players': 'بازیکنان برتر',
    'TOTAL': 'مجموع',
    'Unban': 'رفع مسدودی',
    'Unfriend': 'حذف از دوستان',
    'Use for a foul or a missed shot': 'برای خطا یا ضربه ناموفق استفاده کن',
    'User moderation actions require an admin account.': 'اقدامات نظارتی کاربر به حساب مدیر نیاز دارد.',
    'Waiting for the active player to finish this hole…': 'در انتظار بازیکن فعال برای تمام کردن این حفره…',
    'Waiting for the active player to shoot…': 'در انتظار شلیک بازیکن فعال…',
    'Waiting for the active player…': 'در انتظار بازیکن فعال…',
    'Waiting for the other player to take a shot…': 'در انتظار ضربه بازیکن دیگر…',
    'Wallet': 'کیف پول',
    'Your fleet': 'ناوگان تو',
    'Your hand': 'دست تو',
    'Bidding': 'اعلام پیشنهاد',
    'How many tricks will you take?': 'چند ترفند می‌گیری؟',
    'Hearts': 'قلب‌ها',
    'Spades': 'پیک',
    'Your place in the queue will be cancelled.': 'جای تو در صف لغو می‌شود.',
    'YOUR SECRET WORD': 'کلمه مخفی تو',
    'You can sign back in whenever you are ready.': 'هر وقت آماده بودی می‌توانی دوباره وارد شوی.',
    'You will have one card after this play. Call Ocho to avoid the two-card penalty.': 'پس از این بازی یک کارت خواهی داشت. برای جلوگیری از جریمه دو کارتی، اُچو را اعلام کن.',
    'Your dominoes are hidden until the table syncs.': 'مهره‌های دومینویت تا همگام‌سازی میز مخفی است.',
    'VibeTable': 'VibeTable',
    'Dice Party': 'مهمانی تاس',
    'Darts 301': 'دارت ۳۰۱',
    'Final': 'نهایی',
    'Emoji Charades': 'پانتومیم ایموجی',
    'Impostor Light': 'مظنون',
    'Ludo': 'منچ',
    'Mancala': 'مانکالا',
    'Mini Golf': 'مینی‌گلف',
    'Pool 8-ball': 'بیلیارد هشت‌توپ',
    'Quick Challenges': 'چالش‌های سریع',
    'Sketch & Guess': 'نقاشی و حدس',
    'No games match that search': 'هیچ بازی‌ای با این جست‌وجو پیدا نشد',
    'No games are available right now': 'فعلاً بازی‌ای در دسترس نیست',
    'Try another name or browse every category.': 'نام دیگری را امتحان کن یا همه دسته‌ها را ببین',
    'Pull to refresh and try again.': 'برای تازه‌سازی بکش و دوباره امتحان کن',
    'Welcome back': 'خوش آمدی',
    'Your next table is ready': 'میز بعدی‌ات آماده است',
    'New\ngroup': 'گروه\nجدید',
    '🎮 Game invite': '🎮 دعوت بازی',
    'Could not load groups. Tap to retry.': 'بارگذاری گروه‌ها ممکن نشد. برای تلاش دوباره بزن.',
    'A home base for your table — with its own chat and game nights.': 'خانه‌ای برای میزت، با گفتگوی اختصاصی و شب‌های بازی.',
    'Activate season?': 'فصل فعال شود؟',
    'BREAK SHOT': 'ضربه شروع',
    'Bull 50': 'بول ۵۰',
    'Cue-ball scratch': 'خطای توپ سفید',
    'Deactivate removes it from the shop but keeps player inventories intact (recommended). ': 'غیرفعال‌سازی آن را از فروشگاه حذف می‌کند اما وسایل بازیکنان را نگه می‌دارد (پیشنهاد می‌شود).',
    'HOLE': 'حفره',
    'PLAYER': 'بازیکن',
    'Promote pawn to': 'ارتقای سرباز به',
    'Resigning counts as a loss and your opponents win the table. This cannot be undone.': 'تسلیم شدن باخت محسوب می‌شود و حریفان برنده می‌شوند. این کار قابل بازگشت نیست.',
    'Sow stones around the board — landing your last stone in your store earns another turn.': 'مهره‌ها را در خانه‌ها پخش کن — اگر آخرین مهره در خانه خودت بیفتد، دوباره نوبت می‌گیری.',
    'The answer order is locked one player at a time so nobody can see another player\'s choice.': 'ترتیب پاسخ‌ها برای هر بازیکن قفل است تا انتخاب دیگران دیده نشود.',
    'grey = ship · red = hit': 'خاکستری = کشتی · قرمز = برخورد',
    '🃏 HIGH OR LOW': '🃏 بالا یا پایین',
    '🎯 BULLSEYE STOP': '🎯 توقف روی مرکز هدف',
    '🥤 LUCKY CUPS': '🥤 جام‌های شانسی',
    'Teams': 'تیمی',
    'No featured tables': 'هنوز میز ویژه‌ای نیست',
    'New tables will appear here soon. Pull to refresh.': 'به‌زودی میزهای جدید اینجا می‌آیند. برای تازه‌سازی بکش.',
    'All statuses': 'همه وضعیت‌ها',
    'All roles': 'همه نقش‌ها',
    'Players today': 'بازیکنان امروز',
    'Games live': 'بازی‌های زنده',
    'Revenue (paid)': 'درآمد (پرداخت‌شده)',
    'Suspended': 'معلق‌شده',
    'New users': 'کاربران جدید',
    'Matches': 'بازی‌ها',
    'Active players': 'بازیکنان فعال',
    'Finish': 'پایان',
    'draw': 'کشیدن',
    'Place left': 'قرار دادن در چپ',
    'Place right': 'قرار دادن در راست',
    'left': 'چپ',
    'right': 'راست',
    'Human players': 'بازیکنان انسانی',
    'Synchronize the game room': 'همگام‌سازی اتاق بازی',
    'Hole': 'حفره',
    'Round': 'دور',
    'Season leaderboard': 'جدول رتبه‌بندی فصل',
    'Dashboard': 'داشبورد',
    'History unavailable': 'تاریخچه در دسترس نیست',
    'Chat is unavailable': 'گفتگو در دسترس نیست',
    'We could not load your conversations.': 'بارگذاری گفتگوها ممکن نشد.',
    'No conversations yet': 'هنوز گفتگویی نیست',
    'Open a friend or a group and say hello to start chatting.': 'برای شروع گفتگو، یک دوست یا گروه را باز کن و سلام کن.',
    'No matches': 'نتیجه‌ای نیست',
    'Try a different search.': 'جست‌وجوی دیگری را امتحان کن.',
    'No messages yet': 'هنوز پیامی نیست',
    'Say hello and start the conversation.': 'سلام کن و گفتگو را شروع کن.',
    'Group unavailable': 'گروه در دسترس نیست',
    'We could not load this group.': 'بارگذاری این گروه ممکن نشد.',
    'Invite': 'دعوت',
    'Play': 'بازی',
    'Owner': 'مالک',
    'Online now': 'همین حالا آنلاین',
    'Wants to be your friend': 'می‌خواهد دوستت باشد',
    'Request sent · waiting': 'درخواست ارسال شد · در انتظار پاسخ',
    'Friends are offline': 'دوستان آفلاین هستند',
    'Pull down to try again.': 'برای تلاش دوباره به پایین بکش.',
    'Your table is more fun with friends': 'میزت با دوستان سرگرم‌کننده‌تر است',
    'Search for a player above and send the first invite.': 'بالا یک بازیکن پیدا کن و اولین دعوت را بفرست.',
    'Conversation': 'گفتگو',
    'Set up your table': 'میزت را آماده کن',
    'Choose a room style and player count. We will find a fair table for you.': 'سبک اتاق و تعداد بازیکنان را انتخاب کن. میز منصفانه‌ای برایت پیدا می‌کنیم.',
    'XP': 'تجربه',
    'Insufficient balance': 'موجودی کافی نیست',
    'Done': 'انجام شد',
    'Game invite': 'دعوت بازی',
    'No card left.': 'کارتی باقی نمانده است.',
    'No cards left.': 'کارتی باقی نمانده است.',
    'Your hand is hidden until the deal reaches you.': 'دستت تا رسیدن نوبت پخش مخفی است.',
    'No wind — aim dead center.': 'باد نیست — دقیقاً وسط را هدف بگیر.',
    'The range is quiet.': 'محدوده آرام است.',
    'All arrows spent.': 'همه تیرها استفاده شد.',
    'Tap the target to aim, then loose.': 'برای هدف‌گیری روی هدف بزن و سپس رها کن.',
    'Roll the dice': 'پرتاب تاس',
    'Waiting…': 'در انتظار…',
    'STOP!': 'ایست!',
    'Card drawn — play it or pass': 'کارت کشیده شد — بازی کن یا رد کن',
    'Draw card': 'کشیدن کارت',
    'Choose a color': 'انتخاب رنگ',
    'No move · roll again': 'حرکتی نیست · دوباره تاس بینداز',
    'Your move': 'حرکت تو',
    'Select a target': 'یک هدف انتخاب کن',
    'Your board': 'تخته تو',
    'Opponent board': 'تخته حریف',
    'Fire': 'شلیک',
    'Submit': 'ثبت',
    'Answer': 'پاسخ',
    'Choose a clue': 'یک سرنخ انتخاب کن',
    'Guess': 'حدس',
    'Vote': 'رأی',
    'No items yet': 'هنوز آیتمی نیست',
    'No friends yet': 'هنوز دوستی نیست',
    'No data available': 'داده‌ای در دسترس نیست',
    'Start a table now': 'شروع فوری میز',
    'Complete the table': 'تکمیل میز',
    'No human table yet. A ready opponent will complete the table.': 'هنوز میز انسانی آماده نیست. یک حریف آماده میز را تکمیل می‌کند.',
    'A ready opponent is available': 'یک حریف آماده در دسترس است',
    'Waiting for the enemy…': 'در انتظار دشمن…', 'Waiting for the next player…': 'در انتظار بازیکن بعدی…',
    'red': 'قرمز', 'yellow': 'زرد', 'green': 'سبز', 'blue': 'آبی', 'wild': 'وحشی', 'solids': 'ساده', 'stripes': 'راه‌راه', 'Player': 'بازیکن', 'Opponent': 'حریف', 'Enemy': 'دشمن', 'the enemy': 'دشمن', 'the next player': 'بازیکن بعدی', 'Penalty pending': 'جریمه در انتظار',
    'Your turn · select one of your pieces.': 'نوبت تو · یکی از مهره‌هایت را انتخاب کن.',
    'Your turn · tap a column to drop.': 'نوبت تو · برای انداختن مهره روی یک ستون بزن.',
    'Your turn · cover the queen with one of your coins.': 'نوبت تو · ملکه را با یکی از مهره‌هایت پوشش بده.',
    'Your turn · choose up to 3 coins, then strike.': 'نوبت تو · تا ۳ مهره انتخاب کن و سپس ضربه بزن.',
    'Your turn · target up to 3 coins, then strike.': 'نوبت تو · تا ۳ مهره را هدف بگیر و سپس ضربه بزن.',
    'Choose your color by targeting a coin. The server resolves the strike and queen cover.': 'با هدف گرفتن یک مهره رنگت را مشخص کن. سرور نتیجه ضربه و پوشش ملکه را تعیین می‌کند.',
    'Break and pocket': 'ضربه شروع و پاکت کردن',
    'Pocket ball': 'پاکت کردن توپ',
    'Your group:': 'گروه تو:',
    'Choose a living player for your role, then submit your night action.': 'یک بازیکن زنده را برای نقش خود انتخاب کن و اقدام شب را ثبت کن.',
    'Winner': 'برنده',
    'Defeated': 'شکست‌خورده',
    'Seer': 'پیشگو',
    'Doctor': 'پزشک',
    'Villager': 'روستایی',
    'Hidden': 'مخفی',
    'Each night, pick a victim with the pack. Survive the day votes.': 'هر شب با گروه یک قربانی انتخاب کن. از رأی‌های روز زنده بمان.',
    'Each night, inspect one player to learn if they are a werewolf.': 'هر شب یک بازیکن را بررسی کن تا بفهمی گرگینه است یا نه.',
    'Each night, protect one player from the werewolf attack.': 'هر شب یک بازیکن را از حمله گرگینه محافظت کن.',
    'No night power. Watch, reason, and vote by day.': 'قدرت شبانه نداری. در روز دقت کن، استدلال کن و رأی بده.',
    'Your turn — roll the dice.': 'نوبت تو — تاس بریز.',
    'No legal moves — pass the dice.': 'حرکت مجاز نیست — تاس را رد کن.',
    'Penalty pending — draw or challenge.': 'جریمه در انتظار — کارت بکش یا اعتراض کن.',
    'Choose the opening color to begin.': 'برای شروع رنگ را انتخاب کن.',
    'Your turn — play a matching card or draw.': 'نوبت تو — کارت همسان بازی کن یا کارت بکش.',
    'You drew a card — play it or pass.': 'یک کارت کشیدی — بازی کن یا رد کن.',
    'Waiting for the other players…': 'در انتظار بازیکنان دیگر…',
    'You won the rack!': 'رک را بردی!',
    'The rack is finished': 'رک تمام شد',
    'Break shot · select a ball or take a dry break.': 'ضربه شروع · یک توپ انتخاب کن یا ضربه خشک بزن.',
    'Open table · pocket a ball to claim solids or stripes.': 'میز آزاد · یک توپ پاکت کن تا توپ‌های ساده یا راه‌راه را بگیری.',
    'Your group is clear · call the eight ball.': 'گروه تو تمام شده · توپ هشت را اعلام کن.',
    'Take dry break': 'ضربه شروع خشک',
    'Pocket the eight ball': 'توپ هشت را پاکت کن',
    'Call the eight ball': 'توپ هشت را اعلام کن',
    'Take dry shot': 'ضربه خشک بزن',
    'Draw': 'کشیدن',
    'Draw · tied on points.': 'مساوی · امتیازها برابر است.',
    'You completed your tokens!': 'همه مهره‌هایت را به خانه رساندی!',
    'The match is finished': 'بازی تمام شده است',
    'Your turn · roll to begin': 'نوبت تو · برای شروع تاس بریز',
    'No token can move · roll again': 'هیچ مهره‌ای حرکت نمی‌کند · دوباره تاس بریز',
    'No token can move · pass': 'هیچ مهره‌ای حرکت نمی‌کند · رد کن',
    'Checkmate · you win': 'کیش‌ومات · تو بردی',
    'Checkmate · match finished': 'کیش‌ومات · بازی تمام شد',
    'Check — find a safe move.': 'کیش — یک حرکت امن پیدا کن.',
    'Check — the king must respond.': 'کیش — شاه باید پاسخ دهد.',
    'Waiting for the opponent…': 'در انتظار حریف…',
    'Draw · the grid is full.': 'مساوی · صفحه پر است.',
    'You connected four!': 'چهار مهره را وصل کردی!',
    'The match is finished.': 'بازی تمام شده است.',
    'Waiting for the other player…': 'در انتظار بازیکن دیگر…',
    'Night': 'شب',
    'Day': 'روز',
    'The village has reached a final verdict.': 'روستا به رأی نهایی رسید.',
    'The active player is making a decision.': 'بازیکن فعال در حال تصمیم‌گیری است.',
    'You are a villager. Confirm that you are awake, then wait.': 'تو روستایی هستی. بیدار بودنت را تأیید کن و منتظر بمان.',
    'Choose another living player to eliminate by vote.': 'یک بازیکن زنده دیگر را برای حذف با رأی انتخاب کن.',
    'Blocked round · tied lowest pips.': 'دور بسته شد · کمترین پیپ مساوی است.',
    'You took the round!': 'این دور را بردی!',
    'The chain is complete.': 'زنجیره کامل شد.',
    'Watch the chain and plan your next tile.': 'زنجیره را ببین و مهره بعدی‌ات را برنامه‌ریزی کن.',
    'Your turn · choose a glowing tile.': 'نوبت تو · یک مهره درخشان انتخاب کن.',
    'No match · draw until you can play.': 'مهره همسان نیست · تا زمانی که بتوانی بازی کنی بکش.',
    'No match · pass to block the round.': 'مهره همسان نیست · برای بستن دور رد کن.',
    'Group open': 'گروه باز',
    'You settled the board!': 'تخته را به پایان رساندی!',
    'The board is settled.': 'تخته به پایان رسید.',
    'Choose your color by pocketing a coin. The queen needs a cover.': 'با پاکت کردن یک مهره رنگت را مشخص کن. ملکه به پوشش نیاز دارد.',
    'Enter a checker from the bar.': 'یک مهره را از بار وارد کن.',
    'Select one of your checkers.': 'یکی از مهره‌هایت را انتخاب کن.',
    'Choose a highlighted point.': 'یک نقطه مشخص‌شده را انتخاب کن.',
    'Capture again — keep jumping!': 'دوباره بزن — به پرش ادامه بده!',
    'A capture is available — you must take it.': 'امکان زدن وجود دارد — باید آن را انجام بدهی.',
    'Select one of your pieces.': 'یکی از مهره‌هایت را انتخاب کن.',
    'Choose a highlighted square.': 'یک خانه مشخص‌شده را انتخاب کن.',
    'Fleet ready — waiting for the enemy…': 'ناوگان آماده است — در انتظار دشمن…',
    'player': 'بازیکن', 'moderator': 'ناظر', 'admin': 'مدیر',
    'Play, compete and make a little more room for good vibes.': 'بازی کن، رقابت کن و برای حال خوب بیشتر جا باز کن.',
    'Use another number': 'استفاده از شماره دیگر',
    'Continue with Google': 'ادامه با گوگل',
    'Continue with Apple': 'ادامه با اپل',
    'By continuing, you agree to VibeTable’s community guidelines and privacy policy.': 'با ادامه دادن، قوانین جامعه و حریم خصوصی VibeTable را می‌پذیری.',
    'Coin Store': 'فروشگاه سکه',
    'Top up your coin balance': 'موجودی سکه‌ات را افزایش بده',
    'Secure checkout through the App Store or Google Play.': 'پرداخت امن از طریق اپ‌استور یا گوگل‌پلی.',
    'Instant credit to wallet': 'افزایش فوری موجودی کیف پول',
    'Season Leaderboard': 'جدول رتبه‌بندی فصل',
    'Finding your table': 'در حال پیدا کردن میز',
    'We are looking for real players with a compatible table.': 'در حال پیدا کردن بازیکنان واقعی برای یک میز مناسب هستیم.',
    'Human search runs for up to 15 seconds': 'جست‌وجوی بازیکن انسانی تا ۱۵ ثانیه ادامه دارد',
    'Leaving queue…': 'در حال ترک صف…',
    'Retry now': 'تلاش دوباره همین حالا',
    'This game supports balanced teams.': 'این بازی از تیم‌های متعادل پشتیبانی می‌کند.',
    'Play for fun while keeping your profile stats.': 'برای سرگرمی بازی کن و آمار پروفایلت را نگه دار.',
    'Your result changes your seasonal rating.': 'نتیجه‌ات رتبه فصلت را تغییر می‌دهد.',
    'Any color': 'هر رنگی',
    'Reversed': 'معکوس',
    'Clockwise': 'ساعت‌گرد',
    'Draw four cards or challenge the Wild Draw Four.': 'چهار کارت بکش یا به کارت چهارِ وحشی اعتراض کن.',
    'balls': 'توپ',

    'open table': 'میز آزاد',
    'No move · pass': 'حرکتی نیست · رد کن',
    'Rolled $roll · tap a glowing token': 'تاس $roll آمد · روی مهره درخشان بزن',

    '● Black at bottom': '● مهره‌های سیاه پایین',
    '○ White at bottom': '○ مهره‌های سفید پایین',
    'White to move': 'نوبت سفید',
    'Black to move': 'نوبت سیاه',




    'Cover the queen on your next turn.': 'در نوبت بعدی ملکه را پوشش بده.',





    'The cage is closed. Check the result above.': 'قفس بسته شد. نتیجه را بالا ببین.',
    'Numbers are marked automatically as they are called.': 'شماره‌ها هنگام اعلام به‌صورت خودکار علامت می‌خورند.',


    'Place': 'قرار بده',
    'Enemy fleet': 'ناوگان دشمن',
    'Battle over': 'نبرد تمام شد',
    'Goal!': 'گل!',
    'Saved by the keeper': 'دروازه‌بان مهار کرد',
    'Loose arrow': 'رها کردن تیر',

    'Checkout complete.': 'پایان موفق خروج.',
    'Lock in answer': 'ثبت پاسخ',
    'Lock in guess': 'ثبت حدس',
    'Lock in vote': 'ثبت رأی',
    'Loading the next question…': 'در حال بارگذاری سؤال بعدی…',
    'Match complete.': 'بازی کامل شد.',
    'The question will appear after the live state syncs.': 'سؤال پس از همگام‌سازی زنده نمایش داده می‌شود.',
    'Who is faking it? Study the clues, then strike.': 'چه کسی نقش بازی می‌کند؟ سرنخ‌ها را بررسی کن و بعد ضربه بزن.',
    'Vote locked. Watching the table…': 'رأی ثبت شد. در حال تماشای میز…',
    'Waiting for the vote to reach you…': 'در انتظار رسیدن نوبت رأی‌گیری…',
    'Waiting for your turn': 'در انتظار نوبت تو',
    'Waiting for your turn…': 'در انتظار نوبت تو…',
    'Pick the emoji that sells it.': 'ایموجی مناسب را انتخاب کن.',
    'Guess locked in': 'حدس ثبت شد',
    'What did the drawer draw? First correct guess scores three points.': 'نقاش چه چیزی کشید؟ اولین حدس درست سه امتیاز می‌گیرد.',
    'Your sketch is live · wait for the guesses.': 'نقاشی تو آماده است · منتظر حدس‌ها باش.',
    'Guesses appear here as players try.': 'حدس‌های بازیکنان اینجا نمایش داده می‌شود.',
    'Waiting for the next guess…': 'در انتظار حدس بعدی…',

    'Your role is hidden.': 'نقش تو مخفی است.',
    'Your faction won the village.': 'گروه تو روستا را برد.',
    'Your faction lost the village.': 'گروه تو روستا را باخت.',
    'Goal': 'هدف',
    'Controls': 'کنترل‌ها',
    'Winning Condition': 'شرط پیروزی',
    'How to play & official rules': 'روش بازی و قوانین رسمی',
    'A fresh mini-challenge every turn — most points wins.': 'هر نوبت یک چالش کوچک تازه — بیشترین امتیاز برنده است.',
    'All seven rounds are done.': 'هر هفت دور تمام شد.',
    'All ten frames are complete.': 'هر ده فریم کامل شد.',
    'Strikes and spares earn bonus pins — highest total wins.': 'استرایک و اسپیر پین جایزه دارند — بیشترین مجموع برنده است.',
    'The dice have settled.': 'تاس‌ها ایستادند.',
    'The final result is shown above.': 'نتیجه نهایی بالا نمایش داده شده است.',
    'The final round is revealed below.': 'دور نهایی پایین آشکار شده است.',
    'The final scores are in.': 'امتیازهای نهایی آماده است.',
    'The final whistle has blown.': 'سوت پایان زده شد.',
    'Will the next card be higher or lower?': 'کارت بعدی بالاتر است یا پایین‌تر؟',
    'One cup hides 100 points — pick!': 'یک جام ۱۰۰ امتیاز را پنهان کرده — انتخاب کن!',
    'Stop the marker inside the zone!': 'نشانگر را داخل محدوده متوقف کن!',
    'Each player completes the hole before the next hole starts.': 'هر بازیکن پیش از شروع حفره بعدی این حفره را کامل می‌کند.',
    'Lowest total score wins.': 'کمترین مجموع امتیاز برنده است.',
    'Featured collection': 'مجموعه ویژه',
    '✨ FEATURED COLLECTION': '✨ مجموعه ویژه',
    'Make the table yours': 'میز را برای خودت بساز',
    'Glow avatars, frames, 3D dice and custom table themes for game nights.': 'آواتارهای درخشان، قاب‌ها، تاس‌های سه‌بعدی و تم‌های اختصاصی میز برای شب‌های بازی.',
    'No cosmetics equipped yet. Tap "Equip" on any item below to show it off.': 'هنوز وسیله تزئینی فعالی نداری. روی «فعال‌سازی» هر آیتم پایین بزن تا نمایش داده شود.',
    'Direct purchase for your friend': 'خرید مستقیم برای دوستت',
    'Private group': 'گروه خصوصی',
    'Open group': 'گروه عمومی',
    'Only invited members can join': 'فقط اعضای دعوت‌شده می‌توانند وارد شوند',
    'Anyone with the group can join': 'هر کسی که گروه را ببیند می‌تواند وارد شود',
    'Disband this group?': 'گروه منحل شود؟',
    'Leave this group?': 'گروه را ترک می‌کنی؟',
    'The group, its members, and its chat will be removed for everyone.': 'گروه، اعضا و گفتگوی آن برای همه حذف می‌شود.',
    'Ownership passes to the longest-standing admin or member.': 'مالکیت به باسابقه‌ترین مدیر یا عضو منتقل می‌شود.',
    'You can be invited back at any time.': 'هر زمان می‌توانی دوباره دعوت شوی.',
    'They will disappear from your friends and cannot contact you.': 'آن‌ها از فهرست دوستانت حذف می‌شوند و نمی‌توانند با تو تماس بگیرند.',
    'You can send a new request later.': 'بعداً می‌توانی درخواست تازه‌ای بفرستی.',
    'Chat is offline.': 'گفتگو آفلاین است.',
    'Reconnecting chat…': 'در حال اتصال دوباره به گفتگو…',

    'New shop item': 'آیتم فروشگاهی جدید',
    'Edit item': 'ویرایش آیتم',
    'Delete forever only works if nobody owns it.': 'حذف همیشگی فقط وقتی ممکن است که هیچ‌کس مالک آن نباشد.',
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'fa'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

/// Text widget used by legacy layouts. It translates literal English copy at
/// build time, so changing locale rebuilds every existing screen immediately.
class VibeText extends StatelessWidget {
  const VibeText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final translated = strings.translateText(data);
    return Text(
      translated,
      key: key,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
