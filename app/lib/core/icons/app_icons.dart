import 'package:flutter/widgets.dart';
import 'package:hisaabchat/core/icons/symbols.g.dart';

/// The single icon registry (docs/04-UI-UX-Design-Brief.md §2.4).
///
/// Every icon in the app is a Material Symbols **Rounded** glyph from the
/// subset font in assets/fonts. To add an icon, list it in
/// tool/icons/icons.txt and rerun tool/icons/generate_icons.py.
/// Never use `Icons.*` or emoji in the UI.
abstract final class AppIcons {
  // Navigation & app bar
  static const IconData home = Symbols.home;
  static const IconData transactions = Symbols.receiptLong;
  static const IconData budgets = Symbols.donutLarge;
  static const IconData accounts = Symbols.accountBalanceWallet;
  static const IconData reports = Symbols.barChart;
  static const IconData settings = Symbols.settings;
  static const IconData people = Symbols.groups;
  static const IconData search = Symbols.search;
  static const IconData more = Symbols.moreVert;
  static const IconData back = Symbols.arrowBack;
  static const IconData forward = Symbols.arrowForward;
  static const IconData close = Symbols.close;
  static const IconData add = Symbols.add;
  static const IconData addAccount = Symbols.addCard;
  static const IconData addBudget = Symbols.addChart;
  static const IconData filter = Symbols.filterList;
  static const IconData month = Symbols.calendarMonth;
  static const IconData edit = Symbols.edit;
  static const IconData delete = Symbols.delete;
  static const IconData duplicate = Symbols.contentCopy;
  static const IconData pin = Symbols.pushPin;
  static const IconData archive = Symbols.archive;
  static const IconData download = Symbols.download;
  static const IconData share = Symbols.share;
  static const IconData refresh = Symbols.refresh;
  static const IconData chevron = Symbols.chevronRight;
  static const IconData check = Symbols.check;

  // Transaction types & status
  static const IconData expense = Symbols.northEast;
  static const IconData income = Symbols.southWest;
  static const IconData transfer = Symbols.swapHoriz;
  static const IconData adjustment = Symbols.tune;
  static const IconData recurring = Symbols.autorenew;
  static const IconData sending = Symbols.schedule;
  static const IconData saved = Symbols.done;
  static const IconData failed = Symbols.error;
  static const IconData ok = Symbols.checkCircle;
  static const IconData warning = Symbols.warning;
  static const IconData info = Symbols.info;
  static const IconData over = Symbols.error;
  static const IconData online = Symbols.cloudDone;
  static const IconData offline = Symbols.cloudOff;

  // Composer
  static const IconData toggleExpense = Symbols.remove;
  static const IconData toggleIncome = Symbols.add;
  static const IconData attach = Symbols.attachFile;
  static const IconData send = Symbols.send;
  static const IconData jumpToLatest = Symbols.keyboardDoubleArrowDown;

  // Auth & settings
  static const IconData email = Symbols.mail;
  static const IconData password = Symbols.lock;
  static const IconData showPassword = Symbols.visibility;
  static const IconData hidePassword = Symbols.visibilityOff;
  static const IconData person = Symbols.person;
  static const IconData name = Symbols.badge;
  static const IconData categories = Symbols.sell;
  static const IconData palette = Symbols.palette;
  static const IconData data = Symbols.database;
  static const IconData help = Symbols.help;
  static const IconData logout = Symbols.logout;
  static const IconData devices = Symbols.devices;
  static const IconData currency = Symbols.currencyRupee;
  static const IconData timezone = Symbols.public;
  static const IconData monthStart = Symbols.event;
  static const IconData themeSystem = Symbols.brightnessAuto;
  static const IconData themeLight = Symbols.lightMode;
  static const IconData themeDark = Symbols.darkMode;
  static const IconData motion = Symbols.animation;
  static const IconData privacy = Symbols.lockPerson;

  // Transactions
  static const IconData today = Symbols.today;
  static const IconData history = Symbols.history;
  static const IconData note = Symbols.notes;
  static const IconData reconcile = Symbols.balance;
  static const IconData expand = Symbols.expandMore;
  static const IconData noResults = Symbols.searchOff;
  static const IconData scrollDown = Symbols.keyboardArrowDown;

  // Dashboard, onboarding & reports
  static const IconData pieChart = Symbols.pieChart;
  static const IconData trend = Symbols.showChart;
  static const IconData start = Symbols.rocketLaunch;
  static const IconData done = Symbols.taskAlt;

  /// Curated icons offered when creating a category (keys stored in the DB).
  static const List<String> categoryChoices = [
    'home',
    'shopping_cart',
    'local_grocery_store',
    'restaurant',
    'local_cafe',
    'fastfood',
    'lunch_dining',
    'local_pizza',
    'two_wheeler',
    'directions_car',
    'local_gas_station',
    'directions_bus',
    'train',
    'local_taxi',
    'flight',
    'build',
    'home_repair_service',
    'school',
    'menu_book',
    'bolt',
    'water_drop',
    'wifi',
    'smartphone',
    'shopping_bag',
    'checkroom',
    'medical_services',
    'medication',
    'fitness_center',
    'spa',
    'content_cut',
    'movie',
    'sports_esports',
    'music_note',
    'pets',
    'child_care',
    'redeem',
    'celebration',
    'volunteer_activism',
    'cleaning_services',
    'local_laundry_service',
    'receipt',
    'savings',
    'trending_up',
    'work',
    'laptop_mac',
    'family_restroom',
    'percent',
    'undo',
    'add_circle',
    'payments',
    'more_horiz',
  ];

  /// Resolves an icon key stored in the database (accounts, categories,
  /// budgets); unknown keys fall back to a neutral glyph.
  static IconData byKey(String key) => Symbols.byName[key] ?? Symbols.category;
}
