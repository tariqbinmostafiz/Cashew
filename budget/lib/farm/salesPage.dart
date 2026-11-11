import 'dart:async';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/farm/customersPage.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/farm/paymentDialog.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';

enum _PayMode { unpaid, full, partial }

/// "Sales" tab: month navigator, month summary and the list of sales.
class SalesPage extends StatefulWidget {
  const SalesPage({Key? key, this.backButton = false}) : super(key: key);
  final bool backButton;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  DateTime month = farmMonthStart(DateTime.now());
  List<MilkSale> sales = [];
  Map<String, FarmCustomer> customersById = {};
  Map<String, double> paidBySale = {};
  double litres = 0;
  double value = 0;
  double collected = 0;
  double outstanding = 0;
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
    final DateTime m = month;
    final DateTime end = farmNextMonth(m);
    final List<MilkSale> list = await FarmRepo.getSales(m, end);
    final List<CustomerBalance> balances = await FarmRepo.customerBalances();
    final payments = await FarmRepo.getPayments();
    final Map<String, double> bySale = {};
    double cash = 0;
    for (final p in payments) {
      final String? sk = p.payment.milkSaleFk;
      if (sk != null) bySale[sk] = (bySale[sk] ?? 0) + p.transaction.amount;
      final DateTime t = p.transaction.dateCreated;
      if (!t.isBefore(m) && t.isBefore(end)) cash += p.transaction.amount;
    }
    double l = 0;
    double v = 0;
    for (final MilkSale s in list) {
      if (s.cancelled) continue;
      l += s.litres;
      v += s.totalAmount;
    }
    double out = 0;
    for (final CustomerBalance b in balances) {
      if (b.balance > 0) out += b.balance;
    }
    // sales may belong to archived customers: look them all up
    final Map<String, FarmCustomer> byId = {
      for (final CustomerBalance b in balances) b.customer.customerPk: b.customer
    };
    for (final MilkSale s in list) {
      if (!byId.containsKey(s.customerFk)) {
        final FarmCustomer? c = await FarmRepo.getCustomer(s.customerFk);
        if (c != null) byId[s.customerFk] = c;
      }
    }
    if (!mounted || m != month) return;
    setState(() {
      sales = list;
      customersById = byId;
      paidBySale = bySale;
      litres = l;
      value = v;
      collected = cash;
      outstanding = out;
    });
  }

  void changeMonth(DateTime m) {
    setState(() => month = farmMonthStart(m));
    load();
  }

  Future<void> saleActions(MilkSale s) async {
    final FarmCustomer? c = customersById[s.customerFk];
    final double paid = paidBySale[s.milkSalePk] ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text((c?.name ?? '?') +
                  '  \u2022  ' +
                  farmFmtLitres(s.litres) +
                  ' ' +
                  ft(ctx, 'litres-short') +
                  ' \u00D7 ' +
                  farmFmtNumber(s.pricePerLitre)),
              subtitle: Text(farmFmtDate(ctx, s.saleDate) +
                  '  \u2022  ' +
                  farmFmtMoney(s.totalAmount)),
            ),
            if (!s.cancelled && c != null)
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(ft(ctx, 'receive-payment')),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final double remaining = s.totalAmount - paid;
                  await showReceivePaymentDialog(context,
                      customer: c,
                      milkSalePk: s.milkSalePk,
                      suggestedAmount: remaining > 0 ? remaining : null);
                },
              ),
            if (c != null)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(c.name),
                onTap: () {
                  Navigator.of(ctx).pop();
                  pushRoute(context,
                      CustomerDetailPage(customerPk: s.customerFk));
                },
              ),
            ListTile(
              leading: Icon(s.cancelled
                  ? Icons.restore_rounded
                  : Icons.cancel_outlined),
              title: Text(s.cancelled
                  ? ft(ctx, 'restore-sale')
                  : ft(ctx, 'cancel-sale')),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (!s.cancelled && await FarmRepo.saleHasPayments(s.milkSalePk)) {
                  farmMessage(ft(context, 'sale-has-payments'), warning: true);
                  return;
                }
                await FarmRepo.setSaleCancelled(s.milkSalePk, !s.cancelled);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime thisMonth = farmMonthStart(DateTime.now());
    final Color income = getColor(context, 'incomeAmount');
    final Color expense = getColor(context, 'expenseAmount');
    return PageFramework(
      title: ft(context, 'sales'),
      backButton: widget.backButton,
      dragDownToDismiss: widget.backButton,
      horizontalPaddingConstrained: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushRoute(context, const SaleEditPage()),
        icon: const Icon(Icons.add_rounded),
        label: Text(ft(context, 'new-sale')),
      ),
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
              FarmCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: FarmStat(
                                label: ft(context, 'litres'),
                                value: farmFmtLitres(litres))),
                        Expanded(
                            child: FarmStat(
                                label: ft(context, 'sales-value'),
                                value: farmFmtMoney(value))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: FarmStat(
                                label: ft(context, 'cash-collected'),
                                value: farmFmtMoney(collected),
                                color: income)),
                        Expanded(
                            child: FarmStat(
                                label: ft(context, 'total-outstanding'),
                                value: farmFmtMoney(outstanding),
                                color: outstanding > 0 ? expense : null)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                child: Button(
                  label: ft(context, 'customers'),
                  icon: Icons.people_alt_outlined,
                  onTap: () => pushRoute(context, const CustomersPage()),
                ),
              ),
              if (sales.isEmpty)
                NoResults(message: ft(context, 'no-sales'))
              else
                for (final MilkSale s in sales)
                  FarmCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    onTap: () => saleActions(s),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customersById[s.customerFk]?.name ?? '?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: s.cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              TextFont(
                                text: farmFmtDate(context, s.saleDate) +
                                    '  \u2022  ' +
                                    farmFmtLitres(s.litres) +
                                    ' ' +
                                    ft(context, 'litres-short') +
                                    ' \u00D7 ' +
                                    farmFmtNumber(s.pricePerLitre),
                                fontSize: 13,
                                textColor: getColor(context, 'textLight'),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextFont(
                              text: farmFmtMoney(s.totalAmount),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            Builder(builder: (context) {
                              if (s.cancelled) {
                                return Text(ft(context, 'cancelled'),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey));
                              }
                              final double paid =
                                  paidBySale[s.milkSalePk] ?? 0;
                              if (paid >= s.totalAmount - 0.005) {
                                return Text(ft(context, 'paid-full'),
                                    style: TextStyle(
                                        fontSize: 12, color: income));
                              }
                              if (paid > 0) {
                                return Text(ft(context, 'partial'),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.orange));
                              }
                              return Text(ft(context, 'unpaid'),
                                  style: TextStyle(
                                      fontSize: 12, color: expense));
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}

