"""Menú del administrador de TI (RF-01, RF-02, RF-03, RF-05, RF-06)."""
from __future__ import annotations

from app.servicios.catalogos import AsignacionEquipos, Departamentos, Empleados, Equipos, Tecnicos
from app.servicios.soporte import Panel, Sesion
from app.ui import menu_tickets as mt
from app.ui import utilidades as ui


# ================================================================ DEPARTAMENTOS
def _listar_departamentos() -> None:
    ui.mostrar_tabla(Departamentos.listar(),
                     ["ID_DEPARTAMENTO", "NOMBRE", "UBICACION", "ACTIVO", "EMPLEADOS_ACTIVOS"])


def _registrar_departamento() -> None:
    nombre = ui.pedir_texto("Nombre")
    ubicacion = ui.pedir_texto("Ubicación")
    nuevo = Departamentos.registrar(nombre, ubicacion)
    ui.exito(f"Departamento registrado con id {nuevo}.")


def _modificar_departamento() -> None:
    id_depto = ui.pedir_entero("ID del departamento")
    actual = Departamentos.obtener(id_depto)
    if not actual:
        ui.aviso("El departamento no existe.")
        return
    nombre = ui.pedir_texto("Nombre", actual=actual["NOMBRE"])
    ubicacion = ui.pedir_texto("Ubicación", actual=actual["UBICACION"])
    Departamentos.modificar(id_depto, nombre, ubicacion)
    ui.exito("Departamento actualizado.")


def _activar_desactivar_departamento() -> None:
    id_depto = ui.pedir_entero("ID del departamento")
    if ui.confirmar("¿Desactivar? (n = activar)"):
        Departamentos.desactivar(id_depto)
        ui.exito("Departamento desactivado.")
    else:
        Departamentos.activar(id_depto)
        ui.exito("Departamento activado.")


def _eliminar_departamento() -> None:
    id_depto = ui.pedir_entero("ID del departamento")
    if ui.confirmar("¿Eliminar definitivamente? Solo funciona si no tiene empleados"):
        Departamentos.eliminar(id_depto)
        ui.exito("Departamento eliminado.")


def menu_departamentos() -> None:
    ui.ejecutar_menu("Departamentos", [
        ("Listar", _listar_departamentos),
        ("Registrar", _registrar_departamento),
        ("Modificar", _modificar_departamento),
        ("Activar / desactivar", _activar_desactivar_departamento),
        ("Eliminar", _eliminar_departamento),
    ])


# ================================================================ EMPLEADOS
COLS_EMPLEADO = ["ID_EMPLEADO", "NOMBRE_COMPLETO", "CORREO", "USUARIO", "ROL", "DEPARTAMENTO", "ACTIVO"]


def _elegir_departamento(actual: int | None = None) -> int:
    ui.mostrar_tabla(Departamentos.listar(solo_activos=True), ["ID_DEPARTAMENTO", "NOMBRE"])
    return ui.pedir_entero("ID del departamento", actual=actual)


def _listar_empleados() -> None:
    id_depto = ui.pedir_entero("Filtrar por ID de departamento (ENTER = todos)", obligatorio=False)
    solo_activos = ui.confirmar("¿Solo activos?")
    ui.mostrar_tabla(Empleados.listar(id_depto, solo_activos), COLS_EMPLEADO)


def _buscar_empleados() -> None:
    texto = ui.pedir_texto("Nombre, correo o usuario")
    ui.mostrar_tabla(Empleados.buscar(texto), COLS_EMPLEADO)


def _ver_empleado() -> None:
    id_emp = ui.pedir_entero("ID del empleado")
    ui.mostrar_ficha(Empleados.obtener(id_emp))
    print("\n  Equipos (historial):")
    ui.mostrar_tabla(AsignacionEquipos.historial_empleado(id_emp),
                     ["ID_EQUIPO", "EQUIPO", "NUMERO_SERIE", "FECHA_INICIO", "FECHA_FIN", "SITUACION"])


