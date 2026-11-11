import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

// Bilingual (English / Bengali) strings for the dairy features.
// Kept separate from easy_localization JSON so the generated translation files
// and the CSV pipeline are not touched. Each value is [english, bengali].
String ft(BuildContext context, String key) {
  final String lang = Localizations.localeOf(context).languageCode;
  return _pick(key, lang);
}

/// For code that has no BuildContext (seeding default data).
String ftNoContext(String key) {
  return _pick(key, ui.PlatformDispatcher.instance.locale.languageCode);
}

String _pick(String key, String lang) {
  final List<String>? v = farmStrings[key];
  if (v == null) return key;
  return lang == 'bn' ? v[1] : v[0];
}

const Map<String, List<String>> farmStrings = {
  // ---- default category / wallet names (stored at seed time)
  'cat-feed': ['Feed & Fodder', 'খাদ্য ও খড়'],
  'cat-vet': ['Medicine & Vet', 'ঔষধ ও চিকিৎসা'],
  'cat-labour': ['Labour', 'শ্রমিক মজুরি'],
  'cat-electricity': ['Electricity & Water', 'বিদ্যুৎ ও পানি'],
  'cat-transport': ['Transport', 'পরিবহন'],
  'cat-equipment': ['Equipment & Repair', 'সরঞ্জাম ও মেরামত'],
  'cat-animal-purchase': ['Animal Purchase', 'পশু ক্রয়'],
  'cat-breeding': ['Breeding', 'প্রজনন'],
  'cat-other-expense': ['Other Expense', 'অন্যান্য খরচ'],
  'cat-milk-sales': ['Milk Sales', 'দুধ বিক্রি'],
  'cat-animal-sale': ['Animal Sale', 'পশু বিক্রি'],
  'cat-other-income': ['Other Income', 'অন্যান্য আয়'],
  'wallet-mobile-banking': ['Mobile Banking', 'মোবাইল ব্যাংকিং'],
  'wallet-cash': ['Cash', 'নগদ'],

  // ---- navigation / general
  'nav-milk': ['Milk', 'দুধ'],
  'nav-sales': ['Sales', 'বিক্রি'],
  'nav-animals': ['Animals', 'পশু'],
  'farm': ['Farm', 'খামার'],
  'today': ['Today', 'আজ'],
  'save': ['Save', 'সংরক্ষণ'],
  'cancel': ['Cancel', 'বাতিল'],
  'delete': ['Delete', 'মুছুন'],
  'edit': ['Edit', 'সম্পাদনা'],
  'add': ['Add', 'যোগ করুন'],
  'close': ['Close', 'বন্ধ'],
  'yes': ['Yes', 'হ্যাঁ'],
  'no': ['No', 'না'],
  'all': ['All', 'সব'],
  'note': ['Note', 'নোট'],
  'date': ['Date', 'তারিখ'],
  'none': ['None', 'নেই'],
  'litres': ['Litres', 'লিটার'],
  'litres-short': ['L', 'লি.'],
  'total': ['Total', 'মোট'],
  'optional': ['optional', 'ঐচ্ছিক'],
  'required-field': ['This field is required', 'এই ঘরটি পূরণ করা আবশ্যক'],
  'invalid-number': ['Enter a valid number', 'সঠিক সংখ্যা লিখুন'],
  'saved': ['Saved', 'সংরক্ষিত হয়েছে'],
  'error': ['Something went wrong', 'কিছু একটা সমস্যা হয়েছে'],
  'more-farm': ['Farm tools', 'খামারের টুলস'],

  // ---- sessions
  'morning': ['Morning', 'সকাল'],
  'evening': ['Evening', 'সন্ধ্যা'],
  'session': ['Session', 'সময়'],

  // ---- animals
  'animals': ['Animals', 'পশু'],
  'add-animal': ['Add animal', 'পশু যোগ করুন'],
  'edit-animal': ['Edit animal', 'পশুর তথ্য সম্পাদনা'],
  'tag-number': ['Tag / ID number', 'ট্যাগ / আইডি নম্বর'],
  'animal-name': ['Name', 'নাম'],
  'breed': ['Breed', 'জাত'],
  'sex': ['Sex', 'লিঙ্গ'],
  'female': ['Female', 'স্ত্রী'],
  'male': ['Male', 'পুরুষ'],
  'date-of-birth': ['Date of birth', 'জন্ম তারিখ'],
  'purchase-date': ['Purchase date', 'ক্রয়ের তারিখ'],
  'purchase-price': ['Purchase price', 'ক্রয়মূল্য'],
  'status': ['Status', 'অবস্থা'],
  'status-milking': ['Milking', 'দুধ দিচ্ছে'],
  'status-dry': ['Dry', 'শুকনো'],
  'status-heifer': ['Heifer', 'বকনা'],
  'status-calf': ['Calf', 'বাছুর'],
  'status-bull': ['Bull', 'ষাঁড়'],
  'status-sick': ['Sick', 'অসুস্থ'],
  'status-sold': ['Sold', 'বিক্রিত'],
  'status-dead': ['Dead', 'মৃত'],
  'photo': ['Photo', 'ছবি'],
  'choose-photo': ['Choose photo', 'ছবি বাছুন'],
  'remove-photo': ['Remove photo', 'ছবি সরান'],
  'photo-backup-note': [
    'Photos are stored on the phone and are not included in the database backup file.',
    'ছবি ফোনেই থাকে, ডেটাবেস ব্যাকআপ ফাইলে অন্তর্ভুক্ত হয় না।'
  ],
  'no-animals': ['No animals yet. Tap + to add one.', 'এখনো কোনো পশু নেই। যোগ করতে + চাপুন।'],
  'tag-taken': ['This tag number is already used', 'এই ট্যাগ নম্বর আগেই ব্যবহৃত হয়েছে'],
  'archive': ['Archive', 'আর্কাইভ'],
  'unarchive': ['Restore', 'ফিরিয়ে আনুন'],
  'archive-animal-confirm': [
    'Archive this animal? Its milk records are kept.',
    'এই পশুটি আর্কাইভ করবেন? এর দুধের রেকর্ড থেকে যাবে।'
  ],
  'show-archived': ['Show archived', 'আর্কাইভ দেখান'],
  'animal-count': ['animals', 'টি পশু'],

  // ---- milk
  'milk': ['Milk', 'দুধ'],
  'milk-production': ['Milk production', 'দুধ উৎপাদন'],
  'enter-milk': ['Enter milk', 'দুধ এন্ট্রি'],
  'enter-morning': ['Morning milk', 'সকালের দুধ'],
  'enter-evening': ['Evening milk', 'সন্ধ্যার দুধ'],
  'per-cow': ['Per cow', 'গরু অনুযায়ী'],
  'herd-total': ['Herd total', 'মোট (পুরো পাল)'],
  'herd-total-litres': ['Total litres', 'মোট লিটার'],
  'copy-yesterday': ['Copy yesterday', 'গতকালের মতো'],
  'no-milking-animals': [
    'No milking animals. Add animals with status "Milking", or use Herd total.',
    'কোনো দুধেল পশু নেই। অবস্থা "দুধ দিচ্ছে" দিয়ে পশু যোগ করুন, অথবা "মোট" ব্যবহার করুন।'
  ],
  'herd-entry-exists': [
    'A herd-total entry also exists for this session and is counted too.',
    'এই সময়ের জন্য মোট (পুরো পাল) এন্ট্রিও আছে, সেটিও হিসাবে ধরা হচ্ছে।'
  ],
  'no-milk-today': ['No milk recorded for this day', 'এই দিনে দুধের কোনো রেকর্ড নেই'],
  'last-14-days': ['Last 14 days', 'গত ১৪ দিন'],
  'per-cow-today': ['By cow', 'গরু অনুযায়ী'],
  'milk-sold': ['Sold', 'বিক্রি'],
  'milk-used': ['Used', 'ব্যবহার'],
  'milk-unaccounted': ['Unaccounted', 'হিসাবের বাইরে'],
  'milk-usage': ['Milk usage', 'দুধের ব্যবহার'],
  'usage-home': ['Home', 'বাড়িতে'],
  'usage-calves': ['Calves', 'বাছুরকে'],
  'usage-spoiled': ['Spoiled', 'নষ্ট'],
  'usage-other': ['Other', 'অন্যান্য'],
  'add-usage': ['Add usage', 'ব্যবহার যোগ করুন'],
  'no-usage': ['No usage recorded', 'কোনো ব্যবহার রেকর্ড নেই'],
  'usage-type': ['Type', 'ধরন'],
  'amount-too-large': ['That amount looks too large. Please check.', 'পরিমাণটি অনেক বেশি মনে হচ্ছে, দেখে নিন।'],
  'average-per-day': ['Average per day', 'দৈনিক গড়'],
  'best-day': ['Best day', 'সেরা দিন'],

  // ---- customers / sales
  'sales': ['Milk sales', 'দুধ বিক্রি'],
  'customers': ['Customers', 'গ্রাহক'],
  'add-customer': ['Add customer', 'গ্রাহক যোগ করুন'],
  'edit-customer': ['Edit customer', 'গ্রাহকের তথ্য সম্পাদনা'],
  'customer': ['Customer', 'গ্রাহক'],
  'customer-name': ['Customer name', 'গ্রাহকের নাম'],
  'phone': ['Phone', 'ফোন'],
  'address': ['Address', 'ঠিকানা'],
  'default-price': ['Default price per litre', 'প্রতি লিটারের ডিফল্ট দাম'],
  'opening-balance': ['Opening balance (dues before using the app)', 'শুরুর বকেয়া (অ্যাপ ব্যবহারের আগের)'],
  'no-customers': ['No customers yet. Tap + to add one.', 'এখনো কোনো গ্রাহক নেই। যোগ করতে + চাপুন।'],
  'walk-in': ['Walk-in / cash customer', 'খুচরা / নগদ ক্রেতা'],
  'new-sale': ['New sale', 'নতুন বিক্রি'],
  'sale-details': ['Sale', 'বিক্রি'],
  'price-per-litre': ['Price per litre', 'প্রতি লিটারের দাম'],
  'sale-total': ['Total amount', 'মোট টাকা'],
  'payment-status': ['Payment', 'পেমেন্ট'],
  'unpaid': ['Unpaid', 'বাকি'],
  'paid-full': ['Paid in full', 'সম্পূর্ণ পরিশোধ'],
  'partial': ['Partial', 'আংশিক'],
  'paid-now': ['Amount received now', 'এখন যত টাকা পেয়েছেন'],
  'wallet': ['Account', 'অ্যাকাউন্ট'],
  'select-customer': ['Select a customer', 'গ্রাহক বাছুন'],
  'no-sales': ['No sales in this month', 'এই মাসে কোনো বিক্রি নেই'],
  'sales-value': ['Sales value', 'বিক্রির মূল্য'],
  'cash-collected': ['Cash collected', 'নগদ আদায়'],
  'outstanding': ['Outstanding', 'বকেয়া'],
  'balance': ['Balance due', 'বকেয়া পাবো'],
  'advance': ['Advance', 'অগ্রিম'],
  'cancel-sale': ['Cancel sale', 'বিক্রি বাতিল'],
  'restore-sale': ['Restore sale', 'বিক্রি ফিরিয়ে আনুন'],
  'cancelled': ['Cancelled', 'বাতিল'],
  'sale-has-payments': [
    'This sale has payments linked. Delete the payment first.',
    'এই বিক্রির সঙ্গে পেমেন্ট যুক্ত আছে। আগে পেমেন্ট মুছুন।'
  ],
  'receive-payment': ['Receive payment', 'টাকা গ্রহণ'],
  'payment-amount': ['Amount', 'টাকার পরিমাণ'],
  'delete-payment-confirm': [
    'Delete this payment? The income entry will be removed too.',
    'এই পেমেন্ট মুছবেন? সংশ্লিষ্ট আয়ের এন্ট্রিও মুছে যাবে।'
  ],
  'ledger': ['Ledger', 'হিসাবের খাতা'],
  'ledger-sale': ['Sale', 'বিক্রি'],
  'ledger-payment': ['Payment', 'পেমেন্ট'],
  'ledger-opening': ['Opening balance', 'শুরুর বকেয়া'],
  'share-statement': ['Share statement', 'স্টেটমেন্ট শেয়ার'],
  'statement': ['Statement', 'স্টেটমেন্ট'],
  'archive-customer-confirm': [
    'Archive this customer? Their history is kept.',
    'এই গ্রাহক আর্কাইভ করবেন? তার ইতিহাস থেকে যাবে।'
  ],
  'total-outstanding': ['Total outstanding', 'মোট বকেয়া'],
  'milk-income-name': ['Milk', 'দুধ'],
  'save-failed-nothing-changed': [
    'Could not save. Nothing was changed.',
    'সংরক্ষণ করা যায়নি। কিছুই পরিবর্তন হয়নি।'
  ],

  // ---- dashboard
  'dash-animals': ['Animals', 'পশু'],
  'dash-total': ['Total', 'মোট'],
  'dash-milking': ['Milking', 'দুধেল'],
  'dash-dry': ['Dry', 'শুকনো'],
  'dash-sick': ['Sick', 'অসুস্থ'],
  'dash-milk-today': ['Milk today', 'আজকের দুধ'],
  'dash-money-today': ['Money today', 'আজকের টাকা'],
  'dash-income': ['Cash in', 'আয় (নগদ)'],
  'dash-expense': ['Expenses', 'খরচ'],
  'dash-profit': ['Estimated profit (cash)', 'আনুমানিক লাভ (নগদ)'],
  'dash-sales-value': ['Sales value today', 'আজকের বিক্রির মূল্য'],
  'quick-actions': ['Quick actions', 'দ্রুত কাজ'],
  'add-expense': ['Add expense', 'খরচ যোগ'],
  'add-income': ['Add income', 'আয় যোগ'],
  'reports': ['Reports', 'রিপোর্ট'],
  'accounts-transactions': ['Income & expenses', 'আয়-ব্যয়'],

  // ---- reports
  'monthly-report': ['Monthly report', 'মাসিক রিপোর্ট'],
  'production': ['Production', 'উৎপাদন'],
  'sales-report': ['Sales', 'বিক্রি'],
  'usage-report': ['Usage', 'ব্যবহার'],
  'profit-loss': ['Profit & loss (cash)', 'লাভ-ক্ষতি (নগদ)'],
  'income': ['Income', 'আয়'],
  'expenses': ['Expenses', 'খরচ'],
  'profit': ['Profit', 'লাভ'],
  'expense-by-category': ['Expenses by category', 'খাত অনুযায়ী খরচ'],
  'income-by-category': ['Income by category', 'খাত অনুযায়ী আয়'],
  'cow-wise': ['Cow-wise production', 'গরু অনুযায়ী উৎপাদন'],
  'herd-entries': ['Herd-total entries', 'মোট (পুরো পাল) এন্ট্রি'],
  'share-report': ['Share report', 'রিপোর্ট শেয়ার'],
  'basis-note': [
    'Profit is on a cash basis: money actually received minus money spent.',
    'লাভ নগদ ভিত্তিতে: যত টাকা পেয়েছেন, তা থেকে যত খরচ করেছেন তা বাদ।'
  ],
  'days-with-data': ['days with data', 'দিনের ডেটা আছে'],

  // ---- backup
  'backup-err-too-small': ['This file is too small to be a backup.', 'ফাইলটি ব্যাকআপ হওয়ার জন্য খুব ছোট।'],
  'backup-err-not-sqlite': ['This is not a database backup file.', 'এটি ডেটাবেস ব্যাকআপ ফাইল নয়।'],
  'backup-err-no-version': ['This file is not an app database.', 'এটি অ্যাপের ডেটাবেস ফাইল নয়।'],
  'backup-err-too-new': [
    'This backup was made by a newer version of the app. Update the app first. Your current data was not changed.',
    'এই ব্যাকআপ অ্যাপের নতুন সংস্করণে তৈরি। আগে অ্যাপ আপডেট করুন। আপনার বর্তমান ডেটা বদলায়নি।'
  ],
  'backup-err-not-app-db': [
    'This database does not contain the expected data. Your current data was not changed.',
    'এই ডেটাবেসে প্রত্যাশিত ডেটা নেই। আপনার বর্তমান ডেটা বদলায়নি।'
  ],
};
