import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
    return AlertDialog(
      title: const Text('Selecciona una ubicación'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Busca una ciudad o región',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('Buscar localidades'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              )
            else if (_options.isNotEmpty)
              SizedBox(
                height: 220,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return ListTile(
                      dense: true,
                      title: Text(option.displayName),
                      subtitle: Text(option.query),
                      onTap: () => Navigator.of(context).pop(option.query),
                    );
                  },
                ),
              )
            else if (widget.controller.text.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'No se encontraron resultados. Prueba con otra búsqueda.'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