def _registrar_empleado() -> None:
    id_depto = _elegir_departamento()
    nombre = ui.pedir_texto("Nombre completo")
    correo = ui.pedir_texto("Correo")
    usuario = ui.pedir_texto("Usuario")
    contrasena = ui.pedir_contrasena("Contraseña inicial (8+ caracteres, letras y números)")
    rol = ui.pedir_opcion("Rol", Empleados.ROLES)
    nuevo = Empleados.registrar(id_depto, nombre, correo, usuario, contrasena, rol)
    ui.exito(f"Empleado registrado con id {nuevo}.")
    if rol == "TECNICO":
        ui.aviso("Recuerde registrarlo también en Técnicos para que pueda recibir tickets.")


def _modificar_empleado() -> None:
    id_emp = ui.pedir_entero("ID del empleado")
    actual = Empleados.obtener(id_emp)
    if not actual:
        ui.aviso("El empleado no existe.")
        return
    print("  (ENTER conserva el valor actual)")
    id_depto = _elegir_departamento(actual["ID_DEPARTAMENTO"])
    nombre = ui.pedir_texto("Nombre completo", actual=actual["NOMBRE_COMPLETO"])
    correo = ui.pedir_texto("Correo", actual=actual["CORREO"])
    rol = ui.pedir_opcion("Rol", Empleados.ROLES, actual=actual["ROL"])
    Empleados.modificar(id_emp, id_depto, nombre, correo, rol)
    ui.exito("Empleado actualizado.")


def _desactivar_empleado(sesion: Sesion) -> None:
    id_emp = ui.pedir_entero("ID del empleado")
    if id_emp == sesion.id_empleado:
        ui.aviso("No puede desactivar su propio usuario.")
        return
    if ui.confirmar("Se devolverán sus equipos y licencias. ¿Continuar?"):
        Empleados.desactivar(id_emp)
        ui.exito("Empleado desactivado.")


def _activar_empleado() -> None:
    Empleados.activar(ui.pedir_entero("ID del empleado"))
    ui.exito("Empleado activado.")


def _restablecer_contrasena() -> None:
    id_emp = ui.pedir_entero("ID del empleado")
    nueva = ui.pedir_contrasena("Nueva contraseña")
    Empleados.restablecer_contrasena(id_emp, nueva)
    ui.exito("Contraseña restablecida.")


def _eliminar_empleado() -> None:
    id_emp = ui.pedir_entero("ID del empleado")
    if ui.confirmar("¿Eliminar definitivamente? Solo funciona sin historial"):
        Empleados.eliminar(id_emp)
        ui.exito("Empleado eliminado.")


def menu_empleados(sesion: Sesion) -> None:
    ui.ejecutar_menu("Empleados", [
        ("Listar", _listar_empleados),
        ("Buscar", _buscar_empleados),
        ("Ver ficha e historial de equipos", _ver_empleado),
        ("Registrar", _registrar_empleado),
        ("Modificar", _modificar_empleado),
        ("Desactivar", lambda: _desactivar_empleado(sesion)),
        ("Activar", _activar_empleado),
        ("Restablecer contraseña", _restablecer_contrasena),
        ("Eliminar", _eliminar_empleado),
    ])


# ================================================================ TÉCNICOS
COLS_TECNICO = ["ID_TECNICO", "ID_EMPLEADO", "NOMBRE_COMPLETO", "ESPECIALIDAD", "NIVEL",
                "ACTIVO", "TICKETS_ACTIVOS"]


def _registrar_tecnico() -> None:
    ui.mostrar_tabla(Empleados.listar(solo_activos=True), ["ID_EMPLEADO", "NOMBRE_COMPLETO", "DEPARTAMENTO", "ROL"])
    id_emp = ui.pedir_entero("ID del empleado")
    especialidad = ui.pedir_texto("Especialidad")
    nivel = ui.pedir_opcion("Nivel", Tecnicos.NIVELES)
    nuevo = Tecnicos.registrar(id_emp, especialidad, nivel)
    ui.exito(f"Técnico registrado con id {nuevo}.")


def _modificar_tecnico() -> None:
    id_tec = ui.pedir_entero("ID del técnico")
    actual = Tecnicos.obtener(id_tec)
    if not actual:
        ui.aviso("El técnico no existe.")
        return
    especialidad = ui.pedir_texto("Especialidad", actual=actual["ESPECIALIDAD"])
    nivel = ui.pedir_opcion("Nivel", Tecnicos.NIVELES, actual=actual["NIVEL"])
    Tecnicos.modificar(id_tec, especialidad, nivel)
    ui.exito("Técnico actualizado.")


