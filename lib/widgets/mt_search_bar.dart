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
  final VoidCallback? alTocarFiltros;

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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      child: SizedBox(
        width: MTSearchBar.alto,
        height: MTSearchBar.alto,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
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

/// Botón de paginado: mismo alto que [MTSearchBar], despliega un menú del
/// mismo ancho que él mismo con las opciones de tamaño de página. Por defecto
/// 10, igual que la web (`PAGE_SIZE = 10` en cada listado).
class MTPaginationButton extends StatelessWidget {
  const MTPaginationButton({
    super.key,
    required this.porPagina,
    required this.onChanged,
    this.opciones = const [10, 20, 50],
  });

  final int porPagina;
  final ValueChanged<int> onChanged;
  final List<int> opciones;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MTSearchBar.alto,
      child: PopupMenuButton<int>(
        initialValue: porPagina,
        onSelected: onChanged,
        offset: const Offset(0, MTSearchBar.alto + 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => [
          for (final n in opciones)
            PopupMenuItem(
              value: n,
              child: Text('$n por página',
                  style: TextStyle(
                      fontWeight:
                          n == porPagina ? FontWeight.w800 : FontWeight.w500)),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
            boxShadow: MTElevation.card,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$porPagina',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy700)),
              const Icon(Icons.expand_more_rounded,
                  size: 16, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja de filtros compartida: título + contenido + acciones "Limpiar" /
/// "Aplicar". Cada pantalla arma su propio contenido (chips, switches…) y
/// pasa cuántos filtros quedan activos, para que el llamador pinte la
/// insignia del botón de embudo sin duplicar esa cuenta.
Future<void> mostrarHojaFiltros(
  BuildContext context, {
  required String titulo,
  required Widget contenido,
  VoidCallback? alLimpiar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(titulo,
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                ),
                if (alLimpiar != null)
                  TextButton(
                    onPressed: () {
                      alLimpiar();
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            contenido,
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
