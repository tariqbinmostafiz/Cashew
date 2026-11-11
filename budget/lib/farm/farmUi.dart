import 'package:budget/colors.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Shared small UI helpers for the dairy screens.

const List<String> _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];
const List<String> _monthsBn = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই',
  'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
];

String farmMonthName(BuildContext context, int month) {
  final bool bn = Localizations.localeOf(context).languageCode == 'bn';
  return (bn ? _monthsBn : _monthsEn)[month - 1];
}

String farmFmtDate(BuildContext context, DateTime d) {
  final String m = farmMonthName(context, d.month);
  final String shortMonth =
      Localizations.localeOf(context).languageCode == 'bn' ? m : m.substring(0, 3);
  return d.day.toString() + ' ' + shortMonth + ' ' + d.year.toString();
}

String farmFmtMonth(BuildContext context, DateTime d) {
  return farmMonthName(context, d.month) + ' ' + d.year.toString();
}

// Latin digits everywhere so what is shown matches what is typed.
final NumberFormat _numFmt = NumberFormat('#,##0.##', 'en_US');

String farmFmtNumber(double v) => _numFmt.format(v);
String farmFmtLitres(double v) => _numFmt.format(v);
String farmFmtMoney(double v) {
  final String s = _numFmt.format(v.abs());
  return (v < 0 ? '-' : '') + '\u09F3' + s;
}

/// Parses user input; accepts Bengali digits and thousands separators.
double? farmParseNumber(String? input) {
  if (input == null) return null;
  String t = input.trim();
  if (t.isEmpty) return null;
  const String bnDigits = '\u09E6\u09E7\u09E8\u09E9\u09EA\u09EB\u09EC\u09ED\u09EE\u09EF';
  for (int i = 0; i < bnDigits.length; i++) {
    t = t.replaceAll(bnDigits[i], i.toString());
  }
  t = t.replaceAll(',', '');
  return double.tryParse(t);
}

void farmMessage(String title, {bool warning = false}) {
  openSnackbar(SnackbarMessage(
    title: title,
    icon: warning
        ? (appStateSettings['outlinedIcons']
            ? Icons.warning_outlined
            : Icons.warning_rounded)
        : (appStateSettings['outlinedIcons']
            ? Icons.check_circle_outline
            : Icons.check_circle_rounded),
  ));
}

Future<DateTime?> farmPickDate(BuildContext context, DateTime initial,
    {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: last ?? DateTime(2100),
  );
}

class FarmCard extends StatelessWidget {
  const FarmCard({
    Key? key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
    this.color,
  }) : super(key: key);
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? getColor(context, 'lightDarkAccentHeavyLight'),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class FarmSectionTitle extends StatelessWidget {
  const FarmSectionTitle(this.text, {Key? key, this.trailing})
      : super(key: key);
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, right: 16, top: 14, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: TextFont(
              text: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class FarmStat extends StatelessWidget {
  const FarmStat({
    Key? key,
    required this.label,
    required this.value,
    this.color,
    this.big = false,
  }) : super(key: key);
  final String label;
  final String value;
  final Color? color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFont(
          text: value,
          fontSize: big ? 30 : 20,
          fontWeight: FontWeight.bold,
          textColor: color,
          maxLines: 1,
          autoSizeText: true,
          minFontSize: 12,
        ),
        SizedBox(height: 2),
        TextFont(
          text: label,
          fontSize: 12.5,
          textColor: getColor(context, 'textLight'),
          maxLines: 2,
        ),
      ],
    );
  }
}

/// Row with previous / next arrows around a label (date or month selector).
class FarmStepper extends StatelessWidget {
  const FarmStepper({
    Key? key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.onTapLabel,
  }) : super(key: key);
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTapLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
              onPressed: onPrevious, icon: Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTapLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: TextFont(
                    text: label,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
              onPressed: onNext, icon: Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

/// Wrap of selectable chips: one value of [T] chosen.
class FarmChoice<T> extends StatelessWidget {
  const FarmChoice({
    Key? key,
    required this.options,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);
  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final MapEntry<T, String> e in options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: selected == e.key,
              onSelected: (_) => onSelected(e.key),
            ),
        ],
      ),
    );
  }
}

class FarmFieldLabel extends StatelessWidget {
  const FarmFieldLabel(this.text, {Key? key}) : super(key: key);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, right: 16, top: 12, bottom: 2),
      child: TextFont(
        text: text,
        fontSize: 13,
        textColor: getColor(context, 'textLight'),
      ),
    );
  }
}

Future<bool> farmConfirm(BuildContext context, String message,
    {String? confirmLabel}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ft(ctx, 'cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? ft(ctx, 'yes')),
        ),
      ],
    ),
  );
  return result == true;
}
