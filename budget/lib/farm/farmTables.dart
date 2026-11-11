// Dairy farm tables (schema v47+). See dairy_database_architecture.md.
//
// Rules:
//  * Additive only: nothing here changes Transactions/Wallets/Categories.
//  * Litres are NEVER stored in Transactions.amount.
//  * Money that actually moved is a Transactions row; farm rows only point to it
//    (CustomerPayments.transactionFk). Foreign keys are logical (not enforced by
//    SQLite in this app) so integrity is kept by FarmRepo (lib/farm/farmRepo.dart).
import 'package:budget/struct/databaseGlobal.dart';
import 'package:drift/drift.dart';

enum AnimalSex { female, male }

enum AnimalStatus { milking, dry, heifer, calf, bull, sick, sold, dead }

enum MilkSession { morning, evening }

enum MilkUsageType { home, calves, spoiled, other }

@DataClassName('FarmAnimal')
class Animals extends Table {
  TextColumn get animalPk => text().clientDefault(() => uuid.v4())();
  TextColumn get tagNumber => text().withLength(max: 100)();
  TextColumn get name => text().withLength(max: 250).nullable()();
  TextColumn get breed => text().withLength(max: 250).nullable()();
  IntColumn get sex => intEnum<AnimalSex>().withDefault(const Constant(0))();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  IntColumn get status =>
      intEnum<AnimalStatus>().withDefault(const Constant(0))();
  DateTimeColumn get statusDate => dateTime().nullable()();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  // Optional link to the expense Transactions row (logical FK)
  TextColumn get purchaseTransactionFk => text().nullable()();
  DateTimeColumn get soldDate => dateTime().nullable()();
  RealColumn get soldPrice => real().nullable()();
  // Optional link to the income Transactions row (logical FK)
  TextColumn get saleTransactionFk => text().nullable()();
  // File name (relative to the app documents directory) of the photo
  TextColumn get photoPath => text().nullable()();
  TextColumn get note => text().withLength(max: 500).withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {animalPk};

  @override
  List<Set<Column>> get uniqueKeys => [
        {tagNumber}
      ];
}

@DataClassName('FarmCustomer')
class Customers extends Table {
  TextColumn get customerPk => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text().withLength(max: 250)();
  TextColumn get phone => text().withLength(max: 100).nullable()();
  TextColumn get address => text().withLength(max: 500).nullable()();
  RealColumn get defaultPricePerLitre => real().nullable()();
  // Dues owed before the app was used
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  TextColumn get note => text().withLength(max: 500).withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {customerPk};
}

// Production only. animalFk == null means a herd-total entry.
@DataClassName('MilkRecord')
class MilkRecords extends Table {
  TextColumn get milkRecordPk => text().clientDefault(() => uuid.v4())();
  TextColumn get animalFk => text().nullable()();
  // Normalised to local midnight
  DateTimeColumn get recordDate => dateTime()();
  IntColumn get session => intEnum<MilkSession>()();
  RealColumn get litres => real()();
  TextColumn get note => text().withLength(max: 500).withDefault(const Constant(''))();
  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {milkRecordPk};

  // NOTE: NULL animalFk rows are not covered by this (SQLite treats NULLs as
  // distinct) - herd-total uniqueness is enforced in FarmRepo.
  @override
  List<Set<Column>> get uniqueKeys => [
        {animalFk, recordDate, session}
      ];
}

// A sale = litres x price. It does NOT create a Transaction by itself.
@DataClassName('MilkSale')
class MilkSales extends Table {
  TextColumn get milkSalePk => text().clientDefault(() => uuid.v4())();
  TextColumn get customerFk => text()();
  DateTimeColumn get saleDate => dateTime()();
  IntColumn get session => intEnum<MilkSession>().nullable()();
  RealColumn get litres => real()();
  // Price snapshot so later price changes never rewrite history
  RealColumn get pricePerLitre => real()();
  RealColumn get totalAmount => real()();
  TextColumn get note => text().withLength(max: 500).withDefault(const Constant(''))();
  BoolColumn get cancelled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {milkSalePk};
}

// Bridge between a customer payment and the income Transactions row.
// The amount lives ONLY on the Transactions row.
@DataClassName('CustomerPayment')
class CustomerPayments extends Table {
  TextColumn get customerPaymentPk => text().clientDefault(() => uuid.v4())();
  TextColumn get customerFk => text()();
  // Set when the payment was made against one specific sale
  TextColumn get milkSaleFk => text().nullable()();
  TextColumn get transactionFk => text()();
  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {customerPaymentPk};

  // One transaction can never be attributed to two payments
  @override
  List<Set<Column>> get uniqueKeys => [
        {transactionFk}
      ];
}

// Non-sale uses of milk (home, calves, spoiled, other)
@DataClassName('MilkUsageEntry')
class MilkUsageLogs extends Table {
  TextColumn get milkUsagePk => text().clientDefault(() => uuid.v4())();
  DateTimeColumn get usageDate => dateTime()();
  IntColumn get usageType => intEnum<MilkUsageType>()();
  RealColumn get litres => real()();
  TextColumn get note => text().withLength(max: 500).withDefault(const Constant(''))();
  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {milkUsagePk};
}
