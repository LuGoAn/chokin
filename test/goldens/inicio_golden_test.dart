import 'dart:io';

import 'package:chokin/core/theme/app_theme.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';
import 'package:chokin/domain/entities/category.dart';
import 'package:chokin/domain/entities/credit_card.dart';
import 'package:chokin/domain/entities/inbox_notification.dart';
import 'package:chokin/domain/entities/person.dart';
import 'package:chokin/domain/entities/transaction.dart';
import 'package:chokin/presentation/screens/analytics/analytics_screen.dart';
import 'package:chokin/presentation/screens/categories/categories_management_screen.dart';
import 'package:chokin/presentation/screens/inbox/inbox_screen.dart';
import 'package:chokin/presentation/screens/invoices/invoices_screen.dart';
import 'package:chokin/presentation/screens/main_shell_screen.dart';
import 'package:chokin/presentation/screens/people/people_management_screen.dart';
import 'package:chokin/presentation/screens/reimbursements/reimbursements_screen.dart';
import 'package:chokin/presentation/screens/settings/settings_screen.dart';
import 'package:chokin/presentation/screens/transactions/new_transaction_screen.dart';
import 'package:chokin/presentation/screens/transactions/transaction_history_screen.dart';
import 'package:chokin/presentation/state/financial_state_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(file).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