def _activar_desactivar_tecnico() -> None:
    id_tec = ui.pedir_entero("ID del técnico")
    if ui.confirmar("¿Desactivar? Sus tickets pendientes volverán a la cola (n = activar)"):
        total = Tecnicos.desactivar(id_tec)
        ui.exito(f"Técnico desactivado. {total} ticket(s) devueltos a la cola.")
    else:
        Tecnicos.activar(id_tec)
        ui.exito("Técnico activado.")


def menu_tecnicos() -> None:
    ui.ejecutar_menu("Técnicos", [
        ("Listar", lambda: ui.mostrar_tabla(Tecnicos.listar(), COLS_TECNICO)),
        ("Registrar", _registrar_tecnico),
        ("Modificar", _modificar_tecnico),
        ("Activar / desactivar", _activar_desactivar_tecnico),
    ])


# ================================================================ EQUIPOS
COLS_EQUIPO = ["ID_EQUIPO", "TIPO", "MARCA", "MODELO", "NUMERO_SERIE", "ESTADO", "FECHA_COMPRA", "ASIGNADO_A"]


def _listar_equipos() -> None:
    estado = ui.pedir_opcion("Estado", Equipos.ESTADOS, obligatorio=False)
    tipo = ui.pedir_opcion("Tipo", Equipos.TIPOS, obligatorio=False)
    ui.mostrar_tabla(Equipos.listar(estado, tipo), COLS_EQUIPO)
    print(f"  Inventario: {Equipos.resumen_inventario()}")


def _registrar_equipo() -> None:
    tipo = ui.pedir_opcion("Tipo", Equipos.TIPOS)
    marca = ui.pedir_texto("Marca")
    modelo = ui.pedir_texto("Modelo")
    serie = ui.pedir_texto("Número de serie")
    fecha = ui.pedir_fecha("Fecha de compra")
    nuevo = Equipos.registrar(tipo, marca, modelo, serie, fecha)
    ui.exito(f"Equipo registrado con id {nuevo} (DISPONIBLE).")


def _modificar_equipo() -> None:
    id_eq = ui.pedir_entero("ID del equipo")
    actual = Equipos.obtener(id_eq)
    if not actual:
        ui.aviso("El equipo no existe.")
        return
    print("  (ENTER conserva el valor actual)")
    tipo = ui.pedir_opcion("Tipo", Equipos.TIPOS, actual=actual["TIPO"])
    marca = ui.pedir_texto("Marca", actual=actual["MARCA"])
    modelo = ui.pedir_texto("Modelo", actual=actual["MODELO"])
    serie = ui.pedir_texto("Número de serie", actual=actual["NUMERO_SERIE"])
    fecha = ui.pedir_fecha("Fecha de compra", actual=actual["FECHA_COMPRA"].date())
    Equipos.modificar(id_eq, tipo, marca, modelo, serie, fecha)
    ui.exito("Equipo actualizado.")


def _cambiar_estado_equipo() -> None:
    id_eq = ui.pedir_entero("ID del equipo")
    estado = ui.pedir_opcion("Nuevo estado", ("DISPONIBLE", "REPARACION"))
    Equipos.cambiar_estado(id_eq, estado)
    ui.exito(f"Equipo {id_eq} ahora está {estado}.")


def _dar_baja_equipo() -> None:
    id_eq = ui.pedir_entero("ID del equipo")
    if ui.confirmar("La baja es definitiva. ¿Continuar?"):
        Equipos.dar_baja(id_eq)
        ui.exito("Equipo dado de baja.")


def _eliminar_equipo() -> None:
    id_eq = ui.pedir_entero("ID del equipo")
    if ui.confirmar("¿Eliminar el registro? Solo funciona si nunca se asignó"):
        Equipos.eliminar(id_eq)
        ui.exito("Equipo eliminado.")


def menu_equipos() -> None:
    ui.ejecutar_menu("Equipos", [
        ("Listar / filtrar", _listar_equipos),
        ("Ver ficha", lambda: ui.mostrar_ficha(Equipos.obtener(ui.pedir_entero("ID del equipo")))),
        ("Registrar", _registrar_equipo),
        ("Modificar", _modificar_equipo),
        ("Cambiar estado (disponible / reparación)", _cambiar_estado_equipo),
        ("Dar de baja", _dar_baja_equipo),
        ("Eliminar", _eliminar_equipo),
    ])


