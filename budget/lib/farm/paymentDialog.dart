import 'package:budget/database/tables.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:flutter/material.dart';

/// Dialog to receive a payment from a customer. Creates the income
/// transaction + link atomically through FarmRepo.recordPayment.
/// Returns true if a payment was saved.
Future<bool> showReceivePaymentDialog(
  BuildContext context, {
  required FarmCustomer customer,
  String? milkSalePk,
  double? suggestedAmount,
}) async {
  final List<TransactionWallet> wallets = await database.getAllWallets();
  if (wallets.isEmpty) return false;
  String walletPk = wallets.first.walletPk;
  DateTime date = farmDayOnly(DateTime.now());
  final TextEditingController amount = TextEditingController(
      text: (suggestedAmount != null && suggestedAmount > 0)
          ? farmRound2(suggestedAmount).toString()
          : '');
  final TextEditingController note = TextEditingController();
  if (!context.mounted) return false;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(ft(ctx, 'receive-payment') + ' - ' + customer.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: ft(ctx, 'payment-amount'),
                  prefixText: '\u09F3 ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: walletPk,
                decoration: InputDecoration(
                  labelText: ft(ctx, 'wallet'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final TransactionWallet w in wallets)
                    DropdownMenuItem(value: w.walletPk, child: Text(w.name)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => walletPk = v);
                },
              ),
              TextButton.icon(
                onPressed: () async {
                  final DateTime? d =
                      await farmPickDate(ctx, date, last: DateTime.now());
                  if (d != null) setState(() => date = farmDayOnly(d));
                },
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(farmFmtDate(ctx, date)),
              ),
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
  bool saved = false;
  if (ok == true) {
    final double? v = farmParseNumber(amount.text);
    if (!farmIsValidNumber(v) || v! <= 0) {
      farmMessage(ft(context, 'invalid-number'), warning: true);
    } else {
      try {
        await FarmRepo.recordPayment(
          customerPk: customer.customerPk,
          milkSalePk: milkSalePk,
          amount: v,
          walletPk: walletPk,
          date: date,
          note: note.text,
          incomeName: ft(context, 'milk-income-name'),
        );
        saved = true;
        farmMessage(ft(context, 'saved'));
      } catch (e) {
        print('Record payment failed: ' + e.toString());
        farmMessage(ft(context, 'save-failed-nothing-changed'), warning: true);
      }
    }
  }
  amount.dispose();
  note.dispose();
  return saved;
}
