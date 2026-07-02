import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Baris filter Genre dan Tahun dengan dropdown button.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.genres,
    required this.years,
    this.selectedGenre,
    this.selectedYear,
    this.onGenreChanged,
    this.onYearChanged,
  });

  final List<String> genres;
  final List<String> years;
  final String? selectedGenre;
  final String? selectedYear;
  final void Function(String?)? onGenreChanged;
  final void Function(String?)? onYearChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _FilterDropdown(
            hint: 'Genre',
            value: selectedGenre,
            items: genres,
            onChanged: onGenreChanged,
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterDropdown(
            hint: 'Tahun',
            value: selectedYear,
            items: years,
            onChanged: onYearChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
  });

  final String hint;
  final List<String> items;
  final String? value;
  final void Function(String?)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: value != null ? AppColors.activeBackground : AppColors.surface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(
          color: value != null ? AppColors.primary : AppColors.borderSubtle,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          dropdownColor: AppColors.surface,
          style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
          iconEnabledColor: AppColors.textMuted,
          iconSize: 18,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                'Semua $hint',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem(value: item, child: Text(item)),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
