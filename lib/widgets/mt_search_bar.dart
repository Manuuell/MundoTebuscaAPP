import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';
import 'mt_card.dart' show Press;

/// Fila de búsqueda compacta: buscador + botón de filtros + botón de paginado.
///
/// Reemplaza al `TextField` a toda altura que tenía cada pantalla (48-52 px de
/// alto, igual que el buscador de la web en `SearchBar.tsx`). Los filtros ya
/// no van sueltos a la vista: cuelgan del botón de embudo, como en la web
/// (`FilterSheet`), y el paginado es un botón más al lado, mismo tamaño que
/// el resto de controles de la fila.
class MTSearchBar extends StatelessWidget {
  const MTSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Buscar…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.filtrosActivos = 0,
    this.alTocarFiltros,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  /// Número de filtros aplicados; si es > 0 se pinta una insignia en el botón.
  final int filtrosActivos;

  /// Recibe el `BuildContext` del propio botón (no el de la pantalla): hace
  /// falta para anclar el panel flotante justo debajo de donde se tocó.
  final ValueChanged<BuildContext>? alTocarFiltros;

  /// Control extra al final de la fila — normalmente [MTPaginationButton].
  final Widget? trailing;

  static const alto = 40.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: alto,
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.muted, size: 19),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 38, minHeight: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17),
                        padding: EdgeInsets.zero,
                        onPressed: onClear,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.brand500),
                ),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
        ),
        if (alTocarFiltros != null) ...[
          const SizedBox(width: 8),
          _BotonCircular(
            icono: Icons.tune_rounded,
            insignia: filtrosActivos > 0 ? filtrosActivos : null,
            onTap: alTocarFiltros,
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _BotonCircular extends StatelessWidget {
  const _BotonCircular({required this.icono, this.insignia, this.onTap});

  final IconData icono;
  final int? insignia;
  final ValueChanged<BuildContext>? onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap == null ? null : () => onTap!(context),
      child: SizedBox(
        width: MTSearchBar.alto,
        height: MTSearchBar.alto,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                boxShadow: MTElevation.card,
              ),
              child: Icon(icono, size: 19, color: AppColors.navy700),
            ),
            if (insignia != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: AppColors.brand500,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$insignia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón de paginado: mismo alto y ancho fijo que [MTSearchBar]. Despliega un
/// panel flotante — no una hoja — con el mismo ancho que él mismo. `0` es el
/// valor centinela "infinito" (el scroll sigue trayendo tandas solo; es el
/// comportamiento por defecto), el resto son tamaños fijos de tanda.
class MTPaginationButton extends StatelessWidget {
  const MTPaginationButton({
    super.key,
    required this.porPagina,
    required this.onChanged,
    this.opciones = const [0, 10, 20, 50],
  });

  final int porPagina;
  final ValueChanged<int> onChanged;
  final List<int> opciones;

  static const _ancho = 52.0;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: () => _abrir(context),
      child: Container(
        width: _ancho,
        height: MTSearchBar.alto,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: MTElevation.card,
        ),
        child: _Etiqueta(valor: porPagina, color: AppColors.navy700),
      ),
    );
  }

  Future<void> _abrir(BuildContext anchorContext) {
    return mostrarFlotante(
      anchorContext,
      ancho: _ancho,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in opciones) ...[
            _FilaOpcion(
              activo: n == porPagina,
              child: _Etiqueta(
                valor: n,
                color: n == porPagina ? AppColors.brand700 : AppColors.navy700,
              ),
              onTap: () {
                onChanged(n);
                Navigator.of(ctx, rootNavigator: true).pop();
              },
            ),
            if (n != opciones.last)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.valor, required this.color});

  final int valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (valor == 0) {
      return Icon(Icons.all_inclusive_rounded, size: 18, color: color);
    }
    return Text('$valor',
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: color));
  }
}

class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion(
      {required this.child, required this.activo, required this.onTap});

  final Widget child;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        color: activo ? AppColors.brand500.withValues(alpha: 0.08) : null,
        child: child,
      ),
    );
  }
}

/// Panel flotante genérico: aparece anclado bajo el widget que lo abrió (no
/// desde abajo de la pantalla), con sombra y esquinas redondeadas, y se
/// cierra tocando fuera. Sustituye a la hoja modal para paneles cortos como
/// filtros, capas del mapa o el selector de paginado — "que se sienta como un
/// desplegable nativo, no como una hoja que sube".
Future<T?> mostrarFlotante<T>(
  BuildContext anchorContext, {
  required WidgetBuilder builder,
  double? ancho,
  double maxAlto = 420,
}) {
  final box = anchorContext.findRenderObject() as RenderBox;
  final overlayBox =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()
          as RenderBox;
  final abajoIzq =
      box.localToGlobal(Offset(0, box.size.height + 8), ancestor: overlayBox);
  final abajoDer = box.localToGlobal(
      Offset(box.size.width, box.size.height + 8),
      ancestor: overlayBox);

  final w = ancho ?? 300.0;
  var left = abajoDer.dx - w;
  if (left < 12) left = 12;
  if (left + w > overlayBox.size.width - 12) {
    left = overlayBox.size.width - 12 - w;
  }
  var top = abajoIzq.dy;
  final alturaDisponible = overlayBox.size.height - top - 24;
  final alturaMax =
      alturaDisponible < maxAlto ? alturaDisponible : maxAlto;

  return showGeneralDialog<T>(
    context: anchorContext,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) {
      final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: w,
            child: FadeTransition(
              opacity: curva,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curva),
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                        maxHeight: alturaMax > 120 ? alturaMax : 120),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: MTElevation.cardHover,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: builder(ctx),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Contenido de un panel de filtros: título + contenido + acciones "Limpiar"
/// / "Aplicar". Pensado para pasarse como `builder` de [mostrarFlotante].
Widget panelFiltros(
  BuildContext context, {
  required String titulo,
  required Widget contenido,
  VoidCallback? alLimpiar,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (alLimpiar != null)
              TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () {
                  alLimpiar();
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: const Text('Limpiar'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Flexible(child: SingleChildScrollView(child: contenido)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Aplicar'),
          ),
        ),
      ],
    ),
  );
}
