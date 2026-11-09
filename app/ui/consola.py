"""Punto de entrada de la interfaz: inicio de sesión y menú según el rol."""
from __future__ import annotations

from app.db.conexion import ErrorBaseDatos, ErrorNegocio, bd
from app.servicios.soporte import Seguridad, Sesion, Tickets
from app.ui import menu_admin
from app.ui import menu_tickets as mt
from app.ui import utilidades as ui


def _cambiar_contrasena(sesion: Sesion) -> None:
    actual = ui.pedir_contrasena("Contraseña actual")
    nueva = ui.pedir_contrasena("Nueva contraseña")
    if nueva != ui.pedir_contrasena("Repita la nueva contraseña"):
        ui.aviso("Las contraseñas no coinciden.")
        return
    Seguridad.cambiar_contrasena(sesion.id_empleado, actual, nueva)
    ui.exito("Contraseña actualizada.")


def _menu_tecnico(sesion: Sesion) -> None:
    ui.ejecutar_menu(f"Técnico - {sesion.nombre}", [
        ("Mis tickets pendientes", lambda: ui.mostrar_tabla(
            Tickets.filtrar(estado="EN_PROCESO", id_tecnico=sesion.id_tecnico), mt.COLUMNAS_LISTA,
            vacio="No tiene tickets en proceso.")),
        ("Consultar mis tickets con filtros", lambda: mt.filtrar_tickets(id_tecnico_fijo=sesion.id_tecnico)),
        ("Tickets sin asignar", mt.tickets_sin_asignar),
        ("Tomar un ticket", lambda: mt.tomar_ticket(sesion)),
        ("Cambiar estado de un ticket", lambda: mt.cambiar_estado(sesion)),
        ("Ver detalle de un ticket", mt.ver_detalle),
        ("Crear un ticket propio", lambda: mt.crear_ticket(sesion)),
        ("Cambiar mi contraseña", lambda: _cambiar_contrasena(sesion)),
    ])


def _menu_empleado(sesion: Sesion) -> None:
    ui.ejecutar_menu(f"Empleado - {sesion.nombre}", [
        ("Crear ticket de soporte", lambda: mt.crear_ticket(sesion)),
        ("Mis tickets", lambda: ui.mostrar_tabla(
            Tickets.filtrar(id_empleado=sesion.id_empleado), mt.COLUMNAS_LISTA,
            vacio="Todavía no ha creado tickets.")),
        ("Ver detalle de un ticket", mt.ver_detalle),
        ("Modificar un ticket mío", lambda: mt.modificar_ticket(sesion)),
        ("Cambiar mi contraseña", lambda: _cambiar_contrasena(sesion)),
    ])


def _iniciar_sesion() -> Sesion | None:
    ui.titulo("Nexora Technologies - Soporte TI y Activos")
    for intento in range(3):
        usuario = input("  Usuario (ENTER para salir): ").strip()
        if not usuario:
            return None
        contrasena = ui.pedir_contrasena()
        try:
            return Seguridad.iniciar_sesion(usuario, contrasena)
        except ErrorNegocio as exc:
            ui.aviso(f"{exc} Intentos restantes: {2 - intento}")
    return None


def ejecutar() -> None:
    try:
        bd.conectar()
    except (ErrorBaseDatos, ErrorNegocio) as exc:
        ui.aviso(f"No se pudo conectar a Oracle: {exc}")
        ui.aviso("Revise el archivo .env (usuario, contraseña y DSN).")
        return

    try:
        while True:
            sesion = _iniciar_sesion()
            if sesion is None:
                break
            ui.exito(f"Bienvenido(a), {sesion.nombre} ({sesion.rol}) - {sesion.departamento}")
            if sesion.es_admin:
                menu_admin.menu_principal(sesion, lambda: _cambiar_contrasena(sesion))
            elif sesion.es_tecnico:
                _menu_tecnico(sesion)
            else:
                _menu_empleado(sesion)
            print("\n  Sesión cerrada.")
    except KeyboardInterrupt:
        print()
    finally:
        bd.cerrar()
        print("  Hasta luego.")
