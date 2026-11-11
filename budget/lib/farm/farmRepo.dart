// All reads/writes for the dairy tables live here so UI code stays small and
// every multi-row write is atomic (database.transaction).
//
// Rules (see dairy_database_architecture.md):
//  * litres are NEVER written to Transactions.amount
//  * a sale creates no money; each payment = one income Transaction + one
//    CustomerPayments link row, created in ONE database transaction
//  * customer balance = openingBalance + sum(non-cancelled sales) - sum(payments)
import 'package:budget/database/tables.dart';
import 'package:budget/farm/farmCategories.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:drift/drift.dart';

DateTime farmDayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime farmNextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
DateTime farmMonthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime farmNextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);
double farmRound2(double v) => (v * 100).round() / 100;
String? _nullIfEmpty(String? s) {
  if (s == null) return null;
  final String t = s.trim();
  return t.isEmpty ? null : t;
}

bool farmIsValidNumber(double? v) =>
    v != null && !v.isNaN && !v.isInfinite;

class DayMilk {
  final double morning;
  final double evening;
  const DayMilk(this.morning, this.evening);
  double get total => morning + evening;
}

class CustomerBalance {
  final FarmCustomer customer;
  final double salesTotal; // opening balance included
  final double paidTotal;
  const CustomerBalance(this.customer, this.salesTotal, this.paidTotal);
  double get balance => farmRound2(salesTotal - paidTotal);
}

class LedgerEntry {
  final DateTime date;
  final bool isPayment;
  final double amount; // always positive
  final String label;
  final String? milkSalePk;
  final String? customerPaymentPk;
  final bool cancelled;
  const LedgerEntry({
    required this.date,
    required this.isPayment,
    required this.amount,
    required this.label,
    this.milkSalePk,
    this.customerPaymentPk,
    this.cancelled = false,
  });
}

class FarmDashboardData {
  int totalAnimals = 0;
  int milking = 0;
  int dry = 0;
  int sick = 0;
  double morning = 0;
  double evening = 0;
  double soldLitres = 0;
  double salesValue = 0;
  double usedLitres = 0;
  double incomeToday = 0;
  double expenseToday = 0;
  double outstanding = 0;
  double get totalMilk => morning + evening;
  double get unaccounted => totalMilk - soldLitres - usedLitres;
  double get profitToday => incomeToday - expenseToday;
}

class MonthReport {
  DateTime month = DateTime.now();
  double totalMilk = 0;
  int daysWithMilk = 0;
  double herdEntryLitres = 0;
  double bestDayLitres = 0;
  DateTime? bestDay;
  Map<String, double> litresByAnimal = {}; // animalPk -> litres
  double soldLitres = 0;
  double salesValue = 0;
  double cashCollectedFromMilk = 0;
  Map<MilkUsageType, double> usage = {};
  double income = 0;
  double expenses = 0;
  Map<String, double> incomeByCategory = {}; // categoryPk -> amount
  Map<String, double> expenseByCategory = {};
  double totalOutstanding = 0;
  double get usedLitres => usage.values.fold(0.0, (a, b) => a + b);
  double get unaccounted => totalMilk - soldLitres - usedLitres;
  double get profit => income - expenses;
  double get averagePerDay => daysWithMilk == 0 ? 0 : totalMilk / daysWithMilk;
}

class FarmRepo {
  static FinanceDatabase get _db => database;

  /// Emits whenever any table the dairy screens read from changes.
  static Stream<dynamic> changes() {
    return _db.customSelect('SELECT 1', readsFrom: {
      _db.transactions,
      _db.animals,
      _db.customers,
      _db.milkRecords,
      _db.milkSales,
      _db.customerPayments,
      _db.milkUsageLogs,
    }).watch();
  }

  // ------------------------------------------------------------ animals

  static Stream<List<FarmAnimal>> watchAnimals({bool includeArchived = false}) {
    final q = _db.select(_db.animals);
    if (!includeArchived) q.where((a) => a.archived.equals(false));
    q.orderBy([(a) => OrderingTerm.asc(a.tagNumber)]);
    return q.watch();
  }

