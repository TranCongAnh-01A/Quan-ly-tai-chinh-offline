import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mone_jour/data/models/expense.dart';
import 'package:mone_jour/data/repositories/expense_repository.dart';
import 'package:mone_jour/logic/expense/expense_cubit.dart';
import 'package:mone_jour/logic/expense/expense_state.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

/// Fake dung cho registerFallbackValue — khong can gia tri hop le
class FakeExpense extends Fake implements Expense {}

void main() {
  late ExpenseCubit cubit;
  late MockExpenseRepository mockRepo;

  // Dang ky fallback value de mocktail biet kieu Expense
  setUpAll(() {
    registerFallbackValue(FakeExpense());
  });

  final sampleExpense = Expense()
    ..id = 1
    ..amount = 50000
    ..category = 'food'
    ..date = DateTime(2026, 8, 1)
    ..isIncome = false
    ..isTransfer = false
    ..source = FundingSource.cash
    ..createdAt = DateTime(2026, 8, 1);

  /// loadMonth() chi con 1 truy van duy nhat: toan bo giao dich toi het thang
  /// dang xem. Moi con so deu duoc cubit tinh tu danh sach nay.
  void stubLoadMonth({List<Expense> expenses = const []}) {
    when(() => mockRepo.getByDateRange(any(), any())).thenAnswer((_) async => expenses);
  }

  Expense makeExpense({
    int id = 1,
    double amount = 10000,
    String category = 'food',
    required DateTime date,
    bool isIncome = false,
    bool isTransfer = false,
    FundingSource source = FundingSource.cash,
  }) {
    return Expense()
      ..id = id
      ..amount = amount
      ..category = category
      ..date = date
      ..isIncome = isIncome
      ..isTransfer = isTransfer
      ..source = source
      ..createdAt = date;
  }

  setUp(() {
    mockRepo = MockExpenseRepository();
    when(() => mockRepo.watchChanges()).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    cubit.close();
  });

  test('Initial state la ExpenseLoading', () {
    stubLoadMonth();
    cubit = ExpenseCubit(repository: mockRepo);
    expect(cubit.state, isA<ExpenseLoading>());
  });

  test('loadMonth() voi data rong emit ExpenseLoaded voi balance = 0', () async {
    stubLoadMonth();
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    expect(cubit.state, isA<ExpenseLoaded>());
    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.expenses, isEmpty);
    expect(loaded.balance, 0.0);
    expect(loaded.totalExpense, 0.0);
    expect(loaded.totalIncome, 0.0);
  });

  test('loadMonth() emit ExpenseLoaded voi tong thu chi dung', () async {
    stubLoadMonth(expenses: [
      makeExpense(id: 1, amount: 5000000, date: DateTime(2026, 8, 1), isIncome: true),
      makeExpense(id: 2, amount: 50000, date: DateTime(2026, 8, 5)),
    ]);
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.totalExpense, 50000.0);
    expect(loaded.totalIncome, 5000000.0);
    expect(loaded.selectedMonth.month, 8);
  });

  test('loadMonth() chi dung 1 truy van cho toan bo phep tinh', () async {
    stubLoadMonth();
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    // Truoc day: 6 truy van (2 lan quet toan bo lich su + 4 truy van tong)
    verify(() => mockRepo.getByDateRange(any(), any())).called(1);
    verifyNever(() => mockRepo.getTotalExpense(any(), any()));
    verifyNever(() => mockRepo.getTotalIncome(any(), any()));
  });

  test('loadMonth() tach giao dich thang dang xem khoi lich su cu', () async {
    stubLoadMonth(expenses: [
      // Thang 8 (dang xem)
      makeExpense(id: 1, amount: 30000, date: DateTime(2026, 8, 10)),
      // Thang truoc — chi tinh vao so du luy ke, khong vao tong thang nay
      makeExpense(id: 2, amount: 2000000, date: DateTime(2026, 7, 1), isIncome: true),
      makeExpense(id: 3, amount: 500000, date: DateTime(2026, 7, 15)),
    ]);
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.expenses.length, 1);
    expect(loaded.totalExpense, 30000.0);
    expect(loaded.totalIncome, 0.0);
    expect(loaded.carriedOverBalance, 1500000.0);
  });

  test('loadMonth() tinh quy tien mat / tai khoan qua moi lich su', () async {
    stubLoadMonth(expenses: [
      makeExpense(id: 1, amount: 1000000, date: DateTime(2026, 7, 1), isIncome: true, source: FundingSource.bank),
      makeExpense(id: 2, amount: 200000, date: DateTime(2026, 8, 2), source: FundingSource.cash),
      makeExpense(id: 3, amount: 500000, date: DateTime(2026, 8, 3), isIncome: true, source: FundingSource.cash),
    ]);
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.totalBank, 1000000.0);
    expect(loaded.totalCash, 300000.0);
  });

  test('loadMonth() chuyen tien noi bo doi cho 2 quy, khong tinh vao thu chi', () async {
    stubLoadMonth(expenses: [
      makeExpense(id: 1, amount: 1000000, date: DateTime(2026, 8, 1), isIncome: true, source: FundingSource.cash),
      // Chuyen 400k tu tien mat sang tai khoan
      makeExpense(id: 2, amount: 400000, date: DateTime(2026, 8, 2), isTransfer: true, source: FundingSource.cash),
    ]);
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.totalCash, 600000.0);
    expect(loaded.totalBank, 400000.0);
    expect(loaded.totalIncome, 1000000.0);
    expect(loaded.totalExpense, 0.0);
  });

  test('loadMonth() khi loi emit ExpenseError', () async {
    when(() => mockRepo.getByDateRange(any(), any())).thenThrow(Exception('DB Error'));
    when(() => mockRepo.watchChanges()).thenAnswer((_) => const Stream.empty());

    cubit = ExpenseCubit(repository: mockRepo);
    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    expect(cubit.state, isA<ExpenseError>());
  });

  test('addExpense() goi repository.add() dung 1 lan', () async {
    stubLoadMonth();
    when(() => mockRepo.add(any())).thenAnswer((_) async {});
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.addExpense(
      amount: 100000,
      category: 'food',
      date: DateTime(2026, 8, 10),
      isIncome: false,
    );

    verify(() => mockRepo.add(any())).called(1);
  });

  test('updateExpense() goi repository.update() dung 1 lan', () async {
    stubLoadMonth();
    when(() => mockRepo.update(any())).thenAnswer((_) async {});
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.updateExpense(sampleExpense);

    verify(() => mockRepo.update(any())).called(1);
  });

  test('deleteExpense() goi repository.delete() voi dung ID', () async {
    stubLoadMonth();
    when(() => mockRepo.getById(any())).thenAnswer((_) async => sampleExpense);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.deleteExpense(1);

    verify(() => mockRepo.delete(1)).called(1);
  });

  test('deleteExpense() doc giao dich truoc khi xoa de don anh hoa don', () async {
    final withReceipt = Expense()
      ..id = 7
      ..amount = 50000
      ..category = 'food'
      ..date = DateTime(2026, 8, 1)
      ..isIncome = false
      ..createdAt = DateTime(2026, 8, 1)
      ..receiptImagePath = 'receipt_123.jpg';

    stubLoadMonth();
    when(() => mockRepo.getById(7)).thenAnswer((_) async => withReceipt);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.deleteExpense(7);

    // Phai doc ban ghi TRUOC khi xoa — sau khi xoa thi khong con duong dan anh
    verifyInOrder([
      () => mockRepo.getById(7),
      () => mockRepo.delete(7),
    ]);
  });

  test('deleteExpense() khong loi khi giao dich khong ton tai', () async {
    stubLoadMonth();
    when(() => mockRepo.getById(any())).thenAnswer((_) async => null);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.deleteExpense(999);

    verify(() => mockRepo.delete(999)).called(1);
  });

  test('previousMonth() chuyen ve thang 7 khi dang o thang 8', () async {
    stubLoadMonth();
    cubit = ExpenseCubit(repository: mockRepo);
    await cubit.loadMonth(DateTime(2026, 8));

    stubLoadMonth();
    await cubit.previousMonth();
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.selectedMonth.month, 7);
    expect(loaded.selectedMonth.year, 2026);
  });

  test('nextMonth() chuyen sang thang 9 khi dang o thang 8', () async {
    stubLoadMonth();
    cubit = ExpenseCubit(repository: mockRepo);
    await cubit.loadMonth(DateTime(2026, 8));

    stubLoadMonth();
    await cubit.nextMonth();
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.selectedMonth.month, 9);
    expect(loaded.selectedMonth.year, 2026);
  });

  test('nextMonth() thang 12 chuyen sang thang 1 nam sau', () async {
    stubLoadMonth();
    cubit = ExpenseCubit(repository: mockRepo);
    await cubit.loadMonth(DateTime(2026, 12));

    stubLoadMonth();
    await cubit.nextMonth();
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.selectedMonth.month, 1);
    expect(loaded.selectedMonth.year, 2027);
  });
}