FinancialState _sampleState() {
  final now = DateTime.now();
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));
  DateTime inDays(int d) => now.add(Duration(days: d));

  const nubank = CreditCard(id: 'nubank', name: 'Nubank', closingDay: 3, dueDay: 10, creditLimitCents: 500000);
  const inter = CreditCard(id: 'inter', name: 'Inter', closingDay: 28, dueDay: 5, creditLimitCents: 300000);
  final ana = Person(id: 'p_ana', name: 'Ana', createdAt: DateTime(2026, 1, 1));

  var state = FinancialState.reconciled(
    cards: const [nubank, inter],
    people: [Person(id: 'ME', name: 'Eu', createdAt: DateTime(2026, 1, 1)), ana],
    openingDate: DateTime(now.year, now.month - 2, 1),
  );

  FinancialTransaction tx(String id, String desc, int cents, DateTime date,
      {TransactionType type = TransactionType.expense,
      PaymentMethod method = PaymentMethod.pix,
      String? card,
      int installments = 1,
      String person = 'ME',
      String category = 'cat_other_expense'}) {
    return FinancialTransaction(
      id: id,
      description: desc,
      amountCents: cents,
      purchaseDate: date,
      categoryId: category,
      type: type,
      paymentMethod: method,
      cardId: card,
      totalInstallments: installments,
      personId: person,
    );
  }

  final transactions = [
    tx('salario', 'Salário', 240000, daysAgo(15), type: TransactionType.income, category: 'cat_salary'),
    tx('aluguel', 'Aluguel', 85000, daysAgo(14), category: 'cat_home'),
    tx('uber', 'Uber', 4590, daysAgo(18), method: PaymentMethod.creditCard, card: 'inter', category: 'cat_transport'),
    tx('tv', 'TV 50"', 120000, daysAgo(20),
        method: PaymentMethod.creditCard, card: 'nubank', installments: 3, category: 'cat_tech'),
    tx('netflix', 'Netflix', 5590, daysAgo(6),
            method: PaymentMethod.creditCard, card: 'nubank', category: 'cat_subscriptions')
        .copyWith(isRecurring: true, recurrence: RecurrenceFrequency.monthly),
    tx('cinema', 'Cinema', 6000, daysAgo(3),
        method: PaymentMethod.creditCard, card: 'nubank', person: 'p_ana', category: 'cat_leisure'),
    tx('mercado', 'Mercado Pão de Açúcar', 18450, daysAgo(2), category: 'cat_food'),
    tx('padaria', 'Padaria Real', 2390, daysAgo(1), method: PaymentMethod.cash, category: 'cat_food'),
    tx('tenis', 'Tênis Centauro', 30000, daysAgo(1), category: 'cat_clothing'),
    tx('presente', 'Presente da mãe', 15000, daysAgo(25),
        method: PaymentMethod.creditCard,
        card: 'nubank',
        installments: 3,
        person: 'p_ana',
        category: 'cat_other_expense'),
    tx('spotify', 'Spotify', 2190, inDays(3),
        method: PaymentMethod.creditCard, card: 'nubank', category: 'cat_subscriptions'),
    tx('aluguel_prox', 'Aluguel', 85000, inDays(12), category: 'cat_home'),
    tx('salario_prox', 'Salário', 240000, inDays(16), type: TransactionType.income, category: 'cat_salary'),
  ];
  for (final t in transactions) {
    state = FinancialMovementEngine.processNewTransaction(currentState: state, transaction: t);
  }

  state = FinancialMovementEngine.processTransactionRefund(
    currentState: state,
    transactionId: 'tenis',
    refundAmountCents: 15000,
    refundMethod: PaymentMethod.pix,
    refundDate: daysAgo(1),
  );

  final presente = state.reimbursements.firstWhere((r) => r.transactionId == 'presente');
  state = FinancialMovementEngine.processReimbursementPayment(
    currentState: state,
    reimbursementId: presente.id,
    amountReceivedCents: 5000,
    paymentDate: daysAgo(10),
  );

  final interInvoice = state.invoices.firstWhere((i) => i.cardId == 'inter');
  state = FinancialMovementEngine.processInvoicePayment(
    currentState: state,
    invoiceId: interInvoice.id,
    paymentDate: daysAgo(1),
  );
  return state;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    SharedPreferences.setMockInitialValues({});
    await _loadFont('ZenKakuGothicNew', [
      'assets/fonts/ZenKakuGothicNew-Regular.ttf',
      'assets/fonts/ZenKakuGothicNew-Medium.ttf',
      'assets/fonts/ZenKakuGothicNew-Bold.ttf',
    ]);
    await _loadFont('ShipporiMincho', [
      'assets/fonts/ShipporiMincho-Medium.ttf',
      'assets/fonts/ShipporiMincho-Bold.ttf',
    ]);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
    }
  });

  testWidgets('Tela Início (Sumi)', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 1720 * 2);
    addTearDown(tester.view.reset);

    final notifier = FinancialStateNotifier();
    notifier.debugSeed(
      _sampleState(),
      inbox: [
        InboxNotification(
          id: 'n1',
          rawId: 'n1',
          packageName: 'com.nu.production',
          appName: 'Nubank',
          rawTitle: 'Compra aprovada',
          rawText: 'Compra de R\$ 32,90 aprovada em IFOOD',
          parsedAmount: 32.90,
          eventTimestamp: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainShellScreen(notifier: notifier),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MainShellScreen), matchesGoldenFile('inicio.png'));
  }, skip: !autoUpdateGoldenFiles);

  FinancialStateNotifier seededNotifier() {
    return FinancialStateNotifier()..debugSeed(_sampleState(), categories: Category.defaultCategories());
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen, double height) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(390 * 2, height * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Tela Extrato (Sumi)', (tester) async {
    await pumpScreen(tester, TransactionHistoryScreen(notifier: seededNotifier()), 1300);
    await expectLater(find.byType(TransactionHistoryScreen), matchesGoldenFile('extrato.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Novo lançamento (Sumi)', (tester) async {
    await pumpScreen(tester, NewTransactionScreen(notifier: seededNotifier()), 1180);

    await tester.enterText(find.byType(TextField).at(0), '8490');
    await tester.enterText(find.byType(TextField).at(1), 'Mercado Pão de Açúcar');
    await tester.tap(find.byTooltip('Mais parcelas'));
    await tester.tap(find.byTooltip('Mais parcelas'));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await expectLater(find.byType(NewTransactionScreen), matchesGoldenFile('novo_lancamento.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Faturas (Sumi)', (tester) async {
    await pumpScreen(tester, InvoicesScreen(notifier: seededNotifier()), 1250);
    await expectLater(find.byType(InvoicesScreen), matchesGoldenFile('faturas.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Cobranças (Sumi)', (tester) async {
    await pumpScreen(tester, ReimbursementsScreen(notifier: seededNotifier()), 1100);
    await expectLater(find.byType(ReimbursementsScreen), matchesGoldenFile('cobrancas.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Caixa de entrada (Sumi)', (tester) async {
    final now = DateTime.now();
    InboxNotification item(String id, String app, String merchant, double amount, String text,
        {String method = 'creditCard', List<String> sources = const [], int minutesAgo = 0}) {
      return InboxNotification(
        id: id,
        rawId: id,
        packageName: 'pkg.$id',
        appName: app,
        rawTitle: merchant,
        rawText: text,
        parsedAmount: amount,
        parsedMerchant: merchant,
        suggestedPaymentMethod: method,
        eventTimestamp: now.subtract(Duration(minutes: minutesAgo)),
        detectedSources: sources.isEmpty ? [app] : sources,
      );
    }

    final notifier = FinancialStateNotifier()
      ..debugSeed(
        _sampleState(),
        categories: Category.defaultCategories(),
        inbox: [
          item('n1', 'Nubank', 'iFood', 32.90,
              'Compra de R\$ 32,90 APROVADA em IFOOD *RESTAURANTE para o cartão final 1234',
              sources: ['Nubank', 'Carteira do Google'], minutesAgo: 12),
          item('n2', 'Nubank', 'Pix para Maria Souza', 120.00,
              'Você enviou uma transferência de R\$ 120,00 para Maria Souza',
              method: 'pix', minutesAgo: 95),
          item('n3', 'Inter', 'Drogaria São Paulo', 47.35,
              'Compra aprovada no cartão Inter: R\$ 47,35 em DROGARIA SAO PAULO',
              minutesAgo: 60 * 26),
        ],
      );
    await pumpScreen(tester, InboxScreen(notifier: notifier), 1000);
    await expectLater(find.byType(InboxScreen), matchesGoldenFile('caixa_de_entrada.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Análise (Sumi)', (tester) async {
    await pumpScreen(tester, AnalyticsScreen(notifier: seededNotifier()), 900);
    await expectLater(find.byType(AnalyticsScreen), matchesGoldenFile('analise.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Ajustes (Sumi)', (tester) async {
    await pumpScreen(tester, SettingsScreen(notifier: seededNotifier()), 1400);
    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('ajustes.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Pessoas (Sumi)', (tester) async {
    await pumpScreen(tester, PeopleManagementScreen(notifier: seededNotifier()), 700);
    await expectLater(find.byType(PeopleManagementScreen), matchesGoldenFile('pessoas.png'));
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('Tela Categorias (Sumi)', (tester) async {
    await pumpScreen(tester, CategoriesManagementScreen(notifier: seededNotifier()), 900);
    await expectLater(find.byType(CategoriesManagementScreen), matchesGoldenFile('categorias.png'));
  }, skip: !autoUpdateGoldenFiles);
}
