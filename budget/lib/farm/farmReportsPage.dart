import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/farm/animalsPage.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';

/// Monthly report: production, cow-wise, sales, usage, profit & loss (cash).
class FarmReportsPage extends StatefulWidget {
  const FarmReportsPage({Key? key}) : super(key: key);

  @override
  State<FarmReportsPage> createState() => _FarmReportsPageState();
}

class _FarmReportsPageState extends State<FarmReportsPage> {
  DateTime month = farmMonthStart(DateTime.now());
  MonthReport? report;
  Map<String, String> animalNames = {};
  Map<String, String> categoryNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final DateTime m = month;
    final MonthReport r = await FarmRepo.loadMonthReport(m);
    final List<FarmAnimal> animals = await FarmRepo.getAllAnimalsIncludingArchived();
    final List<TransactionCategory> cats = await database.getAllCategories();
    if (!mounted || m != month) return;
    setState(() {
      report = r;
      animalNames = {
        for (final FarmAnimal a in animals)
          a.animalPk: a.tagNumber +
              ((a.name ?? '').isEmpty ? '' : ' ' + a.name!)
      };
      categoryNames = {for (final TransactionCategory c in cats) c.categoryPk: c.name};
    });
  }

  void changeMonth(DateTime m) {
    setState(() {
      month = farmMonthStart(m);
      report = null;
    });
    load();
  }

  String usageLabel(MilkUsageType t) {
    switch (t) {
      case MilkUsageType.home:
        return ft(context, 'usage-home');
      case MilkUsageType.calves:
        return ft(context, 'usage-calves');
      case MilkUsageType.spoiled:
        return ft(context, 'usage-spoiled');
      case MilkUsageType.other:
        return ft(context, 'usage-other');
    }
  }

  List<MapEntry<String, double>> sortedDesc(Map<String, double> m) {
    final List<MapEntry<String, double>> l = m.entries.toList();
    l.sort((a, b) => b.value.compareTo(a.value));
    return l;
  }

  String reportText(MonthReport r) {
    final String L = ft(context, 'litres-short');
    final StringBuffer sb = StringBuffer();
    sb.writeln(ft(context, 'monthly-report') + ' - ' + farmFmtMonth(context, r.month));
    sb.writeln('');
    sb.writeln(ft(context, 'production') + ': ' + farmFmtLitres(r.totalMilk) + ' ' + L);
    sb.writeln(ft(context, 'average-per-day') + ': ' + farmFmtLitres(r.averagePerDay) + ' ' + L);
    sb.writeln(ft(context, 'sales-report') + ': ' + farmFmtLitres(r.soldLitres) + ' ' + L + ' / ' + farmFmtMoney(r.salesValue));
    sb.writeln(ft(context, 'cash-collected') + ': ' + farmFmtMoney(r.cashCollectedFromMilk));
    sb.writeln(ft(context, 'total-outstanding') + ': ' + farmFmtMoney(r.totalOutstanding));
    sb.writeln(ft(context, 'usage-report') + ': ' + farmFmtLitres(r.usedLitres) + ' ' + L);
    sb.writeln('');
    sb.writeln(ft(context, 'income') + ': ' + farmFmtMoney(r.income));
    sb.writeln(ft(context, 'expenses') + ': ' + farmFmtMoney(r.expenses));
    sb.writeln(ft(context, 'profit') + ': ' + farmFmtMoney(r.profit));
    return sb.toString();
  }

  Widget row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: TextFont(text: label, fontSize: 15, maxLines: 2)),
          TextFont(
            text: value,
            fontSize: 15,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            textColor: color,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MonthReport? r = report;
    final String L = ft(context, 'litres-short');
    final Color income = getColor(context, 'incomeAmount');
    final Color expense = getColor(context, 'expenseAmount');
    final DateTime thisMonth = farmMonthStart(DateTime.now());
    return PageFramework(
      title: ft(context, 'monthly-report'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      actions: [
        if (r != null)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: ft(context, 'share-report'),
            onPressed: () => shareToClipboard(reportText(r), context: context),
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FarmStepper(
                label: farmFmtMonth(context, month),
                onPrevious: () =>
                    changeMonth(DateTime(month.year, month.month - 1, 1)),
                onNext: month == thisMonth
                    ? null
                    : () => changeMonth(farmNextMonth(month)),
              ),
              if (r == null)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                FarmSectionTitle(ft(context, 'production')),
                FarmCard(
                  child: Column(
                    children: [
                      row(ft(context, 'total'), farmFmtLitres(r.totalMilk) + ' ' + L,
                          bold: true),
                      row(ft(context, 'average-per-day'),
                          farmFmtLitres(r.averagePerDay) + ' ' + L),
                      row(ft(context, 'days-with-data'), r.daysWithMilk.toString()),
                      if (r.bestDay != null)
                        row(ft(context, 'best-day'),
                            farmFmtLitres(r.bestDayLitres) + ' ' + L + '  (' + r.bestDay!.day.toString() + ')'),
                      if (r.herdEntryLitres > 0)
                        row(ft(context, 'herd-entries'),
                            farmFmtLitres(r.herdEntryLitres) + ' ' + L),
                    ],
                  ),
                ),
                if (r.litresByAnimal.isNotEmpty) ...[
                  FarmSectionTitle(ft(context, 'cow-wise')),
                  FarmCard(
                    child: Column(
                      children: [
                        for (final MapEntry<String, double> e
                            in sortedDesc(r.litresByAnimal))
                          row(animalNames[e.key] ?? '?',
                              farmFmtLitres(e.value) + ' ' + L),
                      ],
                    ),
                  ),
                ],
                FarmSectionTitle(ft(context, 'sales-report')),
                FarmCard(
                  child: Column(
                    children: [
                      row(ft(context, 'litres'), farmFmtLitres(r.soldLitres) + ' ' + L),
                      row(ft(context, 'sales-value'), farmFmtMoney(r.salesValue)),
                      row(ft(context, 'cash-collected'),
                          farmFmtMoney(r.cashCollectedFromMilk), color: income),
                      row(ft(context, 'total-outstanding'),
                          farmFmtMoney(r.totalOutstanding),
                          color: r.totalOutstanding > 0 ? expense : null),
                    ],
                  ),
                ),
                FarmSectionTitle(ft(context, 'usage-report')),
                FarmCard(
                  child: Column(
                    children: [
                      for (final MilkUsageType t in MilkUsageType.values)
                        row(usageLabel(t),
                            farmFmtLitres(r.usage[t] ?? 0.0) + ' ' + L),
                      row(ft(context, 'milk-unaccounted'),
                          farmFmtLitres(r.unaccounted) + ' ' + L,
                          bold: true,
                          color: r.unaccounted < -0.005 ? expense : null),
                    ],
                  ),
                ),
                FarmSectionTitle(ft(context, 'profit-loss')),
                FarmCard(
                  child: Column(
                    children: [
                      row(ft(context, 'income'), farmFmtMoney(r.income), color: income),
                      row(ft(context, 'expenses'), farmFmtMoney(r.expenses), color: expense),
                      row(ft(context, 'profit'), farmFmtMoney(r.profit),
                          bold: true, color: r.profit >= 0 ? income : expense),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextFont(
                          text: ft(context, 'basis-note'),
                          fontSize: 12,
                          maxLines: 3,
                          textColor: getColor(context, 'textLight'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.expenseByCategory.isNotEmpty) ...[
                  FarmSectionTitle(ft(context, 'expense-by-category')),
                  FarmCard(
                    child: Column(
                      children: [
                        for (final MapEntry<String, double> e
                            in sortedDesc(r.expenseByCategory))
                          row(categoryNames[e.key] ?? e.key, farmFmtMoney(e.value)),
                      ],
                    ),
                  ),
                ],
                if (r.incomeByCategory.isNotEmpty) ...[
                  FarmSectionTitle(ft(context, 'income-by-category')),
                  FarmCard(
                    child: Column(
                      children: [
                        for (final MapEntry<String, double> e
                            in sortedDesc(r.incomeByCategory))
                          row(categoryNames[e.key] ?? e.key, farmFmtMoney(e.value)),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 90),
            ],
          ),
        ),
      ],
    );
  }
}
