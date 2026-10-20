import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/transaction.dart';

enum CsvExportScope {
  specificMonth,
  entireYear,
  allHistory,
  customRange,
}

class CsvExportOptions {
  final CsvExportScope scope;
  final int? month;
  final int? year;
  final DateTime? startDate;
  final DateTime? endDate;

  const CsvExportOptions({
    required this.scope,
    this.month,
    this.year,
    this.startDate,
    this.endDate,
  });
}

class CsvExportService {
  static String generateCsv({
    required FinancialState state,
    List<Category> categories = const [],
    required CsvExportOptions options,
  }) {
    final transactions = _filterTransactions(state.transactions, options);
    
    transactions.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    final sb = StringBuffer();

    sb.writeln('Data;Mês/Ano;Descrição;Categoria;Tipo;Forma de Pagamento;Parcela;Pessoa;Valor (R\$)');

    int? currentMonth;
    int? currentYear;

    for (final t in transactions) {
      if (options.scope != CsvExportScope.specificMonth) {
        if (currentMonth != t.purchaseDate.month || currentYear != t.purchaseDate.year) {
          currentMonth = t.purchaseDate.month;
          currentYear = t.purchaseDate.year;
          final monthHeader = DateTimeUtils.formatMonthYear(DateTime(currentYear, currentMonth));
          sb.writeln(';--- $monthHeader ---;;;;;;;');
        }
      }

      final dateStr = DateTimeUtils.formatDate(t.purchaseDate);
      final monthStr = DateTimeUtils.formatMonthYear(DateTime(t.purchaseDate.year, t.purchaseDate.month));
      final descStr = _escapeCsv(t.description);

      final cat = categories.where((c) => c.id == t.categoryId).firstOrNull;
      final catStr = _escapeCsv(cat?.name ?? 'Outros');

      final tipoStr = t.isRefunded
          ? 'Estorno'
          : (t.type == TransactionType.income ? 'Receita' : 'Despesa');

      String paymentStr;
      if (t.paymentMethod == PaymentMethod.creditCard) {
        final card = state.cards.where((c) => c.id == t.cardId).firstOrNull;
        paymentStr = card != null ? 'Cartão (${card.name})' : 'Cartão de Crédito';
      } else if (t.isPix) {
        paymentStr = 'Pix';
      } else {
        paymentStr = 'Dinheiro / Débito';
      }

      final parcelaStr = t.isInstallment ? '${t.totalInstallments}x' : 'À vista';

      final person = t.personId != null
          ? state.people.where((p) => p.id == t.personId).firstOrNull
          : null;
      final personStr = _escapeCsv(person?.name ?? 'Eu');

      final amountVal = t.amount.toStringAsFixed(2).replaceAll('.', ',');
      final valorStr = t.type == TransactionType.expense ? '-$amountVal' : amountVal;

      sb.writeln('$dateStr;$monthStr;$descStr;$catStr;$tipoStr;$paymentStr;$parcelaStr;$personStr;$valorStr');
    }

    return sb.toString();
  }

  static List<FinancialTransaction> _filterTransactions(
    List<FinancialTransaction> allTransactions,
    CsvExportOptions options,
  ) {
    switch (options.scope) {
      case CsvExportScope.specificMonth:
        final m = options.month ?? DateTime.now().month;
        final y = options.year ?? DateTime.now().year;
        return allTransactions.where((t) => t.purchaseDate.month == m && t.purchaseDate.year == y).toList();

      case CsvExportScope.entireYear:
        final y = options.year ?? DateTime.now().year;
        return allTransactions.where((t) => t.purchaseDate.year == y).toList();

      case CsvExportScope.allHistory:
        return List<FinancialTransaction>.from(allTransactions);

      case CsvExportScope.customRange:
        final start = options.startDate ?? DateTime(2000);
        final end = options.endDate != null
            ? DateTime(options.endDate!.year, options.endDate!.month, options.endDate!.day, 23, 59, 59)
            : DateTime(2100);
        return allTransactions
            .where((t) => !t.purchaseDate.isBefore(start) && !t.purchaseDate.isAfter(end))
            .toList();
    }
  }

  static String _escapeCsv(String text) {
    if (text.contains(';') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
