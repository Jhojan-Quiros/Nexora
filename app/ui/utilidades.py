"""Funciones de entrada/salida para la interfaz de consola."""
from __future__ import annotations

import getpass
from datetime import date, datetime
from typing import Callable, Iterable, Sequence

from app.db.conexion import ErrorBaseDatos, ErrorNegocio, Resultado

ANCHO_MAX = 28


class Cancelado(Exception):
    """El usuario escribió 0 / vacío para cancelar."""


# ------------------------------------------------------------------ salida
def titulo(texto: str) -> None:
    print("\n" + "=" * 70)
    print(f"  {texto}")
    print("=" * 70)


def exito(texto: str) -> None:
    print(f"\n  ✔ {texto}")


def aviso(texto: str) -> None:
    print(f"\n  ✖ {texto}")


def pausa() -> None:
    input("\n  Presione ENTER para continuar...")


def _formatear(valor: object) -> str:
    if valor is None:
        return "-"
    if isinstance(valor, datetime):
        return valor.strftime("%d/%m/%Y %H:%M") if (valor.hour or valor.minute) else valor.strftime("%d/%m/%Y")
    if isinstance(valor, date):
        return valor.strftime("%d/%m/%Y")
    if isinstance(valor, float):
        return f"{valor:.2f}"
    texto = str(valor)
    return texto if len(texto) <= ANCHO_MAX else texto[: ANCHO_MAX - 1] + "…"


def mostrar_tabla(resultado: Resultado, columnas: Sequence[str] | None = None,
                  vacio: str = "No hay registros.") -> None:
    if not resultado.filas:
        print(f"\n  {vacio}")
        return
    columnas = [c.upper() for c in (columnas or resultado.columnas)]
    indices = [resultado.columnas.index(c) for c in columnas]
    filas = [[_formatear(f[i]) for i in indices] for f in resultado.filas]
    encabezados = [c.replace("_", " ") for c in columnas]
    anchos = [max(len(encabezados[i]), *(len(f[i]) for f in filas)) for i in range(len(columnas))]
    linea = "  " + "-+-".join("-" * a for a in anchos)
    print()
    print("  " + " | ".join(e.ljust(a) for e, a in zip(encabezados, anchos)))
    print(linea)
    for fila in filas:
        print("  " + " | ".join(v.ljust(a) for v, a in zip(fila, anchos)))
    print(f"\n  {len(filas)} registro(s).")


def mostrar_ficha(datos: dict | None, campos: Iterable[str] | None = None) -> None:
    if not datos:
        aviso("Registro no encontrado.")
        return
    campos = [c.upper() for c in (campos or datos.keys())]
    ancho = max(len(c) for c in campos)
    print()
    for c in campos:
        valor = datos.get(c)
        texto = _formatear(valor) if not isinstance(valor, str) else valor
        print(f"  {c.replace('_', ' ').ljust(ancho)} : {texto if texto else '-'}")


# ------------------------------------------------------------------ entrada
def pedir_texto(etiqueta: str, obligatorio: bool = True, actual: str | None = None) -> str | None:
    sufijo = f" [{actual}]" if actual else ""
    while True:
        valor = input(f"  {etiqueta}{sufijo}: ").strip()
        if valor == "0":
            raise Cancelado
        if not valor and actual is not None:
            return actual
        if valor or not obligatorio:
            return valor or None
        print("    Este dato es obligatorio (escriba 0 para cancelar).")


def pedir_contrasena(etiqueta: str = "Contraseña") -> str:
    return getpass.getpass(f"  {etiqueta}: ")


def pedir_entero(etiqueta: str, obligatorio: bool = True, actual: int | None = None) -> int | None:
    sufijo = f" [{actual}]" if actual is not None else ""
    while True:
        valor = input(f"  {etiqueta}{sufijo}: ").strip()
        if not valor:
            if actual is not None:
                return actual
            if not obligatorio:
                return None
            print("    Ingrese un número.")
            continue
        if valor == "0" and obligatorio:
            raise Cancelado
        if valor.isdigit():
            return int(valor)
        print("    Debe ser un número entero positivo.")


def pedir_fecha(etiqueta: str, actual: date | None = None) -> date:
    sufijo = f" [{actual:%d/%m/%Y}]" if actual else ""
    while True:
        valor = input(f"  {etiqueta} (dd/mm/aaaa){sufijo}: ").strip()
        if not valor and actual:
            return actual
        try:
            return datetime.strptime(valor, "%d/%m/%Y").date()
        except ValueError:
            print("    Fecha inválida. Ejemplo: 15/03/2025")


def pedir_opcion(etiqueta: str, opciones: Sequence[str], obligatorio: bool = True,
                 actual: str | None = None) -> str | None:
    print(f"  {etiqueta}:")
    for i, op in enumerate(opciones, 1):
        print(f"    {i}. {op}")
    if not obligatorio:
        print("    (ENTER = todos)")
    while True:
        sufijo = f" [{actual}]" if actual else ""
        valor = input(f"  Opción{sufijo}: ").strip()
        if not valor:
            if actual:
                return actual
            if not obligatorio:
                return None
        if valor == "0":
            raise Cancelado
        if valor.isdigit() and 1 <= int(valor) <= len(opciones):
            return opciones[int(valor) - 1]
        print("    Opción inválida.")


def confirmar(pregunta: str) -> bool:
    return input(f"  {pregunta} (s/n): ").strip().lower() in ("s", "si", "sí")


# ------------------------------------------------------------------ menús
Accion = Callable[[], None]


def submenu(accion: Accion) -> Accion:
    """Marca una acción como submenú para no pedir ENTER al volver de ella."""
    accion.es_submenu = True  # type: ignore[attr-defined]
    return accion


def ejecutar_menu(nombre: str, opciones: Sequence[tuple[str, Accion]]) -> None:
    """Muestra un menú hasta que el usuario elija 0 (volver/salir)."""
    while True:
        titulo(nombre)
        for i, (texto, _) in enumerate(opciones, 1):
            print(f"   {i}. {texto}")
        print("   0. Volver")
        eleccion = input("\n  Seleccione: ").strip()
        if eleccion == "0":
            return
        if not eleccion.isdigit() or not 1 <= int(eleccion) <= len(opciones):
            aviso("Opción inválida.")
            continue
        _, accion = opciones[int(eleccion) - 1]
        ejecutar_accion(accion, pausar=not getattr(accion, "es_submenu", False))


def ejecutar_accion(accion: Accion, pausar: bool = True) -> None:
    """Ejecuta una acción mostrando los errores de negocio sin cerrar el programa."""
    try:
        accion()
    except Cancelado:
        aviso("Operación cancelada.")
    except ErrorNegocio as exc:
        aviso(str(exc))
    except ErrorBaseDatos as exc:
        aviso(str(exc))
    if pausar:
        pausa()
