import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String format(double value) {
    return _formatter.format(value);
  }

  static String formatNoSymbol(double value) {
    return _formatter.format(value).replaceAll('R\$', '').trim();
  }

  static String formatNumber(double value) {
    return NumberFormat.decimalPattern('pt_BR').format(value);
  }

  static double? parse(String value) {
    if (value.trim().isEmpty) return null;

    String clean = value
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();

    if (clean.isEmpty) return null;

    // Se tem tanto ponto quanto vírgula
    if (clean.contains('.') && clean.contains(',')) {
      final lastDot = clean.lastIndexOf('.');
      final lastComma = clean.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Formato BR: 1.250,36
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Formato US: 1,250.36
        clean = clean.replaceAll(',', '');
      }
      return double.tryParse(clean);
    }

    // Se tem apenas vírgula: 25,36 -> 25.36
    if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
      return double.tryParse(clean);
    }

    // Se tem apenas ponto: pode ser 25.36 (decimal) ou 1.000 (milhar)
    if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Ex: 25.3 ou 25.36 -> decimal
        return double.tryParse(clean);
      } else if (parts.length > 2) {
        // Ex: 1.000.000
        clean = clean.replaceAll('.', '');
        return double.tryParse(clean);
      }
    }

    return double.tryParse(clean);
  }
}

/// Formatador dinâmico de digitação para valores em Reais (R$)
/// Conforme o usuário digita os números, formata da direita para a esquerda:
/// "2" -> "0,02", "25" -> "0,25", "253" -> "2,53", "2536" -> "25,36"
class CurrencyTextInputFormatter extends TextInputFormatter {
  final int maxDigits;

  CurrencyTextInputFormatter({this.maxDigits = 11});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove tudo que não for dígito
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (digitsOnly.length > maxDigits) {
      digitsOnly = digitsOnly.substring(0, maxDigits);
    }

    final double value = (double.tryParse(digitsOnly) ?? 0.0) / 100.0;
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );

    final String formattedText = formatter.format(value).trim();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
