import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/zone_status.dart';
import '../utils/colors.dart';

/// Chips para cambiar de zona sin volver al Dashboard (HU-M06, Task 6.1).
/// Con una sola zona no se muestra.
class ZoneSelector extends StatelessWidget {
  const ZoneSelector({
    super.key,
    required this.zones,
    required this.selectedId,
    required this.onSelected,
  });

  final Map<String, ZoneStatus> zones;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ids = zones.keys.toList()..sort();
    if (ids.length < 2) return const SizedBox.shrink();

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ids.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final id = ids[i];
            final selected = id == selectedId;
            return ChoiceChip(
              label: Text(
                id,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : textColor,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: selected ? AppColors.primary : borderColor,
                width: 1.5,
              ),
              shape: const StadiumBorder(),
              onSelected: (_) => onSelected(id),
            );
          },
        ),
      ),
    );
  }
}