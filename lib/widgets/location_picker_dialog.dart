import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

Future<String?> showLocationPicker({
  required BuildContext context,
  required ApiService api,
  String? initialLocation,
}) {
  final controller =
      TextEditingController(text: initialLocation ?? api.currentLocation);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return _LocationPickerDialog(
        api: api,
        controller: controller,
      );
    },
  );
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({
    required this.api,
    required this.controller,
  });

  final ApiService api;
  final TextEditingController controller;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  bool _loading = false;
  List<LocationOption> _options = [];

  Future<void> _search() async {
    final query = widget.controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _options = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await widget.api.searchLocations(query);
      if (!mounted) return;
      setState(() {
        _options = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Selecciona una ubicación',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widget.controller,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Busca una ciudad o región',
                  hintStyle: GoogleFonts.inter(color: subtextColor),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.secondary),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkBackground
                      : const Color(0xFFE2E8F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(
                    'Buscar localidades',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (_options.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _options.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final option = _options[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            option.displayName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            option.query,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subtextColor,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(option.query),
                        ),
                      );
                    },
                  ),
                )
              else if (widget.controller.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'No se encontraron resultados. Prueba con otra búsqueda.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: subtextColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.inter(
              color: subtextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
