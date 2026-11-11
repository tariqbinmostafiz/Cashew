import 'dart:async';
import 'dart:math' as math;
import 'package:budget/colors.dart';
import 'package:budget/farm/animalsPage.dart';
import 'package:budget/farm/farmReportsPage.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

String _rawNumber(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

/// Main "Milk" tab: day navigator, totals, quick entry, 14-day chart, by cow.
class MilkPage extends StatefulWidget {
  const MilkPage({Key? key, this.backButton = false}) : super(key: key);
  final bool backButton;

  @override
  State<MilkPage> createState() => _MilkPageState();
}

class _MilkPageState extends State<MilkPage> {
  DateTime day = farmDayOnly(DateTime.now());
  DayMilk milk = const DayMilk(0, 0);
  List<MilkRecord> records = [];
  Map<String, FarmAnimal> animalsById = {};
  Map<DateTime, double> perDay = {};
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
    final DateTime d = day;
    final List<MilkRecord> recs = await FarmRepo.milkRecordsForDay(d);
    final DayMilk m = await FarmRepo.milkForDay(d);
    final List<FarmAnimal> animals =
        await FarmRepo.getAllAnimalsIncludingArchived();
    final DateTime start = DateTime(d.year, d.month, d.day - 13);
    final Map<DateTime, double> pd =
        await FarmRepo.litresPerDay(start, farmNextDay(d));
    if (!mounted || d != day) return;
    setState(() {
      records = recs;
      milk = m;
      animalsById = {for (final FarmAnimal a in animals) a.animalPk: a};
      perDay = pd;
    });
  }

  void changeDay(DateTime d) {
    setState(() => day = farmDayOnly(d));
    load();
  }

  Widget chart(BuildContext context) {
    final List<DateTime> days = [
      for (int i = 13; i >= 0; i--) DateTime(day.year, day.month, day.day - i)
    ];
    double maxY = 0;
    for (final DateTime d in days) {
      maxY = math.max(maxY, perDay[d] ?? 0);
    }
    final Color barColor = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY <= 0 ? 10 : maxY * 1.2,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(days[i].day.toString(),
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: perDay[days[i]] ?? 0,
                    width: 10,
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isToday = day == farmDayOnly(DateTime.now());

    // per-cow totals for the selected day
    final Map<String, double> morningBy = {};
    final Map<String, double> eveningBy = {};
    double herdLitres = 0;
    for (final MilkRecord r in records) {
      if (r.animalFk == null) {
        herdLitres += r.litres;
      } else if (r.session == MilkSession.morning) {
        morningBy[r.animalFk!] = (morningBy[r.animalFk!] ?? 0) + r.litres;
      } else {
        eveningBy[r.animalFk!] = (eveningBy[r.animalFk!] ?? 0) + r.litres;
      }
    }
    final Set<String> cowIds = {...morningBy.keys, ...eveningBy.keys};
    final List<String> orderedCows = cowIds.toList()
      ..sort((a, b) => (animalsById[a]?.tagNumber ?? '')
          .compareTo(animalsById[b]?.tagNumber ?? ''));

    return PageFramework(
      title: ft(context, 'milk-production'),
      backButton: widget.backButton,
      dragDownToDismiss: widget.backButton,
      horizontalPaddingConstrained: true,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FarmStepper(
                label: isToday
                    ? ft(context, 'today') + ' \u2022 ' + farmFmtDate(context, day)
                    : farmFmtDate(context, day),
                onPrevious: () => changeDay(
                    DateTime(day.year, day.month, day.day - 1)),
                onNext: isToday
                    ? null
                    : () => changeDay(farmNextDay(day)),
                onTapLabel: () async {
                  final DateTime? d = await farmPickDate(context, day,
                      last: DateTime.now());
                  if (d != null) changeDay(d);
                },
              ),
              FarmCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: FarmStat(
                            label: ft(context, 'morning'),
                            value: farmFmtLitres(milk.morning) + ' ' + ft(context, 'litres-short'))),
                    Expanded(
                        child: FarmStat(
                            label: ft(context, 'evening'),
                            value: farmFmtLitres(milk.evening) + ' ' + ft(context, 'litres-short'))),
                    Expanded(
                        child: FarmStat(
                            label: ft(context, 'total'),
                            value: farmFmtLitres(milk.total) + ' ' + ft(context, 'litres-short'),
                            color: Theme.of(context).colorScheme.primary,
                            big: false)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Button(
                          label: ft(context, 'enter-morning'),
                          icon: Icons.wb_sunny_outlined,
                          onTap: () => pushRoute(
                              context,
                              MilkEntryPage(
                                  day: day, session: MilkSession.morning)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Button(
                          label: ft(context, 'enter-evening'),
                          icon: Icons.nights_stay_outlined,
                          onTap: () => pushRoute(
                              context,
                              MilkEntryPage(
                                  day: day, session: MilkSession.evening)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FarmSectionTitle(ft(context, 'last-14-days')),
              FarmCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                child: chart(context),
              ),
              FarmSectionTitle(ft(context, 'per-cow-today')),
              if (orderedCows.isEmpty && herdLitres == 0)
                NoResults(message: ft(context, 'no-milk-today'))
              else
                FarmCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      for (final String id in orderedCows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFont(
                                  text: (animalsById[id]?.tagNumber ?? '?') +
                                      ((animalsById[id]?.name ?? '').isEmpty
                                          ? ''
                                          : '  ' + animalsById[id]!.name!),
                                  fontSize: 15,
                                  maxLines: 1,
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: TextFont(
                                  text: farmFmtLitres(morningBy[id] ?? 0),
                                  fontSize: 14,
                                  textAlign: TextAlign.end,
                                  textColor: getColor(context, 'textLight'),
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: TextFont(
                                  text: farmFmtLitres(eveningBy[id] ?? 0),
                                  fontSize: 14,
                                  textAlign: TextAlign.end,
                                  textColor: getColor(context, 'textLight'),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: TextFont(
                                  text: farmFmtLitres(
                                      (morningBy[id] ?? 0) + (eveningBy[id] ?? 0)),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (herdLitres > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                  child: TextFont(
                                      text: ft(context, 'herd-entries'),
                                      fontSize: 15)),
                              TextFont(
                                text: farmFmtLitres(herdLitres),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Button(
                          label: ft(context, 'milk-usage'),
                          icon: Icons.local_drink_outlined,
                          onTap: () =>
                              pushRoute(context, const MilkUsagePage()),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Button(
                          label: ft(context, 'reports'),
                          icon: Icons.bar_chart_rounded,
                          onTap: () =>
                              pushRoute(context, const FarmReportsPage()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ],
    );
  }
}

/// One-screen entry grid for a session (per cow) or a herd total.
class MilkEntryPage extends StatefulWidget {
  const MilkEntryPage({Key? key, required this.day, required this.session})
      : super(key: key);
  final DateTime day;
  final MilkSession session;

  @override
  State<MilkEntryPage> createState() => _MilkEntryPageState();
}

class _MilkEntryPageState extends State<MilkEntryPage> {
  late DateTime day;
  late MilkSession session;
  bool herdMode = false;
  bool loading = true;
  bool saving = false;
  double? existingHerd;
  List<FarmAnimal> animals = [];
  final Map<String, TextEditingController> controllers = {};
  final TextEditingController herdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    day = farmDayOnly(widget.day);
    session = widget.session;
    load();
  }

  @override
  void dispose() {
    for (final TextEditingController c in controllers.values) {
      c.dispose();
    }
    herdController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final List<FarmAnimal> milking = await FarmRepo.getMilkingAnimals();
    final entries = await FarmRepo.milkEntries(day, session);
    for (final TextEditingController c in controllers.values) {
      c.dispose();
    }
    controllers.clear();
    for (final FarmAnimal a in milking) {
      final double? v = entries.perCow[a.animalPk];
      controllers[a.animalPk] =
          TextEditingController(text: v == null ? '' : _rawNumber(v));
    }
    herdController.text =
        entries.herd == null ? '' : _rawNumber(entries.herd!);
    if (!mounted) return;
    setState(() {
      animals = milking;
      existingHerd = entries.herd;
      herdMode = milking.isEmpty ||
          (entries.herd != null && entries.perCow.isEmpty);
      loading = false;
    });
  }

  Future<void> copyYesterday() async {
    final DateTime prev = DateTime(day.year, day.month, day.day - 1);
    final entries = await FarmRepo.milkEntries(prev, session);
    if (!mounted) return;
    setState(() {
      if (herdMode) {
        herdController.text =
            entries.herd == null ? '' : _rawNumber(entries.herd!);
      } else {
        for (final FarmAnimal a in animals) {
          final double? v = entries.perCow[a.animalPk];
          controllers[a.animalPk]!.text = v == null ? '' : _rawNumber(v);
        }
      }
    });
  }

  double runningTotal() {
    if (herdMode) return farmParseNumber(herdController.text) ?? 0;
    double t = 0;
    for (final TextEditingController c in controllers.values) {
      t += farmParseNumber(c.text) ?? 0;
    }
    return t;
  }

  Future<void> save() async {
    if (saving) return;
    final Map<String, double?> values = {};
    bool tooLarge = false;
    if (herdMode) {
      final String t = herdController.text.trim();
      if (t.isNotEmpty) {
        final double? v = farmParseNumber(t);
        if (!farmIsValidNumber(v) || v! < 0) {
          farmMessage(ft(context, 'invalid-number'), warning: true);
          return;
        }
        if (v > 2000) tooLarge = true;
      }
    } else {
      for (final FarmAnimal a in animals) {
        final String t = controllers[a.animalPk]!.text.trim();
        if (t.isEmpty) {
          values[a.animalPk] = null;
          continue;
        }
        final double? v = farmParseNumber(t);
        if (!farmIsValidNumber(v) || v! < 0) {
          farmMessage(ft(context, 'invalid-number') + ' (' + a.tagNumber + ')',
              warning: true);
          return;
        }
        if (v > 100) tooLarge = true;
        values[a.animalPk] = v;
      }
    }
    if (tooLarge &&
        !await farmConfirm(context, ft(context, 'amount-too-large'))) {
      return;
    }
    setState(() => saving = true);
    try {
      await FarmRepo.saveMilkSession(
        day: day,
        session: session,
        litresByAnimal: values,
        updateHerdTotal: herdMode,
        herdTotal: herdMode ? farmParseNumber(herdController.text) : null,
      );
      if (!mounted) return;
      farmMessage(ft(context, 'saved'));
      Navigator.of(context).pop();
    } catch (e) {
      print('Save milk failed: ' + e.toString());
      if (!mounted) return;
      setState(() => saving = false);
      farmMessage(ft(context, 'save-failed-nothing-changed'), warning: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double total = runningTotal();
    return PageFramework(
      title: ft(context, 'enter-milk'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      resizeToAvoidBottomInset: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : save,
        icon: const Icon(Icons.check_rounded),
        label: Text(ft(context, 'save')),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FarmStepper(
                label: farmFmtDate(context, day),
                onPrevious: () {
                  setState(() => day = DateTime(day.year, day.month, day.day - 1));
                  load();
                },
                onNext: day == farmDayOnly(DateTime.now())
                    ? null
                    : () {
                        setState(() => day = farmNextDay(day));
                        load();
                      },
                onTapLabel: () async {
                  final DateTime? d =
                      await farmPickDate(context, day, last: DateTime.now());
                  if (d != null) {
                    setState(() => day = farmDayOnly(d));
                    load();
                  }
                },
              ),
              FarmChoice<MilkSession>(
                options: {
                  MilkSession.morning: ft(context, 'morning'),
                  MilkSession.evening: ft(context, 'evening'),
                },
                selected: session,
                onSelected: (v) {
                  setState(() => session = v);
                  load();
                },
              ),
              FarmChoice<bool>(
                options: {
                  false: ft(context, 'per-cow'),
                  true: ft(context, 'herd-total'),
                },
                selected: herdMode,
                onSelected: (v) => setState(() => herdMode = v),
              ),
              FarmCard(
                child: Row(
                  children: [
                    Expanded(
                      child: FarmStat(
                        label: ft(context, 'total'),
                        value: farmFmtLitres(total) + ' ' + ft(context, 'litres-short'),
                        big: true,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: copyYesterday,
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: Text(ft(context, 'copy-yesterday')),
                    ),
                  ],
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (herdMode) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: TextField(
                    controller: herdController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 22),
                    decoration: InputDecoration(
                      labelText: ft(context, 'herd-total-litres'),
                      suffixText: ft(context, 'litres-short'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ] else if (animals.isEmpty)
                NoResults(message: ft(context, 'no-milking-animals'))
              else ...[
                if (existingHerd != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                    child: Text(ft(context, 'herd-entry-exists'),
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 13)),
                  ),
                for (int i = 0; i < animals.length; i++)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Row(
                      children: [
                        AnimalAvatar(animal: animals[i], size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFont(
                            text: animals[i].tagNumber +
                                ((animals[i].name ?? '').isEmpty
                                    ? ''
                                    : '  ' + animals[i].name!),
                            fontSize: 16,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: controllers[animals[i].animalPk],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: i == animals.length - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              isDense: true,
                              suffixText: ft(context, 'litres-short'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 110),
            ],
          ),
        ),
      ],
    );
  }
}

/// Milk used for something other than sale (home, calves, spoiled, other).
class MilkUsagePage extends StatelessWidget {
  const MilkUsagePage({Key? key}) : super(key: key);

  String typeLabel(BuildContext context, MilkUsageType t) {
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

  Future<void> addDialog(BuildContext context) async {
    DateTime date = farmDayOnly(DateTime.now());
    MilkUsageType type = MilkUsageType.home;
    final TextEditingController litres = TextEditingController();
    final TextEditingController note = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ft(ctx, 'add-usage')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final DateTime? d = await farmPickDate(ctx, date,
                        last: DateTime.now());
                    if (d != null) setState(() => date = farmDayOnly(d));
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(farmFmtDate(ctx, date)),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final MilkUsageType t in MilkUsageType.values)
                      ChoiceChip(
                        label: Text(typeLabel(ctx, t)),
                        selected: type == t,
                        onSelected: (_) => setState(() => type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: litres,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: ft(ctx, 'litres'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: InputDecoration(
                    labelText: ft(ctx, 'note') + ' (' + ft(ctx, 'optional') + ')',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ft(ctx, 'cancel'))),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(ft(ctx, 'save'))),
          ],
        ),
      ),
    );
    if (ok == true) {
      final double? v = farmParseNumber(litres.text);
      if (!farmIsValidNumber(v) || v! <= 0) {
        farmMessage(ft(context, 'invalid-number'), warning: true);
      } else {
        await FarmRepo.addUsage(
            date: date, type: type, litres: v, note: note.text);
        farmMessage(ft(context, 'saved'));
      }
    }
    litres.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: ft(context, 'milk-usage'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(ft(context, 'add-usage')),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<List<MilkUsageEntry>>(
            stream: FarmRepo.watchRecentUsage(),
            builder: (context, snapshot) {
              final List<MilkUsageEntry> list = snapshot.data ?? [];
              if (list.isEmpty) {
                return NoResults(message: ft(context, 'no-usage'));
              }
              return Column(
                children: [
                  for (final MilkUsageEntry u in list)
                    FarmCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFont(
                                  text: typeLabel(context, u.usageType) +
                                      '  \u2022  ' +
                                      farmFmtLitres(u.litres) +
                                      ' ' +
                                      ft(context, 'litres-short'),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                TextFont(
                                  text: farmFmtDate(context, u.usageDate) +
                                      (u.note.isEmpty ? '' : '  \u2022  ' + u.note),
                                  fontSize: 13,
                                  textColor: getColor(context, 'textLight'),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              if (await farmConfirm(
                                  context, ft(context, 'delete') + '?')) {
                                await FarmRepo.deleteUsage(u.milkUsagePk);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
