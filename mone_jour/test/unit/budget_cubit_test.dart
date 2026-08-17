import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mone_jour/data/models/budget.dart';
import 'package:mone_jour/data/repositories/budget_repository.dart';
import 'package:mone_jour/data/repositories/expense_repository.dart';
import 'package:mone_jour/logic/budget/budget_cubit.dart';
import 'package:mone_jour/logic/budget/budget_state.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}
class MockExpenseRepository extends Mock implements ExpenseRepository {}

/// Fake cho registerFallbackValue — mocktail yeu cau khi dung any() voi object type
class FakeBudget extends Fake implements Budget {}

/// Helper tao Budget model cho test
Budget makeBudget({
  int id = 1,
  String categoryId = 'food',
  double amountLimit = 1000000,
  int month = 8,
  int year = 2026,
}) {
  return Budget()
    ..id = id
    ..categoryId = categoryId
    ..amountLimit = amountLimit
    ..month = month
    ..year = year;
}

void main() {
  late BudgetCubit cubit;
  late MockBudgetRepository mockBudgetRepo;
  late MockExpenseRepository mockExpenseRepo;

  setUpAll(() {
    registerFallbackValue(FakeBudget());
  });

  setUp(() {
    mockBudgetRepo = MockBudgetRepository();
    mockExpenseRepo = MockExpenseRepository();
    // Watchers phai tra ve Stream rong de Cubit khoi tao khong loi
    when(() => mockBudgetRepo.watchChanges()).thenAnswer((_) => const Stream.empty());
    when(() => mockExpenseRepo.watchChanges()).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    cubit.close();
  });

  // ── Khoi tao ────────────────────────────────────────────────────────────────

  test('Initial state la BudgetLoading', () {
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => []);
    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );
    expect(cubit.state, isA<BudgetLoading>());
  });

  // ── loadBudgets ──────────────────────────────────────────────────────────────

  test('loadBudgets() voi khong co budget emit BudgetLoaded voi danh sach rong', () async {
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => []);
    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );

    await cubit.loadBudgets(8, 2026);
    await Future.delayed(Duration.zero);

    expect(cubit.state, isA<BudgetLoaded>());
    final loaded = cubit.state as BudgetLoaded;
    expect(loaded.progresses, isEmpty);
  });

  test('loadBudgets() tinh BudgetProgress dung theo spending/limit', () async {
    final budget = makeBudget(amountLimit: 1000000);
    when(() => mockBudgetRepo.getByMonth(8, 2026)).thenAnswer((_) async => [budget]);
    when(() => mockExpenseRepo.getCategorySpending('food', 8, 2026)).thenAnswer((_) async => 500000);

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );

    await cubit.loadBudgets(8, 2026);
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as BudgetLoaded;
    expect(loaded.progresses.length, 1);
    final progress = loaded.progresses.first;
    expect(progress.categoryId, 'food');
    expect(progress.currentSpending, 500000);
    expect(progress.amountLimit, 1000000);
    expect(progress.ratio, 0.5);
    expect(progress.status, BudgetStatus.safe);
  });

  test('BudgetProgress.status la warning khi chi >= 80% han muc', () async {
    final budget = makeBudget(amountLimit: 1000000);
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => [budget]);
    when(() => mockExpenseRepo.getCategorySpending(any(), any(), any())).thenAnswer((_) async => 850000);

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );
    await cubit.loadBudgets(8, 2026);
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as BudgetLoaded;
    expect(loaded.progresses.first.status, BudgetStatus.warning);
  });

  test('BudgetProgress.status la exceeded khi chi >= 100% han muc', () async {
    final budget = makeBudget(amountLimit: 1000000);
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => [budget]);
    when(() => mockExpenseRepo.getCategorySpending(any(), any(), any())).thenAnswer((_) async => 1200000);

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );
    await cubit.loadBudgets(8, 2026);
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as BudgetLoaded;
    expect(loaded.progresses.first.status, BudgetStatus.exceeded);
    expect(loaded.progresses.first.remaining, -200000);
  });

  // ── setBudget ────────────────────────────────────────────────────────────────

  test('setBudget() goi budgetRepo.upsert() dung 1 lan', () async {
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetRepo.upsert(any())).thenAnswer((_) async {});

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );

    await cubit.setBudget(categoryId: 'food', amountLimit: 500000);

    verify(() => mockBudgetRepo.upsert(any())).called(1);
  });

  // ── removeBudget ─────────────────────────────────────────────────────────────

  test('removeBudget() goi budgetRepo.delete() voi dung ID', () async {
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetRepo.delete(any())).thenAnswer((_) async {});

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );

    await cubit.removeBudget(99);

    verify(() => mockBudgetRepo.delete(99)).called(1);
  });

  // ── checkBudgetWarning ───────────────────────────────────────────────────────

  test('checkBudgetWarning() tra ve null neu khong co budget', () async {
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetRepo.getByCategoryMonth(any(), any(), any())).thenAnswer((_) async => null);

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );

    final result = await cubit.checkBudgetWarning('food', 100000);
    expect(result, isNull);
  });

  test('checkBudgetWarning() tra ve BudgetProgress khi se vuot nguong 80%', () async {
    final budget = makeBudget(amountLimit: 1000000);
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetRepo.getByCategoryMonth('food', any(), any())).thenAnswer((_) async => budget);
    when(() => mockExpenseRepo.getCategorySpending('food', any(), any())).thenAnswer((_) async => 750000);

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );

    // Chi them 100k -> total 850k/1000k = 85% -> vuot nguong 80%
    final result = await cubit.checkBudgetWarning('food', 100000);
    expect(result, isNotNull);
    expect(result!.status, BudgetStatus.warning);
  });

  // ── BudgetProgress unit logic ─────────────────────────────────────────────────

  test('BudgetProgress.percentage tinh dung phan tram', () {
    const p = BudgetProgress(
      categoryId: 'food',
      amountLimit: 1000000,
      currentSpending: 850000,
      budgetId: 1,
    );
    expect(p.percentage, 85);
    expect(p.ratio, 0.85);
  });

  test('BudgetProgress.remaining tra ve so am khi vuot han muc', () {
    const p = BudgetProgress(
      categoryId: 'food',
      amountLimit: 1000000,
      currentSpending: 1200000,
      budgetId: 1,
    );
    expect(p.remaining, -200000);
  });

  test('BudgetLoaded.alerts chi chua cac progress dang canh bao hoac vuot', () async {
    final budgets = [
      makeBudget(id: 1, categoryId: 'food'),
      makeBudget(id: 2, categoryId: 'transport'),
      makeBudget(id: 3, categoryId: 'shopping'),
    ];
    when(() => mockBudgetRepo.getByMonth(any(), any())).thenAnswer((_) async => budgets);
    when(() => mockExpenseRepo.getCategorySpending('food', any(), any())).thenAnswer((_) async => 500000); // safe
    when(() => mockExpenseRepo.getCategorySpending('transport', any(), any())).thenAnswer((_) async => 850000); // warning
    when(() => mockExpenseRepo.getCategorySpending('shopping', any(), any())).thenAnswer((_) async => 1100000); // exceeded

    cubit = BudgetCubit(
      budgetRepository: mockBudgetRepo,
      expenseRepository: mockExpenseRepo,
    );
    await cubit.loadBudgets(8, 2026);
    await Future.delayed(Duration.zero);

    final loaded = cubit.state as BudgetLoaded;
    expect(loaded.progresses.length, 3);
    expect(loaded.alerts.length, 2); // transport + shopping
  });
}
