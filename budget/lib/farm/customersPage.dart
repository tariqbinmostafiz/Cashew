import 'dart:async';
import 'package:budget/colors.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/farm/paymentDialog.dart';
import 'package:budget/farm/salesPage.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/fab.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({Key? key}) : super(key: key);

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<CustomerBalance> balances = [];
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
    final List<CustomerBalance> b = await FarmRepo.customerBalances();
    if (!mounted) return;
    setState(() => balances = b);
  }

  @override
  Widget build(BuildContext context) {
    double outstanding = 0;
    for (final CustomerBalance b in balances) {
      if (b.balance > 0) outstanding += b.balance;
    }
    final Color expense = getColor(context, 'expenseAmount');
    final Color income = getColor(context, 'incomeAmount');
    return PageFramework(
      title: ft(context, 'customers'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      floatingActionButton: AddFAB(
        tooltip: ft(context, 'add-customer'),
        onTap: () => pushRoute(context, const CustomerEditPage()),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              FarmCard(
                child: Row(
                  children: [
                    Expanded(
                      child: FarmStat(
                        label: ft(context, 'total-outstanding'),
                        value: farmFmtMoney(outstanding),
                        big: true,
                        color: outstanding > 0 ? expense : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (balances.isEmpty)
                NoResults(message: ft(context, 'no-customers'))
              else
                for (final CustomerBalance b in balances)
                  FarmCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    onTap: () => pushRoute(context,
                        CustomerDetailPage(customerPk: b.customer.customerPk)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFont(
                                text: b.customer.name,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                maxLines: 1,
                              ),
                              if ((b.customer.phone ?? '').isNotEmpty)
                                TextFont(
                                  text: b.customer.phone!,
                                  fontSize: 13,
                                  textColor: getColor(context, 'textLight'),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextFont(
                              text: farmFmtMoney(b.balance.abs()),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              textColor: b.balance > 0.005 ? expense : income,
                            ),
                            TextFont(
                              text: b.balance > 0.005
                                  ? ft(context, 'balance')
                                  : (b.balance < -0.005
                                      ? ft(context, 'advance')
                                      : ''),
                              fontSize: 12,
                              textColor: getColor(context, 'textLight'),
                            ),
                          ],
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

class CustomerEditPage extends StatefulWidget {
  const CustomerEditPage({Key? key, this.customer}) : super(key: key);
  final FarmCustomer? customer;

  @override
  State<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends State<CustomerEditPage> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController priceController;
  late final TextEditingController openingController;
  late final TextEditingController noteController;
  String? nameError;
  bool saving = false;

  String _raw(double? v) {
    if (v == null) return '';
    return farmFmtNumber(v).replaceAll(',', '');
  }

  @override
  void initState() {
    super.initState();
    final FarmCustomer? c = widget.customer;
    nameController = TextEditingController(text: c?.name ?? '');
    phoneController = TextEditingController(text: c?.phone ?? '');
    addressController = TextEditingController(text: c?.address ?? '');
    priceController = TextEditingController(text: _raw(c?.defaultPricePerLitre));
    openingController = TextEditingController(
        text: (c == null || c.openingBalance == 0) ? '' : _raw(c.openingBalance));
    noteController = TextEditingController(text: c?.note ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    priceController.dispose();
    openingController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (nameController.text.trim().isEmpty) {
      setState(() => nameError = ft(context, 'required-field'));
      return;
    }
    double? price;
    if (priceController.text.trim().isNotEmpty) {
      price = farmParseNumber(priceController.text);
      if (!farmIsValidNumber(price) || price! < 0) {
        farmMessage(ft(context, 'invalid-number'), warning: true);
        return;
      }
    }
    double opening = 0;
    if (openingController.text.trim().isNotEmpty) {
      final double? o = farmParseNumber(openingController.text);
      if (!farmIsValidNumber(o)) {
        farmMessage(ft(context, 'invalid-number'), warning: true);
        return;
      }
      opening = o!;
    }
    setState(() => saving = true);
    try {
      await FarmRepo.saveCustomer(
        customerPk: widget.customer?.customerPk,
        name: nameController.text,
        phone: phoneController.text,
        address: addressController.text,
        defaultPricePerLitre: price,
        openingBalance: opening,
        note: noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      print('Save customer failed: ' + e.toString());
      if (!mounted) return;
      setState(() => saving = false);
      farmMessage(ft(context, 'save-failed-nothing-changed'), warning: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.customer != null;
    return PageFramework(
      title: isEdit ? ft(context, 'edit-customer') : ft(context, 'add-customer'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      resizeToAvoidBottomInset: true,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'customer-name'),
                controller: nameController,
                icon: Icons.person_outline_rounded,
                onChanged: (_) {
                  if (nameError != null) setState(() => nameError = null);
                },
              ),
              if (nameError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 4),
                  child: Text(nameError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'phone'),
                controller: phoneController,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'address'),
                controller: addressController,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'default-price'),
                controller: priceController,
                icon: Icons.sell_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'opening-balance'),
                controller: openingController,
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'note'),
                controller: noteController,
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Button(
                            label: ft(context, 'archive'),
                            onTap: () async {
                              if (!await farmConfirm(context,
                                  ft(context, 'archive-customer-confirm'))) {
                                return;
                              }
                              await FarmRepo.setCustomerArchived(
                                  widget.customer!.customerPk, true);
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              Navigator.of(context).maybePop();
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: Button(label: ft(context, 'save'), onTap: save),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    );
  }
}

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({Key? key, required this.customerPk})
      : super(key: key);
  final String customerPk;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  FarmCustomer? customer;
  CustomerBalance? balance;
  List<LedgerEntry> entries = [];
  late StreamSubscription<dynamic> sub;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    sub = FarmRepo.changes().listen((_) => load());
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    final FarmCustomer? c = await FarmRepo.getCustomer(widget.customerPk);
    if (c == null) {
      if (mounted) setState(() => loaded = true);
      return;
    }
    final CustomerBalance? b = await FarmRepo.customerBalance(widget.customerPk);
    final List<LedgerEntry> l = await FarmRepo.ledger(c,
        saleLabel: ft(context, 'ledger-sale'),
        paymentLabel: ft(context, 'ledger-payment'));
    if (!mounted) return;
    setState(() {
      customer = c;
      balance = b;
      entries = l;
      loaded = true;
    });
  }

  String statementText() {
    final FarmCustomer c = customer!;
    final StringBuffer sb = StringBuffer();
    sb.writeln(ft(context, 'statement') + ': ' + c.name);
    sb.writeln(ft(context, 'date') + ': ' + farmFmtDate(context, DateTime.now()));
    sb.writeln('');
    if (c.openingBalance != 0) {
      sb.writeln(ft(context, 'ledger-opening') + ': ' + farmFmtMoney(c.openingBalance));
    }
    for (final LedgerEntry e in entries.reversed) {
      if (e.cancelled) continue;
      sb.writeln(farmFmtDate(context, e.date) +
          '  ' +
          e.label +
          '  ' +
          (e.isPayment ? '-' : '+') +
          farmFmtMoney(e.amount));
    }
    sb.writeln('');
    sb.writeln(ft(context, 'balance') + ': ' + farmFmtMoney(balance?.balance ?? 0));
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final Color expense = getColor(context, 'expenseAmount');
    final Color income = getColor(context, 'incomeAmount');
    final FarmCustomer? c = customer;
    return PageFramework(
      title: c?.name ?? ft(context, 'customer'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      actions: [
        if (c != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: ft(context, 'edit'),
            onPressed: () async {
              await pushRoute(context, CustomerEditPage(customer: c));
              if (!mounted) return;
              final FarmCustomer? still =
                  await FarmRepo.getCustomer(widget.customerPk);
              if (still == null || still.archived) {
                if (mounted) Navigator.of(context).maybePop();
              } else {
                load();
              }
            },
          ),
        if (c != null)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: ft(context, 'share-statement'),
            onPressed: () =>
                shareToClipboard(statementText(), context: context),
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: !loaded
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : c == null
                  ? NoResults(message: ft(context, 'error'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FarmCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: FarmStat(
                                  label: (balance?.balance ?? 0) < -0.005
                                      ? ft(context, 'advance')
                                      : ft(context, 'balance'),
                                  value: farmFmtMoney(
                                      (balance?.balance ?? 0).abs()),
                                  big: true,
                                  color: (balance?.balance ?? 0) > 0.005
                                      ? expense
                                      : income,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Button(
                                    label: ft(context, 'receive-payment'),
                                    icon: Icons.payments_outlined,
                                    onTap: () => showReceivePaymentDialog(
                                      context,
                                      customer: c,
                                      suggestedAmount:
                                          (balance?.balance ?? 0) > 0
                                              ? balance!.balance
                                              : null,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Button(
                                    label: ft(context, 'new-sale'),
                                    icon: Icons.add_rounded,
                                    onTap: () => pushRoute(
                                        context,
                                        SaleEditPage(
                                            customerPk: c.customerPk)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FarmSectionTitle(ft(context, 'ledger')),
                        for (final LedgerEntry e in entries)
                          FarmCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  e.isPayment
                                      ? Icons.south_west_rounded
                                      : Icons.north_east_rounded,
                                  color: e.isPayment ? income : expense,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          decoration: e.cancelled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      TextFont(
                                        text: farmFmtDate(context, e.date) +
                                            (e.cancelled
                                                ? '  \u2022  ' +
                                                    ft(context, 'cancelled')
                                                : ''),
                                        fontSize: 12.5,
                                        textColor:
                                            getColor(context, 'textLight'),
                                      ),
                                    ],
                                  ),
                                ),
                                TextFont(
                                  text: (e.isPayment ? '-' : '+') +
                                      farmFmtMoney(e.amount),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  textColor: e.isPayment ? income : expense,
                                ),
                                if (e.isPayment)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20),
                                    onPressed: () async {
                                      if (!await farmConfirm(context,
                                          ft(context, 'delete-payment-confirm'))) {
                                        return;
                                      }
                                      final payments = await FarmRepo.getPayments(
                                          customerPk: c.customerPk);
                                      for (final p in payments) {
                                        if (p.payment.customerPaymentPk ==
                                            e.customerPaymentPk) {
                                          await FarmRepo.deletePayment(
                                              p.payment);
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        if (c.openingBalance != 0)
                          FarmCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(ft(context, 'ledger-opening'))),
                                TextFont(
                                  text: farmFmtMoney(c.openingBalance),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
