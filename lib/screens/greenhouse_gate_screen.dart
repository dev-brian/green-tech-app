import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../repositories/greenhouse_repository.dart';
import '../services/firebase_service.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

enum _Fase { cargando, elegir, unirse, error }

/// Paso entre el login y el Dashboard: decide qué invernadero ver.
///
/// - Un invernadero (o el último usado en este celular): entra directo.
/// - Varios: muestra la lista para elegir.
/// - Ninguno: pide el código de invitación que da el admin en la PWA.
///
/// Con [cambiar] en true se abre desde el Dashboard solo para cambiar de
/// invernadero y, al elegir, regresa.
class GreenhouseGateScreen extends StatefulWidget {
  const GreenhouseGateScreen({super.key, this.cambiar = false, this.session});

  final bool cambiar;

  /// Para pruebas; por defecto [GreenhouseSession.instance].
  final GreenhouseSession? session;

  @override
  State<GreenhouseGateScreen> createState() => _GreenhouseGateScreenState();
}

class _GreenhouseGateScreenState extends State<GreenhouseGateScreen> {
  late final GreenhouseSession _session =
      widget.session ?? GreenhouseSession.instance;
  final _codeCtrl = TextEditingController();

  _Fase _fase = _Fase.cargando;
  String? _error;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    if (widget.cambiar && _session.greenhouses.value.isNotEmpty) {
      _fase = _Fase.elegir;
    } else {
      _cargar();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _fase = _Fase.cargando;
      _error = null;
    });
    try {
      final r = await _session.load();
      if (!mounted) return;
      switch (r) {
        case GreenhouseLoadResult.ready when !widget.cambiar:
          _irAlDashboard();
        case GreenhouseLoadResult.ready || GreenhouseLoadResult.pick:
          setState(() => _fase = _Fase.elegir);
        case GreenhouseLoadResult.join:
          setState(() => _fase = _Fase.unirse);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.error;
        _error = e is GreenhouseException
            ? e.message
            : 'No se pudieron cargar tus invernaderos. Revisa tu conexión';
      });
    }
  }

  void _irAlDashboard() {
    if (widget.cambiar) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _elegir(Greenhouse g) async {
    setState(() => _ocupado = true);
    await _session.select(g);
    if (!mounted) return;
    setState(() => _ocupado = false);
    _irAlDashboard();
  }

  Future<void> _unirse() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _session.joinWithCode(_codeCtrl.text);
      if (!mounted) return;
      if (_session.current.value != null) {
        _irAlDashboard();
      } else {
        setState(() => _fase = _Fase.elegir);
      }
    } on GreenhouseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo unir al invernadero. Inténtalo de nuevo');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await _session.clear();
    await FirebaseService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.cambiar ? 'Cambiar invernadero' : 'Tus invernaderos',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: widget.cambiar,
        actions: [
          if (!widget.cambiar)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _ocupado ? null : _cerrarSesion,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: switch (_fase) {
              _Fase.cargando => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              _Fase.error => _buildError(isDark),
              _Fase.elegir => _buildLista(isDark),
              _Fase.unirse => _buildUnirse(isDark),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: AppColors.critico, size: 42),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Ocurrió un error',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: textColor),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return ValueListenableBuilder<List<Greenhouse>>(
      valueListenable: _session.greenhouses,
      builder: (context, lista, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: AppColors.primary),
            ),
          Text(
            '¿Qué invernadero quieres ver?',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Puedes cambiarlo después desde el Dashboard.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtextColor),
          ),
          const SizedBox(height: 16),
          for (final g in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: NeumorphismDecoration.extruded(
                    context: context, isDark: isDark, borderRadius: 16),
                // Material propio: así el fondo de la tarjeta no
                // tapa el efecto de toque del ListTile.
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    key: Key('invernadero_${g.id}'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: const Icon(Icons.eco, color: AppColors.primary),
                    title: Text(g.name,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, color: textColor)),
                    subtitle: Text(g.role.label,
                        style: GoogleFonts.plusJakartaSans(color: subtextColor)),
                    trailing: _session.current.value?.id == g.id
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : const Icon(Icons.chevron_right),
                    onTap: _ocupado ? null : () => _elegir(g),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _ocupado ? null : () => setState(() => _fase = _Fase.unirse),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Unirme a otro con un código'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnirse(bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: NeumorphismDecoration.extruded(
              context: context, isDark: isDark, borderRadius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.group_add_outlined,
                  color: AppColors.secondary, size: 40),
              const SizedBox(height: 12),
              Text(
                _session.greenhouses.value.isEmpty
                    ? 'Aún no perteneces a ningún invernadero'
                    : 'Unirme a otro invernadero',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Pídele al administrador el código de invitación. '
                'Lo encuentra en la PWA, en la configuración del invernadero.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtextColor),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('codigo_invitacion'),
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _ocupado ? null : _unirse(),
                decoration: const InputDecoration(
                  labelText: 'Código de invitación',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.estadoTexto(EstadoNivel.critico,
                        isDark: isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _ocupado ? null : _unirse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _ocupado
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Unirme'),
              ),
              if (_session.greenhouses.value.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _error = null;
                    _fase = _Fase.elegir;
                  }),
                  child: const Text('Volver a mis invernaderos'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