# ================================================================ ASIGNACIÓN DE EQUIPOS (RF-03)
def _asignar_equipo() -> None:
    ui.mostrar_tabla(Equipos.listar("DISPONIBLE"), COLS_EQUIPO, vacio="No hay equipos disponibles.")
    id_eq = ui.pedir_entero("ID del equipo (también puede traspasar uno ya asignado)")
    id_emp = ui.pedir_entero("ID del empleado que lo recibe")
    AsignacionEquipos.asignar(id_eq, id_emp)
    ui.exito("Equipo asignado. El historial quedó registrado.")


def _devolver_equipo() -> None:
    id_eq = ui.pedir_entero("ID del equipo devuelto")
    AsignacionEquipos.devolver(id_eq)
    ui.exito("Devolución registrada; el equipo quedó DISPONIBLE.")


def menu_asignaciones() -> None:
    ui.ejecutar_menu("Asignación de equipos", [
        ("Asignar o traspasar equipo", _asignar_equipo),
        ("Registrar devolución", _devolver_equipo),
        ("Asignaciones vigentes", lambda: ui.mostrar_tabla(
            AsignacionEquipos.activas(),
            ["ID_EQUIPO", "TIPO", "EQUIPO", "NUMERO_SERIE", "EMPLEADO", "DEPARTAMENTO", "DIAS_ASIGNADO"])),
        ("Historial de un equipo", lambda: ui.mostrar_tabla(
            AsignacionEquipos.historial_equipo(ui.pedir_entero("ID del equipo")),
            ["EMPLEADO", "FECHA_INICIO", "FECHA_FIN", "SITUACION", "DIAS"])),
    ])


# ================================================================ TICKETS
def menu_tickets(sesion: Sesion) -> None:
    ui.ejecutar_menu("Tickets", [
        ("Consultar con filtros", mt.filtrar_tickets),
        ("Ver detalle", mt.ver_detalle),
        ("Sin asignar", mt.tickets_sin_asignar),
        ("Asignar técnico", mt.asignar_tecnico),
        ("Asignación automática por carga", mt.asignacion_automatica),
        ("Cambiar estado", lambda: mt.cambiar_estado(sesion)),
        ("Crear ticket a nombre de un empleado", lambda: mt.crear_ticket(sesion, para_otro=True)),
        ("Modificar ticket", lambda: mt.modificar_ticket(sesion)),
        ("Eliminar ticket creado por error", mt.eliminar_ticket),
    ])


# ================================================================ PANEL
def panel_resumen() -> None:
    datos = Panel.resumen()
    ui.titulo("Panel de soporte TI")
    print(f"  Tickets abiertos ............ {datos['abiertos']}")
    print(f"    de ellos sin técnico ...... {datos['sin_asignar']}")
    print(f"  Tickets en proceso .......... {datos['en_proceso']}")
    print(f"  Pendientes CRÍTICOS ......... {datos['criticos']}")
    print(f"  Promedio de resolución ...... {datos['promedio_horas'] or 0:.2f} h")
    print(f"  Equipos disponibles ......... {datos['equipos_disponibles']}")
    print(f"  Licencias por vencer (30 d) . {datos['licencias_por_vencer']}")
    print("\n  Carga por técnico:")
    ui.mostrar_tabla(Panel.tickets_por_tecnico(),
                     ["TECNICO", "TOTAL", "ABIERTOS", "EN_PROCESO", "RESUELTOS", "CERRADOS", "PROMEDIO_HORAS"])


def menu_principal(sesion: Sesion, cambiar_contrasena) -> None:
    ui.ejecutar_menu(f"Administrador de TI - {sesion.nombre}", [
        ("Panel resumen", panel_resumen),
        ("Departamentos", ui.submenu(menu_departamentos)),
        ("Empleados", ui.submenu(lambda: menu_empleados(sesion))),
        ("Técnicos", ui.submenu(menu_tecnicos)),
        ("Equipos", ui.submenu(menu_equipos)),
        ("Asignación de equipos", ui.submenu(menu_asignaciones)),
        ("Tickets", ui.submenu(lambda: menu_tickets(sesion))),
        ("Cambiar mi contraseña", cambiar_contrasena),
    ])
