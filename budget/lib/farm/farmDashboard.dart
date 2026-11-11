import 'dart:async';
import 'package:budget/colors.dart';
import 'package:budget/farm/animalsPage.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmReportsPage.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/farm/milkPage.dart';
import 'package:budget/farm/salesPage.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';

/// Dairy dashboard shown at the top of the Home page.
class FarmDashboardSection extends StatefulWidget {
  const FarmDashboardSection({Key? key}) : super(key: key);

  @override
  State<FarmDashboardSection> createState() => _FarmDashboardSectionState();
}

class _FarmDashboardSectionState extends State<FarmDashboardSection> {
  FarmDashboardData? data;
  late StreamSubscription<dynamic> sub;

  @override
  void initState() {
    super.initState();
    load();
    sub = FarmRepo.changes().listen((_) => load());
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final FarmDashboardData d = await FarmRepo.loadDashboard();
      if (!mounted) return;
      setState(() => data = d);
    } catch (e) {
      print('Dashboard load failed: ' + e.toString());
    }
  }

  Widget quickButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: getColor(context, 'lightDarkAccentHeavyLight'),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  TextFont(
                    text: label,
                    fontSize: 12.5,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FarmDashboardData? d = data;
    final Color income = getColor(context, 'incomeAmount');
    final Color expense = getColor(context, 'expenseAmount');
    final String L = ft(context, 'litres-short');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FarmSectionTitle(
          ft(context, 'dash-animals'),
          trailing: TextButton(
            onPressed: () => pushRoute(context, const AnimalsPage()),
            child: Text(ft(context, 'animals')),
          ),
        ),
        FarmCard(
          onTap: () => pushRoute(context, const AnimalsPage()),
          child: Row(
            children: [
              Expanded(
                  child: FarmStat(
                      label: ft(context, 'dash-total'),
                      value: (d?.totalAnimals ?? 0).toString())),
              Expanded(
                  child: FarmStat(
                      label: ft(context, 'dash-milking'),
                      value: (d?.milking ?? 0).toString(),
                      color: Colors.green)),
              Expanded(
                  child: FarmStat(
                      label: ft(context, 'dash-dry'),
                      value: (d?.dry ?? 0).toString(),
                      color: Colors.orange)),
              Expanded(
                  child: FarmStat(
                      label: ft(context, 'dash-sick'),
                      value: (d?.sick ?? 0).toString(),
                      color: Colors.red)),
            ],
          ),
        ),
        FarmSectionTitle(ft(context, 'dash-milk-today')),
        FarmCard(
          onTap: () => pushRoute(context, const MilkPage(backButton: true)),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'morning'),
                          value: farmFmtLitres(d?.morning ?? 0) + ' ' + L)),
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'evening'),
                          value: farmFmtLitres(d?.evening ?? 0) + ' ' + L)),
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'total'),
                          value: farmFmtLitres(d?.totalMilk ?? 0) + ' ' + L,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'milk-sold'),
                          value: farmFmtLitres(d?.soldLitres ?? 0) + ' ' + L)),
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'milk-used'),
                          value: farmFmtLitres(d?.usedLitres ?? 0) + ' ' + L)),
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'milk-unaccounted'),
                          value: farmFmtLitres(d?.unaccounted ?? 0) + ' ' + L,
                          color: (d?.unaccounted ?? 0) < -0.005 ? expense : null)),
                ],
              ),
            ],
          ),
        ),
        FarmSectionTitle(ft(context, 'dash-money-today')),
        FarmCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'dash-income'),
                          value: farmFmtMoney(d?.incomeToday ?? 0),
                          color: income)),
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'dash-expense'),
                          value: farmFmtMoney(d?.expenseToday ?? 0),
                          color: expense)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'dash-profit'),
                          value: farmFmtMoney(d?.profitToday ?? 0),
                          color: (d?.profitToday ?? 0) >= 0 ? income : expense)),
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'dash-sales-value'),
                          value: farmFmtMoney(d?.salesValue ?? 0))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: FarmStat(
                          label: ft(context, 'total-outstanding'),
                          value: farmFmtMoney(d?.outstanding ?? 0),
                          color: (d?.outstanding ?? 0) > 0 ? expense : null)),
                ],
              ),
            ],
          ),
        ),
        FarmSectionTitle(ft(context, 'quick-actions')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              quickButton(Icons.water_drop_outlined, ft(context, 'enter-milk'),
                  () => pushRoute(
                      context,
                      MilkEntryPage(
                          day: farmDayOnly(DateTime.now()),
                          session: DateTime.now().hour < 14
                              ? MilkSession.morning
                              : MilkSession.evening))),
              quickButton(Icons.point_of_sale_rounded, ft(context, 'new-sale'),
                  () => pushRoute(context, const SaleEditPage())),
              quickButton(
                  Icons.remove_circle_outline_rounded,
                  ft(context, 'add-expense'),
                  () => pushRoute(
                      context,
                      AddTransactionPage(
                          selectedIncome: false,
                          routesToPopAfterDelete: RoutesToPopAfterDelete.None))),
              quickButton(
                  Icons.add_circle_outline_rounded,
                  ft(context, 'add-income'),
                  () => pushRoute(
                      context,
                      AddTransactionPage(
                          selectedIncome: true,
                          routesToPopAfterDelete: RoutesToPopAfterDelete.None))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            children: [
              quickButton(Icons.pets_rounded, ft(context, 'animals'),
                  () => pushRoute(context, const AnimalsPage())),
              quickButton(Icons.bar_chart_rounded, ft(context, 'reports'),
                  () => pushRoute(context, const FarmReportsPage())),
              const Spacer(),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