  static Future<List<FarmAnimal>> getAnimals() {
    return (_db.select(_db.animals)
          ..where((a) => a.archived.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.tagNumber)]))
        .get();
  }

  static Future<List<FarmAnimal>> getAllAnimalsIncludingArchived() {
    return _db.select(_db.animals).get();
  }

  static Future<List<FarmAnimal>> getMilkingAnimals() async {
    final List<FarmAnimal> all = await getAnimals();
    return all.where((a) => a.status == AnimalStatus.milking).toList();
  }

  static Future<bool> isTagTaken(String tag, {String? exceptPk}) async {
    final String t = tag.trim().toLowerCase();
    final List<FarmAnimal> all = await getAllAnimalsIncludingArchived();
    return all.any((a) =>
        a.tagNumber.trim().toLowerCase() == t && a.animalPk != exceptPk);
  }

  /// Creates (animalPk == null) or updates an animal. Returns its pk.
  static Future<String> saveAnimal({
    String? animalPk,
    required String tagNumber,
    String? name,
    String? breed,
    required AnimalSex sex,
    DateTime? dateOfBirth,
    required AnimalStatus status,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? photoPath,
    required String note,
  }) async {
    final DateTime now = DateTime.now();
    if (animalPk == null) {
      final String pk = uuid.v4();
      await _db.into(_db.animals).insert(AnimalsCompanion(
            animalPk: Value(pk),
            tagNumber: Value(tagNumber.trim()),
            name: Value(_nullIfEmpty(name)),
            breed: Value(_nullIfEmpty(breed)),
            sex: Value(sex),
            dateOfBirth: Value(dateOfBirth),
            status: Value(status),
            statusDate: Value(now),
            purchaseDate: Value(purchaseDate),
            purchasePrice: Value(purchasePrice),
            photoPath: Value(photoPath),
            note: Value(note.trim()),
            dateCreated: Value(now),
            dateTimeModified: Value(now),
          ));
      return pk;
    }
    final FarmAnimal? old = await (_db.select(_db.animals)
          ..where((a) => a.animalPk.equals(animalPk)))
        .getSingleOrNull();
    await (_db.update(_db.animals)..where((a) => a.animalPk.equals(animalPk)))
        .write(AnimalsCompanion(
      tagNumber: Value(tagNumber.trim()),
      name: Value(_nullIfEmpty(name)),
      breed: Value(_nullIfEmpty(breed)),
      sex: Value(sex),
      dateOfBirth: Value(dateOfBirth),
      status: Value(status),
      statusDate: Value(old != null && old.status == status
          ? old.statusDate
          : now),
      purchaseDate: Value(purchaseDate),
      purchasePrice: Value(purchasePrice),
      photoPath: Value(photoPath),
      note: Value(note.trim()),
      dateTimeModified: Value(now),
    ));
    return animalPk;
  }

  static Future<void> setAnimalArchived(String animalPk, bool archived) async {
    await (_db.update(_db.animals)..where((a) => a.animalPk.equals(animalPk)))
        .write(AnimalsCompanion(
      archived: Value(archived),
      dateTimeModified: Value(DateTime.now()),
    ));
  }

  // --------------------------------------------------------------- milk

  static Future<List<MilkRecord>> getMilkRecords(
      DateTime start, DateTime endExclusive) {
    return (_db.select(_db.milkRecords)
          ..where((r) =>
              r.recordDate.isBiggerOrEqualValue(start) &
              r.recordDate.isSmallerThanValue(endExclusive)))
        .get();
  }

  static Future<DayMilk> milkForDay(DateTime day) async {
    final DateTime d = farmDayOnly(day);
    final List<MilkRecord> rows = await getMilkRecords(d, farmNextDay(d));
    double morning = 0;
    double evening = 0;
    for (final MilkRecord r in rows) {
      if (r.session == MilkSession.morning) {
        morning += r.litres;
      } else {
        evening += r.litres;
      }
    }
    return DayMilk(morning, evening);
  }

  /// Existing per-cow litres for a day+session (animalPk -> litres) and the
  /// herd-total litres (null if none).
  static Future<({Map<String, double> perCow, double? herd})> milkEntries(
      DateTime day, MilkSession session) async {
    final DateTime d = farmDayOnly(day);
    final List<MilkRecord> rows = await getMilkRecords(d, farmNextDay(d));
    final Map<String, double> perCow = {};
    double? herd;
    for (final MilkRecord r in rows) {
      if (r.session != session) continue;
      if (r.animalFk == null) {
        herd = (herd ?? 0) + r.litres;
      } else {
        perCow[r.animalFk!] = (perCow[r.animalFk!] ?? 0) + r.litres;
      }
    }
    return (perCow: perCow, herd: herd);
  }

  static Future<void> _upsertMilk(
      String? animalPk, DateTime day, MilkSession session, double? litres,
      {String note = ''}) async {
    final List<MilkRecord> existing = await (_db.select(_db.milkRecords)
          ..where((r) =>
              (animalPk == null
                  ? r.animalFk.isNull()
                  : r.animalFk.equals(animalPk)) &
              r.recordDate.equals(day) &
              r.session.equals(session.index)))
        .get();
    if (litres == null || litres <= 0) {
      // Empty / zero means "no record": remove every existing row
      for (final MilkRecord e in existing) {
        await (_db.delete(_db.milkRecords)
              ..where((r) => r.milkRecordPk.equals(e.milkRecordPk)))
            .go();
      }
      return;
    }
    // Keep the first row, remove duplicates (only possible for herd rows)
    for (int i = 1; i < existing.length; i++) {
      await (_db.delete(_db.milkRecords)
            ..where((r) => r.milkRecordPk.equals(existing[i].milkRecordPk)))
          .go();
    }
    final DateTime now = DateTime.now();
    if (existing.isNotEmpty) {
      await (_db.update(_db.milkRecords)
            ..where((r) => r.milkRecordPk.equals(existing.first.milkRecordPk)))
          .write(MilkRecordsCompanion(
        litres: Value(litres),
        dateTimeModified: Value(now),
      ));
    } else {
      await _db.into(_db.milkRecords).insert(MilkRecordsCompanion(
            milkRecordPk: Value(uuid.v4()),
            animalFk: Value(animalPk),
            recordDate: Value(day),
            session: Value(session),
            litres: Value(litres),
            note: Value(note),
            dateCreated: Value(now),
            dateTimeModified: Value(now),
          ));
    }
  }

  /// Saves one session in a single atomic step. A null/<=0 value removes that
  /// cow's record. [herdTotal] (if mode is herd) replaces the herd row.
  static Future<void> saveMilkSession({
    required DateTime day,
    required MilkSession session,
    required Map<String, double?> litresByAnimal,
    bool updateHerdTotal = false,
    double? herdTotal,
  }) async {
    final DateTime d = farmDayOnly(day);
    await _db.transaction(() async {
      for (final MapEntry<String, double?> e in litresByAnimal.entries) {
        await _upsertMilk(e.key, d, session, e.value);
      }
      if (updateHerdTotal) {
        await _upsertMilk(null, d, session, herdTotal);
      }
    });
  }

  /// litres per day (local midnight key) in [start, endExclusive)
  static Future<Map<DateTime, double>> litresPerDay(
      DateTime start, DateTime endExclusive) async {
    final List<MilkRecord> rows = await getMilkRecords(start, endExclusive);
    final Map<DateTime, double> out = {};
    for (final MilkRecord r in rows) {
      final DateTime k = farmDayOnly(r.recordDate);
      out[k] = (out[k] ?? 0) + r.litres;
    }
    return out;
  }

  static Future<List<MilkRecord>> milkRecordsForDay(DateTime day) {
    final DateTime d = farmDayOnly(day);
    return getMilkRecords(d, farmNextDay(d));
  }

  // -------------------------------------------------------------- usage

  static Future<List<MilkUsageEntry>> getUsage(
      DateTime start, DateTime endExclusive) {
    return (_db.select(_db.milkUsageLogs)
          ..where((u) =>
              u.usageDate.isBiggerOrEqualValue(start) &
              u.usageDate.isSmallerThanValue(endExclusive))
          ..orderBy([(u) => OrderingTerm.desc(u.usageDate)]))
        .get();
  }

  static Stream<List<MilkUsageEntry>> watchRecentUsage({int days = 60}) {
    final DateTime start = farmDayOnly(DateTime.now())
        .subtract(Duration(days: days));
    return (_db.select(_db.milkUsageLogs)
          ..where((u) => u.usageDate.isBiggerOrEqualValue(start))
          ..orderBy([(u) => OrderingTerm.desc(u.usageDate)]))
        .watch();
  }

  static Future<void> addUsage({
    required DateTime date,
    required MilkUsageType type,
    required double litres,
    String note = '',
  }) async {
    final DateTime now = DateTime.now();
    await _db.into(_db.milkUsageLogs).insert(MilkUsageLogsCompanion(
          milkUsagePk: Value(uuid.v4()),
          usageDate: Value(farmDayOnly(date)),
          usageType: Value(type),
          litres: Value(litres),
          note: Value(note.trim()),
          dateCreated: Value(now),
          dateTimeModified: Value(now),
        ));
  }

  static Future<void> deleteUsage(String milkUsagePk) async {
    await (_db.delete(_db.milkUsageLogs)
          ..where((u) => u.milkUsagePk.equals(milkUsagePk)))
        .go();
  }

  // ---------------------------------------------------------- customers

  static Stream<List<FarmCustomer>> watchCustomers() {
    return (_db.select(_db.customers)
          ..where((c) => c.archived.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  static Future<List<FarmCustomer>> getCustomers() {
    return (_db.select(_db.customers)
          ..where((c) => c.archived.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  static Future<FarmCustomer?> getCustomer(String customerPk) {
    return (_db.select(_db.customers)
          ..where((c) => c.customerPk.equals(customerPk)))
        .getSingleOrNull();
  }

  static Future<String> saveCustomer({
    String? customerPk,
    required String name,
    String? phone,
    String? address,
    double? defaultPricePerLitre,
    double openingBalance = 0,
    String note = '',
  }) async {
    final DateTime now = DateTime.now();
    if (customerPk == null) {
      final String pk = uuid.v4();
      await _db.into(_db.customers).insert(CustomersCompanion(
            customerPk: Value(pk),
            name: Value(name.trim()),
            phone: Value(_nullIfEmpty(phone)),
            address: Value(_nullIfEmpty(address)),
            defaultPricePerLitre: Value(defaultPricePerLitre),
            openingBalance: Value(farmRound2(openingBalance)),
            note: Value(note.trim()),
            dateCreated: Value(now),
            dateTimeModified: Value(now),
          ));
      return pk;
    }
    await (_db.update(_db.customers)
          ..where((c) => c.customerPk.equals(customerPk)))
        .write(CustomersCompanion(
      name: Value(name.trim()),
      phone: Value(_nullIfEmpty(phone)),
      address: Value(_nullIfEmpty(address)),
      defaultPricePerLitre: Value(defaultPricePerLitre),
      openingBalance: Value(farmRound2(openingBalance)),
      note: Value(note.trim()),
      dateTimeModified: Value(now),
    ));
    return customerPk;
  }

  static Future<void> setCustomerArchived(String customerPk, bool v) async {
    await (_db.update(_db.customers)
          ..where((c) => c.customerPk.equals(customerPk)))
        .write(CustomersCompanion(
      archived: Value(v),
      dateTimeModified: Value(DateTime.now()),
    ));
  }

  // -------------------------------------------------- sales and payments

  static Future<List<MilkSale>> getSales(
      DateTime start, DateTime endExclusive) {
    return (_db.select(_db.milkSales)
          ..where((s) =>
              s.saleDate.isBiggerOrEqualValue(start) &
              s.saleDate.isSmallerThanValue(endExclusive))
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
        .get();
  }

  static Future<List<MilkSale>> getSalesForCustomer(String customerPk) {
    return (_db.select(_db.milkSales)
          ..where((s) => s.customerFk.equals(customerPk))
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
        .get();
  }

  /// Payments joined to their income transaction (orphan links are ignored by
  /// the INNER JOIN). Optionally for one customer.
  static Future<List<({CustomerPayment payment, Transaction transaction})>>
      getPayments({String? customerPk}) async {
    final query = _db.select(_db.customerPayments).join([
      innerJoin(
        _db.transactions,
        _db.transactions.transactionPk
            .equalsExp(_db.customerPayments.transactionFk),
      ),
    ]);
    if (customerPk != null) {
      query.where(_db.customerPayments.customerFk.equals(customerPk));
    }
    final rows = await query.get();
    return rows
        .map((row) => (
              payment: row.readTable(_db.customerPayments),
              transaction: row.readTable(_db.transactions),
            ))
        .toList();
  }

  static Future<String> _insertPayment({
    required FarmCustomer customer,
    String? milkSalePk,
    required double amount,
    required String walletPk,
    required DateTime date,
    required String note,
    required String incomeName,
  }) async {
    final String txPk = uuid.v4();
    final DateTime now = DateTime.now();
    final DateTime when =
        DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second);
    // Income Transaction: the ONLY place the money amount is stored.
    await _db.createOrUpdateTransaction(Transaction(
      transactionPk: txPk,
      name: incomeName + ' - ' + customer.name,
      amount: farmRound2(amount),
      note: note.trim(),
      categoryFk: FarmCategories.milkSales,
      walletFk: walletPk,
      dateCreated: when,
      income: true,
      paid: true,
      skipPaid: false,
    ));
    final String paymentPk = uuid.v4();
    await _db.into(_db.customerPayments).insert(CustomerPaymentsCompanion(
          customerPaymentPk: Value(paymentPk),
          customerFk: Value(customer.customerPk),
          milkSaleFk: Value(milkSalePk),
          transactionFk: Value(txPk),
          dateCreated: Value(now),
        ));
    return paymentPk;
  }

  /// Records a sale. If [paidNow] > 0 the payment (income transaction + link)
  /// is created in the same atomic step. Throws on failure; nothing persists.
  static Future<String> addSale({
    required String customerPk,
    required DateTime date,
    MilkSession? session,
    required double litres,
    required double pricePerLitre,
    String note = '',
    double paidNow = 0,
    String? walletPk,
    required String incomeName,
  }) async {
    if (!(litres > 0) || !farmIsValidNumber(litres)) throw 'invalid-litres';
    if (!(pricePerLitre >= 0) || !farmIsValidNumber(pricePerLitre)) {
      throw 'invalid-price';
    }
    final double total = farmRound2(litres * pricePerLitre);
    return await _db.transaction(() async {
      final FarmCustomer? customer = await getCustomer(customerPk);
      if (customer == null) throw 'customer-missing';
      final String salePk = uuid.v4();
      final DateTime now = DateTime.now();
      await _db.into(_db.milkSales).insert(MilkSalesCompanion(
            milkSalePk: Value(salePk),
            customerFk: Value(customerPk),
            saleDate: Value(farmDayOnly(date)),
            session: Value(session),
            litres: Value(litres),
            pricePerLitre: Value(pricePerLitre),
            totalAmount: Value(total),
            note: Value(note.trim()),
            dateCreated: Value(now),
            dateTimeModified: Value(now),
          ));
      if (paidNow > 0) {
        if (walletPk == null) throw 'wallet-missing';
        await _insertPayment(
          customer: customer,
          milkSalePk: salePk,
          amount: paidNow > total ? total : paidNow,
          walletPk: walletPk,
          date: date,
          note: '',
          incomeName: incomeName,
        );
      }
      return salePk;
    });
  }

  static Future<void> recordPayment({
    required String customerPk,
    String? milkSalePk,
    required double amount,
    required String walletPk,
    required DateTime date,
    String note = '',
    required String incomeName,
  }) async {
    if (!(amount > 0) || !farmIsValidNumber(amount)) throw 'invalid-amount';
    await _db.transaction(() async {
      final FarmCustomer? customer = await getCustomer(customerPk);
      if (customer == null) throw 'customer-missing';
      await _insertPayment(
        customer: customer,
        milkSalePk: milkSalePk,
        amount: amount,
        walletPk: walletPk,
        date: date,
        note: note,
        incomeName: incomeName,
      );
    });
  }

  /// Deletes the payment link AND its income transaction together.
  static Future<void> deletePayment(CustomerPayment payment) async {
    await _db.transaction(() async {
      await (_db.delete(_db.customerPayments)
            ..where(
                (p) => p.customerPaymentPk.equals(payment.customerPaymentPk)))
          .go();
      await _db.deleteTransaction(payment.transactionFk,
          updateSharedEntry: false);
    });
  }

  static Future<bool> saleHasPayments(String milkSalePk) async {
    final List<CustomerPayment> rows = await (_db.select(_db.customerPayments)
          ..where((p) => p.milkSaleFk.equals(milkSalePk)))
        .get();
    return rows.isNotEmpty;
  }

  static Future<void> setSaleCancelled(String milkSalePk, bool cancelled) async {
    await (_db.update(_db.milkSales)
          ..where((s) => s.milkSalePk.equals(milkSalePk)))
        .write(MilkSalesCompanion(
      cancelled: Value(cancelled),
      dateTimeModified: Value(DateTime.now()),
    ));
  }

  static Future<List<CustomerBalance>> customerBalances() async {
    final List<FarmCustomer> customers = await getCustomers();
    final List<MilkSale> sales = await _db.select(_db.milkSales).get();
    final payments = await getPayments();
    final Map<String, double> salesByCustomer = {};
    for (final MilkSale s in sales) {
      if (s.cancelled) continue;
      salesByCustomer[s.customerFk] =
          (salesByCustomer[s.customerFk] ?? 0) + s.totalAmount;
    }
    final Map<String, double> paidByCustomer = {};
    for (final p in payments) {
      paidByCustomer[p.payment.customerFk] =
          (paidByCustomer[p.payment.customerFk] ?? 0) + p.transaction.amount;
    }
    return customers
        .map((c) => CustomerBalance(
              c,
              c.openingBalance + (salesByCustomer[c.customerPk] ?? 0),
              paidByCustomer[c.customerPk] ?? 0,
            ))
        .toList();
  }

  static Future<CustomerBalance?> customerBalance(String customerPk) async {
    final List<CustomerBalance> all = await customerBalances();
    for (final CustomerBalance b in all) {
      if (b.customer.customerPk == customerPk) return b;
    }
    return null;
  }

  static Future<List<LedgerEntry>> ledger(FarmCustomer customer,
      {required String saleLabel, required String paymentLabel}) async {
    final List<MilkSale> sales = await getSalesForCustomer(customer.customerPk);
    final payments = await getPayments(customerPk: customer.customerPk);
    final List<LedgerEntry> out = [];
    for (final MilkSale s in sales) {
      out.add(LedgerEntry(
        date: s.saleDate,
        isPayment: false,
        amount: s.totalAmount,
        label: saleLabel,
        milkSalePk: s.milkSalePk,
        cancelled: s.cancelled,
      ));
    }
    for (final p in payments) {
      out.add(LedgerEntry(
        date: p.transaction.dateCreated,
        isPayment: true,
        amount: p.transaction.amount,
        label: paymentLabel,
        customerPaymentPk: p.payment.customerPaymentPk,
        milkSalePk: p.payment.milkSaleFk,
      ));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  // ---------------------------------------------------------- dashboard

  static bool _countsAsMoney(Transaction t) {
    if (!t.paid) return false;
    if (t.categoryFk == '0') return false; // balance correction
    if (t.pairedTransactionFk != null) return false; // wallet transfer
    if (t.type == TransactionSpecialType.credit ||
        t.type == TransactionSpecialType.debt) return false; // loans
    return true;
  }

  static Future<List<Transaction>> _transactionsBetween(
      DateTime start, DateTime endExclusive) async {
    final List<Transaction> rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.dateCreated.isBiggerOrEqualValue(start) &
              t.dateCreated.isSmallerThanValue(endExclusive)))
        .get();
    return rows.where(_countsAsMoney).toList();
  }

  static Future<FarmDashboardData> loadDashboard() async {
    final FarmDashboardData d = FarmDashboardData();
    final DateTime today = farmDayOnly(DateTime.now());
    final DateTime tomorrow = farmNextDay(today);

    final List<FarmAnimal> animals = await getAnimals();
    for (final FarmAnimal a in animals) {
      if (a.status == AnimalStatus.sold || a.status == AnimalStatus.dead) {
        continue;
      }
      d.totalAnimals++;
      if (a.status == AnimalStatus.milking) d.milking++;
      if (a.status == AnimalStatus.dry) d.dry++;
      if (a.status == AnimalStatus.sick) d.sick++;
    }

    final DayMilk milk = await milkForDay(today);
    d.morning = milk.morning;
    d.evening = milk.evening;

    final List<MilkSale> sales = await getSales(today, tomorrow);
    for (final MilkSale s in sales) {
      if (s.cancelled) continue;
      d.soldLitres += s.litres;
      d.salesValue += s.totalAmount;
    }
    final List<MilkUsageEntry> usage = await getUsage(today, tomorrow);
    for (final MilkUsageEntry u in usage) {
      d.usedLitres += u.litres;
    }

    final List<Transaction> tx = await _transactionsBetween(today, tomorrow);
    for (final Transaction t in tx) {
      if (t.income) {
        d.incomeToday += t.amount.abs();
      } else {
        d.expenseToday += t.amount.abs();
      }
    }

    final List<CustomerBalance> balances = await customerBalances();
    for (final CustomerBalance b in balances) {
      if (b.balance > 0) d.outstanding += b.balance;
    }
    return d;
  }

  // ------------------------------------------------------------- report

  static Future<MonthReport> loadMonthReport(DateTime anyDayInMonth) async {
    final DateTime start = farmMonthStart(anyDayInMonth);
    final DateTime end = farmNextMonth(anyDayInMonth);
    final MonthReport r = MonthReport();
    r.month = start;

    final List<MilkRecord> records = await getMilkRecords(start, end);
    final Map<DateTime, double> perDay = {};
    for (final MilkRecord m in records) {
      r.totalMilk += m.litres;
      final DateTime k = farmDayOnly(m.recordDate);
      perDay[k] = (perDay[k] ?? 0) + m.litres;
      if (m.animalFk == null) {
        r.herdEntryLitres += m.litres;
      } else {
        r.litresByAnimal[m.animalFk!] =
            (r.litresByAnimal[m.animalFk!] ?? 0) + m.litres;
      }
    }
    r.daysWithMilk = perDay.length;
    perDay.forEach((day, l) {
      if (l > r.bestDayLitres) {
        r.bestDayLitres = l;
        r.bestDay = day;
      }
    });

    final List<MilkSale> sales = await getSales(start, end);
    for (final MilkSale s in sales) {
      if (s.cancelled) continue;
      r.soldLitres += s.litres;
      r.salesValue += s.totalAmount;
    }
    final payments = await getPayments();
    for (final p in payments) {
      final DateTime t = p.transaction.dateCreated;
      if (!t.isBefore(start) && t.isBefore(end)) {
        r.cashCollectedFromMilk += p.transaction.amount;
      }
    }
    final List<MilkUsageEntry> usage = await getUsage(start, end);
    for (final MilkUsageEntry u in usage) {
      r.usage[u.usageType] = (r.usage[u.usageType] ?? 0) + u.litres;
    }

    final List<Transaction> tx = await _transactionsBetween(start, end);
    for (final Transaction t in tx) {
      final double a = t.amount.abs();
      if (t.income) {
        r.income += a;
        r.incomeByCategory[t.categoryFk] =
            (r.incomeByCategory[t.categoryFk] ?? 0) + a;
      } else {
        r.expenses += a;
        r.expenseByCategory[t.categoryFk] =
            (r.expenseByCategory[t.categoryFk] ?? 0) + a;
      }
    }
    final List<CustomerBalance> balances = await customerBalances();
    for (final CustomerBalance b in balances) {
      if (b.balance > 0) r.totalOutstanding += b.balance;
    }
    return r;
  }
}
