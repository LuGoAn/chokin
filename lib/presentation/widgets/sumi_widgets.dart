import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/sumi.dart';
import '../../core/utils/date_time_utils.dart';

class HankoStamp extends StatelessWidget {
  final double size;
  final String label;

  const HankoStamp({super.key, this.size = 54, this.label = 'PAGA'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fatura paga',
      child: Transform.rotate(
        angle: -0.17,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: size * 0.04),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('済', style: Sumi.figures(size * 0.37, weight: FontWeight.w700, color: AppColors.primary)),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Sumi.uiFont,
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthStrip extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;

  const MonthStrip({super.key, required this.month, required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final months = [
      for (var offset = -2; offset <= 2; offset++) DateTime(year, month + offset),
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in months) _MonthTab(date: d, selected: d.month == month && d.year == year, onTap: onChanged),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateTimeUtils.formatMonthYear(DateTime(year, month)),
          style: Sumi.caption,
        ),
      ],
    );
  }
}

class _MonthTab extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final void Function(int month, int year) onTap;

  const _MonthTab({required this.date, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: DateTimeUtils.formatMonthYear(date),
      child: InkWell(
        onTap: () => onTap(date.month, date.year),
        borderRadius: BorderRadius.circular(Sumi.radius),
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2),
            ),
          ),
          child: ExcludeSemantics(
            child: Text(
              Sumi.shortMonth(date.month),
              style: Sumi.figures(
                17,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LedgerLine extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;
  final bool showBottomBorder;

  const LedgerLine({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.onTap,
    this.showBottomBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: AppColors.border),
          bottom: showBottomBorder ? const BorderSide(color: AppColors.border) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Sumi.label),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: Sumi.caption),
                ],
              ],
            ),
          ),
          Text(value, style: Sumi.figures(18)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ],
      ),
    );

    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: Sumi.sectionTitle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SegmentedChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool underline;

  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      final (option, label) = options[i];
      final selected = option == value;
      final textStyle = TextStyle(
        fontFamily: Sumi.uiFont,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: underline
            ? (selected ? AppColors.textPrimary : AppColors.textSecondary)
            : (selected ? AppColors.background : AppColors.textSecondary),
      );
      items.add(Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: () => onChanged(option),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !underline && selected ? AppColors.textPrimary : Colors.transparent,
                border: underline
                    ? Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))
                    : (i < options.length - 1 ? const Border(right: BorderSide(color: AppColors.borderStrong)) : null),
              ),
              child: Text(label, style: textStyle, textAlign: TextAlign.center),
            ),
          ),
        ),
      ));
    }

    if (underline) {
      return Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: items),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Sumi.radius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(Sumi.radius),
        ),
        child: Row(children: items),
      ),
    );
  }
}

class ChoiceChipSumi extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  const ChoiceChipSumi(
      {super.key, required this.label, required this.selected, required this.onTap, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.textPrimary : AppColors.borderStrong),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Sumi.uiFont,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.background : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration underlineDecoration(String label, {String? hint, Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderStrong)),
    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderStrong)),
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5)),
    floatingLabelBehavior: FloatingLabelBehavior.always,
  );
}

String invoiceStatusLabel({
  required bool isPaid,
  required int amountCents,
  required DateTime closingDate,
  required DateTime dueDate,
  required int month,
  required int year,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final today = DateUtils.dateOnly(ref);
  if (isPaid) return 'PAGA';
  if (amountCents > 0 && dueDate.isBefore(today)) return 'VENCIDA';
  if (!closingDate.isAfter(ref)) return 'FECHADA';
  if (year > ref.year || (year == ref.year && month > ref.month)) return 'FUTURA';
  return 'ABERTA';
}
