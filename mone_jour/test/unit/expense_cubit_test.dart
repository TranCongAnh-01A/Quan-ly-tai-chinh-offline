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

  void stubLoadMonth({
    List<Expense> expenses = const [],
    double totalExpense = 0.0,
    double totalIncome = 0.0,
  }) {
    when(() => mockRepo.getByDateRange(any(), any())).thenAnswer((_) async => expenses);
    when(() => mockRepo.getTotalExpense(any(), any())).thenAnswer((_) async => totalExpense);
    when(() => mockRepo.getTotalIncome(any(), any())).thenAnswer((_) async => totalIncome);
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
    stubLoadMonth(
      expenses: [sampleExpense],
      totalExpense: 50000,
      totalIncome: 5000000,
    );
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.loadMonth(DateTime(2026, 8));
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as ExpenseLoaded;
    expect(loaded.totalExpense, 50000.0);
    expect(loaded.totalIncome, 5000000.0);
    expect(loaded.selectedMonth.month, 8);
  });

  test('loadMonth() khi loi emit ExpenseError', () async {
    when(() => mockRepo.getByDateRange(any(), any())).thenThrow(Exception('DB Error'));
    when(() => mockRepo.getTotalExpense(any(), any())).thenThrow(Exception('DB Error'));
    when(() => mockRepo.getTotalIncome(any(), any())).thenThrow(Exception('DB Error'));
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
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    cubit = ExpenseCubit(repository: mockRepo);

    await cubit.deleteExpense(1);

    verify(() => mockRepo.delete(1)).called(1);
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
