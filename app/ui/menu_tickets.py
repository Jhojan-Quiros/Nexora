"""Pantallas de tickets compartidas por los tres roles (RF-04, RF-05, RF-06)."""
from __future__ import annotations

from app.servicios.catalogos import AsignacionEquipos, Tecnicos
from app.servicios.soporte import Sesion, Tickets
from app.ui import utilidades as ui

COLUMNAS_LISTA = ["ID_TICKET", "TITULO", "CATEGORIA", "PRIORIDAD", "ESTADO",
                  "SOLICITANTE", "TECNICO", "FECHA_CREACION"]


def crear_ticket(sesion: Sesion, para_otro: bool = False) -> None:
    ui.titulo("Nuevo ticket de soporte")
    id_empleado = sesion.id_empleado
    if para_otro:
        id_empleado = ui.pedir_entero("ID del empleado solicitante")

    # Ofrece los equipos que el solicitante tiene asignados
    equipos = AsignacionEquipos.historial_empleado(id_empleado).como_diccionarios()
    vigentes = [e for e in equipos if e["SITUACION"] == "VIGENTE"]
    id_equipo = None
    if vigentes:
        print("  Equipos asignados:")
        for e in vigentes:
            print(f"    {e['ID_EQUIPO']}. {e['EQUIPO']} ({e['NUMERO_SERIE']})")
        id_equipo = ui.pedir_entero("ID del equipo afectado (ENTER si no aplica)", obligatorio=False)

    titulo = ui.pedir_texto("Título")
    descripcion = ui.pedir_texto("Descripción")
    categoria = ui.pedir_opcion("Categoría", Tickets.CATEGORIAS)
    prioridad = ui.pedir_opcion("Prioridad", Tickets.PRIORIDADES)
    nuevo = Tickets.crear(id_empleado, id_equipo, titulo, descripcion, categoria, prioridad)
    ui.exito(f"Ticket #{nuevo} creado. Estado: ABIERTO.")


def ver_detalle() -> None:
    id_ticket = ui.pedir_entero("ID del ticket")
    datos = Tickets.obtener(id_ticket)
    ui.mostrar_ficha(datos, ["ID_TICKET", "TITULO", "DESCRIPCION", "CATEGORIA", "PRIORIDAD",
                             "ESTADO", "SOLICITANTE", "DEPARTAMENTO", "TECNICO", "NUMERO_SERIE",
                             "FECHA_CREACION", "FECHA_CIERRE", "HORAS_RESOLUCION"])
    if datos:
        print("\n  Seguimiento:")
        ui.mostrar_tabla(Tickets.comentarios(id_ticket), ["FECHA", "TECNICO", "TEXTO"],
                         vacio="Sin comentarios todavía.")


def filtrar_tickets(id_empleado_fijo: int | None = None, id_tecnico_fijo: int | None = None) -> None:
    ui.titulo("Consultar tickets")
    estado = ui.pedir_opcion("Estado", Tickets.ESTADOS, obligatorio=False)
    prioridad = ui.pedir_opcion("Prioridad", Tickets.PRIORIDADES, obligatorio=False)
    id_tecnico = id_tecnico_fijo
    id_empleado = id_empleado_fijo
    if id_empleado_fijo is None and id_tecnico_fijo is None:
        id_tecnico = ui.pedir_entero("ID de técnico (ENTER = todos)", obligatorio=False)
        id_empleado = ui.pedir_entero("ID de empleado solicitante (ENTER = todos)", obligatorio=False)
    ui.mostrar_tabla(Tickets.filtrar(estado, prioridad, id_tecnico, id_empleado), COLUMNAS_LISTA)


def tickets_sin_asignar() -> None:
    ui.mostrar_tabla(Tickets.filtrar(estado="ABIERTO", sin_asignar=True), COLUMNAS_LISTA,
                     vacio="No hay tickets pendientes de asignar.")


def asignar_tecnico() -> None:
    tickets_sin_asignar()
    id_ticket = ui.pedir_entero("ID del ticket")
    ui.mostrar_tabla(Tecnicos.listar(solo_activos=True),
                     ["ID_TECNICO", "NOMBRE_COMPLETO", "ESPECIALIDAD", "NIVEL", "TICKETS_ACTIVOS"])
    sugerido = Tecnicos.menor_carga()
    id_tecnico = ui.pedir_entero("ID del técnico", actual=sugerido)
    Tickets.asignar_tecnico(id_ticket, id_tecnico)
    ui.exito(f"Ticket #{id_ticket} asignado al técnico {id_tecnico} (EN_PROCESO).")


def asignacion_automatica() -> None:
    if ui.confirmar("¿Repartir todos los tickets sin técnico según la carga de trabajo?"):
        total = Tickets.asignar_automatico()
        ui.exito(f"{total} ticket(s) asignado(s).")


def tomar_ticket(sesion: Sesion) -> None:
    tickets_sin_asignar()
    id_ticket = ui.pedir_entero("ID del ticket que desea atender")
    Tickets.asignar_tecnico(id_ticket, sesion.id_tecnico)
    ui.exito(f"Ticket #{id_ticket} asignado a usted.")


def cambiar_estado(sesion: Sesion) -> None:
    id_ticket = ui.pedir_entero("ID del ticket")
    datos = Tickets.obtener(id_ticket)
    if not datos:
        ui.aviso("El ticket no existe.")
        return
    if not sesion.es_admin and datos["ID_TECNICO"] != sesion.id_tecnico:
        ui.aviso("Solo puede cambiar el estado de los tickets asignados a usted.")
        return
    print(f"  Estado actual: {datos['ESTADO']}")
    nuevo = ui.pedir_opcion("Nuevo estado", Tickets.ESTADOS)
    Tickets.cambiar_estado(id_ticket, nuevo)
    ui.exito(f"Ticket #{id_ticket} ahora está {nuevo}.")


def modificar_ticket(sesion: Sesion) -> None:
    id_ticket = ui.pedir_entero("ID del ticket")
    datos = Tickets.obtener(id_ticket)
    if not datos:
        ui.aviso("El ticket no existe.")
        return
    if not sesion.es_admin and datos["ID_EMPLEADO"] != sesion.id_empleado:
        ui.aviso("Solo puede modificar sus propios tickets.")
        return
    print("  (ENTER conserva el valor actual)")
    titulo = ui.pedir_texto("Título", actual=datos["TITULO"])
    descripcion = ui.pedir_texto("Descripción", actual=datos["DESCRIPCION"])
    categoria = ui.pedir_opcion("Categoría", Tickets.CATEGORIAS, actual=datos["CATEGORIA"])
    prioridad = ui.pedir_opcion("Prioridad", Tickets.PRIORIDADES, actual=datos["PRIORIDAD"])
    Tickets.modificar(id_ticket, titulo, descripcion, categoria, prioridad)
    ui.exito("Ticket actualizado.")


def eliminar_ticket() -> None:
    id_ticket = ui.pedir_entero("ID del ticket (solo ABIERTOS sin técnico)")
    if ui.confirmar(f"¿Eliminar definitivamente el ticket #{id_ticket}?"):
        Tickets.eliminar(id_ticket)
        ui.exito("Ticket eliminado.")
