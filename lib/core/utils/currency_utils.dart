import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'money.dart';

class CurrencyUtils {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String format(double value) {
    return _formatter.format(value);
  }

  static String formatCents(int cents) {
    return _formatter.format(Money.toReais(cents));
  }

  static int? parseCents(String value) {
    final reais = parse(value);
    return reais == null ? null : Money.fromReais(reais);
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

    if (clean.contains('.') && clean.contains(',')) {
      final lastDot = clean.lastIndexOf('.');
      final lastComma = clean.lastIndexOf(',');
      if (lastComma > lastDot) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
      return double.tryParse(clean);
    }

    if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
      return double.tryParse(clean);
    }

    if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        return double.tryParse(clean);
      } else if (parts.length > 2) {
        clean = clean.replaceAll('.', '');
        return double.tryParse(clean);
      }
    }

    return double.tryParse(clean);
  }
}

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
