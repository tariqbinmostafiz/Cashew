import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter/material.dart';

/// Fixed primary keys of the dairy system categories. Code looks them up by
/// these keys, so they must never be renamed.
class FarmCategories {
  static const String milkSales = 'dairy_milk_sales';
  static const String animalSale = 'dairy_animal_sale';
  static const String otherIncome = 'dairy_other_income';
  static const String feed = 'dairy_feed';
  static const String vet = 'dairy_vet';
  static const String labour = 'dairy_labour';
  static const String electricity = 'dairy_electricity';
  static const String transport = 'dairy_transport';
  static const String equipment = 'dairy_equipment';
  static const String animalPurchase = 'dairy_animal_purchase';
  static const String breeding = 'dairy_breeding';
  static const String otherExpense = 'dairy_other_expense';

  static const List<String> all = [
    milkSales,
    animalSale,
    otherIncome,
    feed,
    vet,
    labour,
    electricity,
    transport,
    equipment,
    animalPurchase,
    breeding,
    otherExpense,
  ];

  static bool isSystem(String categoryPk) => all.contains(categoryPk);
}

TransactionCategory _cat(String pk, String nameKey, Color colour,
    String icon, bool income, int order) {
  return TransactionCategory(
    categoryPk: pk,
    name: ftNoContext(nameKey),
    colour: toHexString(colour),
    iconName: icon,
    dateCreated: DateTime.now(),
    dateTimeModified: null,
    order: order,
    income: income,
  );
}

/// The dairy category set. Used for fresh installs (as the default categories)
/// and added idempotently to existing databases by ensureDairyCategories().
List<TransactionCategory> dairyCategories() {
  return [
    _cat(FarmCategories.feed, 'cat-feed', Colors.green, 'organic-food.png',
        false, 0),
    _cat(FarmCategories.vet, 'cat-vet', Colors.red,
        'healthcare-and-medical.png', false, 1),
    _cat(FarmCategories.labour, 'cat-labour', Colors.blueGrey, 'briefcase.png',
        false, 2),
    _cat(FarmCategories.electricity, 'cat-electricity', Colors.yellow,
        'lightning-bolt.png', false, 3),
    _cat(FarmCategories.transport, 'cat-transport', Colors.orange,
        'delivery-truck.png', false, 4),
    _cat(FarmCategories.equipment, 'cat-equipment', Colors.brown, 'gears.png',
        false, 5),
    _cat(FarmCategories.animalPurchase, 'cat-animal-purchase', Colors.purple,
        'pet-bowl.png', false, 6),
    _cat(FarmCategories.breeding, 'cat-breeding', Colors.pink, 'heart.png',
        false, 7),
    _cat(FarmCategories.otherExpense, 'cat-other-expense', Colors.grey,
        'price-tag.png', false, 8),
    _cat(FarmCategories.milkSales, 'cat-milk-sales', Colors.blue, 'milk.png',
        true, 9),
    _cat(FarmCategories.animalSale, 'cat-animal-sale', Colors.teal,
        'money-bag.png', true, 10),
    _cat(FarmCategories.otherIncome, 'cat-other-income', Colors.lightGreen,
        'coin.png', true, 11),
  ];
}

/// Inserts any missing dairy system category (matched by fixed pk).
/// Never deletes or changes existing categories. Safe to run on every start.
Future<void> ensureDairyCategories() async {
  try {
    final List<TransactionCategory> existing =
        await database.select(database.categories).get();
    final Set<String> existingPks = existing.map((c) => c.categoryPk).toSet();
    int order = existing.length;
    for (final TransactionCategory c in dairyCategories()) {
      if (existingPks.contains(c.categoryPk)) continue;
      await database.createOrUpdateCategory(
        c.copyWith(order: order),
        updateSharedEntry: false,
      );
      order++;
    }
  } catch (e) {
    print('ensureDairyCategories failed: ' + e.toString());
  }
}

/// Creates Cash-friendly wallets once on a database that only has the single
/// default wallet. Existing wallets are never removed.
Future<void> ensureDairyWallets() async {
  try {
    if (appStateSettings['dairyWalletsSeeded'] == true) return;
    final List<TransactionWallet> wallets = await database.getAllWallets();
    if (wallets.length == 1) {
      final TransactionWallet first = wallets.first;
      int order = 1;
      for (final String nameKey in ['wallet-cash', 'wallet-mobile-banking']) {
        await database.createOrUpdateWallet(
          TransactionWallet(
            walletPk: '-1',
            name: ftNoContext(nameKey),
            dateCreated: DateTime.now(),
            order: order,
            currency: first.currency,
            currencyFormat: first.currencyFormat,
            decimals: first.decimals,
          ),
          insert: true,
        );
        order++;
      }
    }
    await updateSettings('dairyWalletsSeeded', true,
        updateGlobalState: false);
  } catch (e) {
    print('ensureDairyWallets failed: ' + e.toString());
  }
}

/// One-time defaults for the dairy layout on a device that already has stored
/// settings (fresh installs get the same values from defaultPreferences.dart).
/// Only changes navigation shortcuts and hides the budgets card on Home.
Future<void> applyDairyDefaultsOnce() async {
  try {
    if (appStateSettings['dairyDefaultsApplied'] == true) return;
    await updateSettings('customNavBarShortcut0', 'home',
        updateGlobalState: false);
    await updateSettings('customNavBarShortcut1', 'milk',
        updateGlobalState: false);
    await updateSettings('customNavBarShortcut2', 'sales',
        updateGlobalState: false);
    await updateSettings('showPinnedBudgets', false, updateGlobalState: false);
    await updateSettings('dairyDefaultsApplied', true,
        updateGlobalState: false);
  } catch (e) {
    print('applyDairyDefaultsOnce failed: ' + e.toString());
  }
}

/// Everything the dairy feature set needs at startup. Idempotent.
Future<void> initializeFarmData() async {
  await ensureDairyCategories();
  await ensureDairyWallets();
  await applyDairyDefaultsOnce();
}