/// New sale (+ optional immediate payment).
class SaleEditPage extends StatefulWidget {
  const SaleEditPage({Key? key, this.customerPk}) : super(key: key);
  final String? customerPk;

  @override
  State<SaleEditPage> createState() => _SaleEditPageState();
}

class _SaleEditPageState extends State<SaleEditPage> {
  List<FarmCustomer> customers = [];
  List<TransactionWallet> wallets = [];
  String? customerPk;
  String? walletPk;
  DateTime date = farmDayOnly(DateTime.now());
  MilkSession? session;
  _PayMode payMode = _PayMode.unpaid;
  final TextEditingController litresController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController paidController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  bool saving = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    customerPk = widget.customerPk;
    init();
  }

  @override
  void dispose() {
    litresController.dispose();
    priceController.dispose();
    paidController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> init() async {
    final List<FarmCustomer> c = await FarmRepo.getCustomers();
    final List<TransactionWallet> w = await database.getAllWallets();
    if (!mounted) return;
    setState(() {
      customers = c;
      wallets = w;
      walletPk = w.isEmpty ? null : w.first.walletPk;
      loading = false;
    });
    if (customerPk != null) applyCustomerPrice(customerPk!);
  }

  Future<void> reloadCustomers({String? select}) async {
    final List<FarmCustomer> c = await FarmRepo.getCustomers();
    if (!mounted) return;
    setState(() {
      customers = c;
      if (select != null) customerPk = select;
    });
    if (select != null) applyCustomerPrice(select);
  }

  void applyCustomerPrice(String pk) {
    for (final FarmCustomer c in customers) {
      if (c.customerPk == pk && c.defaultPricePerLitre != null) {
        priceController.text = farmFmtNumber(c.defaultPricePerLitre!).replaceAll(',', '');
        setState(() {});
        return;
      }
    }
  }

  Future<void> useWalkIn() async {
    final String name = ft(context, 'walk-in');
    String? pk;
    for (final FarmCustomer c in customers) {
      if (c.name == name) pk = c.customerPk;
    }
    pk ??= await FarmRepo.saveCustomer(name: name);
    await reloadCustomers(select: pk);
  }

  double get litres => farmParseNumber(litresController.text) ?? 0;
  double get price => farmParseNumber(priceController.text) ?? 0;
  double get total => farmRound2(litres * price);

  Future<void> save() async {
    if (saving) return;
    if (customerPk == null) {
      farmMessage(ft(context, 'select-customer'), warning: true);
      return;
    }
    final double? l = farmParseNumber(litresController.text);
    final double? pr = farmParseNumber(priceController.text);
    if (!farmIsValidNumber(l) || l! <= 0 || !farmIsValidNumber(pr) || pr! < 0) {
      farmMessage(ft(context, 'invalid-number'), warning: true);
      return;
    }
    if (l > 2000 &&
        !await farmConfirm(context, ft(context, 'amount-too-large'))) {
      return;
    }
    double paidNow = 0;
    if (payMode == _PayMode.full) {
      paidNow = total;
    } else if (payMode == _PayMode.partial) {
      final double? v = farmParseNumber(paidController.text);
      if (!farmIsValidNumber(v) || v! <= 0 || v > total + 0.005) {
        farmMessage(ft(context, 'invalid-number'), warning: true);
        return;
      }
      paidNow = v;
    }
    if (paidNow > 0 && walletPk == null) {
      farmMessage(ft(context, 'error'), warning: true);
      return;
    }
    setState(() => saving = true);
    try {
      await FarmRepo.addSale(
        customerPk: customerPk!,
        date: date,
        session: session,
        litres: l,
        pricePerLitre: pr,
        note: noteController.text,
        paidNow: paidNow,
        walletPk: walletPk,
        incomeName: ft(context, 'milk-income-name'),
      );
      if (!mounted) return;
      farmMessage(ft(context, 'saved'));
      Navigator.of(context).pop();
    } catch (e) {
      print('Save sale failed: ' + e.toString());
      if (!mounted) return;
      setState(() => saving = false);
      farmMessage(ft(context, 'save-failed-nothing-changed'), warning: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: ft(context, 'new-sale'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      resizeToAvoidBottomInset: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading || saving ? null : save,
        icon: const Icon(Icons.check_rounded),
        label: Text(ft(context, 'save')),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FarmFieldLabel(ft(context, 'customer')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: customers.any((c) => c.customerPk == customerPk)
                                  ? customerPk
                                  : null,
                              isExpanded: true,
                              hint: Text(ft(context, 'select-customer')),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                              items: [
                                for (final FarmCustomer c in customers)
                                  DropdownMenuItem(
                                      value: c.customerPk, child: Text(c.name)),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => customerPk = v);
                                applyCustomerPrice(v);
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: ft(context, 'add-customer'),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            onPressed: () async {
                              await pushRoute(
                                  context, const CustomerEditPage());
                              await reloadCustomers();
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: TextButton(
                        onPressed: useWalkIn,
                        child: Text(ft(context, 'walk-in')),
                      ),
                    ),
                    FarmCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      onTap: () async {
                        final DateTime? d = await farmPickDate(context, date,
                            last: DateTime.now());
                        if (d != null) setState(() => date = farmDayOnly(d));
                      },
                      child: Row(
                        children: [
                          Expanded(child: TextFont(text: ft(context, 'date'), fontSize: 15)),
                          TextFont(
                            text: farmFmtDate(context, date),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.event_rounded, size: 18),
                        ],
                      ),
                    ),
                    FarmChoice<MilkSession?>(
                      options: {
                        null: ft(context, 'none'),
                        MilkSession.morning: ft(context, 'morning'),
                        MilkSession.evening: ft(context, 'evening'),
                      },
                      selected: session,
                      onSelected: (v) => setState(() => session = v),
                    ),
                    const SizedBox(height: 6),
                    TextInput(
                      labelText: ft(context, 'litres'),
                      controller: litresController,
                      icon: Icons.local_drink_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextInput(
                      labelText: ft(context, 'price-per-litre'),
                      controller: priceController,
                      icon: Icons.sell_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    FarmCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: FarmStat(
                              label: ft(context, 'sale-total'),
                              value: farmFmtMoney(total),
                              big: true,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FarmFieldLabel(ft(context, 'payment-status')),
                    FarmChoice<_PayMode>(
                      options: {
                        _PayMode.unpaid: ft(context, 'unpaid'),
                        _PayMode.full: ft(context, 'paid-full'),
                        _PayMode.partial: ft(context, 'partial'),
                      },
                      selected: payMode,
                      onSelected: (v) => setState(() => payMode = v),
                    ),
                    if (payMode != _PayMode.unpaid) ...[
                      if (payMode == _PayMode.partial)
                        TextInput(
                          labelText: ft(context, 'paid-now'),
                          controller: paidController,
                          icon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        child: DropdownButtonFormField<String>(
                          value: walletPk,
                          decoration: InputDecoration(
                            labelText: ft(context, 'wallet'),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final TransactionWallet w in wallets)
                              DropdownMenuItem(
                                  value: w.walletPk, child: Text(w.name)),
                          ],
                          onChanged: (v) => setState(() => walletPk = v),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextInput(
                      labelText: ft(context, 'note'),
                      controller: noteController,
                      icon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
        ),
      ],
    );
  }
}
