"""Servicios de soporte: seguridad, tickets y panel resumen."""
from __future__ import annotations

from dataclasses import dataclass

from app.db.conexion import ErrorNegocio, Resultado, bd


@dataclass
class Sesion:
    id_empleado: int
    nombre: str
    usuario: str
    rol: str
    departamento: str
    id_tecnico: int | None

    @property
    def es_admin(self) -> bool:
        return self.rol == "ADMIN"

    @property
    def es_tecnico(self) -> bool:
        return self.id_tecnico is not None


# ============================================================ SEGURIDAD (RF-12)
class Seguridad:
    PKG = "pkg_seguridad"

    @classmethod
    def iniciar_sesion(cls, usuario: str, contrasena: str) -> Sesion:
        fila = bd.consultar(f"{cls.PKG}.pr_iniciar_sesion", [usuario, contrasena]).primero()
        if fila is None:
            raise ErrorNegocio("No se pudo iniciar sesión.")
        return Sesion(
            id_empleado=int(fila["ID_EMPLEADO"]),
            nombre=fila["NOMBRE_COMPLETO"],
            usuario=fila["USUARIO"],
            rol=fila["ROL"],
            departamento=fila["DEPARTAMENTO"],
            id_tecnico=int(fila["ID_TECNICO"]) if fila["ID_TECNICO"] is not None else None,
        )

    @classmethod
    def cambiar_contrasena(cls, id_empleado: int, actual: str, nueva: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_contrasena", [id_empleado, actual, nueva])


# ============================================================ TICKETS (RF-04, RF-05, RF-06)
class Tickets:
    PKG = "pkg_ticket"
    CATEGORIAS = ("HARDWARE", "SOFTWARE", "RED", "ACCESOS", "OTRO")
    PRIORIDADES = ("BAJA", "MEDIA", "ALTA", "CRITICA")
    ESTADOS = ("ABIERTO", "EN_PROCESO", "RESUELTO", "CERRADO")

    @classmethod
    def crear(cls, id_empleado: int, id_equipo: int | None, titulo: str, descripcion: str,
              categoria: str, prioridad: str) -> int:
        (nuevo_id,) = bd.ejecutar(
            f"{cls.PKG}.pr_crear",
            [id_empleado, id_equipo, titulo, descripcion, categoria, prioridad],
            [int],
        )
        return nuevo_id

    @classmethod
    def modificar(cls, id_ticket: int, titulo: str, descripcion: str, categoria: str,
                  prioridad: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_actualizar", [id_ticket, titulo, descripcion, categoria, prioridad])

    @classmethod
    def asignar_tecnico(cls, id_ticket: int, id_tecnico: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_asignar_tecnico", [id_ticket, id_tecnico])

    @classmethod
    def cambiar_estado(cls, id_ticket: int, estado: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_estado", [id_ticket, estado])

    @classmethod
    def asignar_automatico(cls) -> int:
        (asignados,) = bd.ejecutar(f"{cls.PKG}.pr_asignar_automatico", [], [int])
        return asignados

    @classmethod
    def eliminar(cls, id_ticket: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_ticket])

    @classmethod
    def obtener(cls, id_ticket: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.pr_obtener", [id_ticket]).primero()

    @classmethod
    def filtrar(cls, estado: str | None = None, prioridad: str | None = None,
                id_tecnico: int | None = None, id_empleado: int | None = None,
                sin_asignar: bool = False) -> Resultado:
        return bd.consultar(
            f"{cls.PKG}.pr_filtrar",
            [estado, prioridad, id_tecnico, id_empleado, "S" if sin_asignar else "N"],
        )

    @classmethod
    def comentarios(cls, id_ticket: int) -> Resultado:
        """Solo lectura en esta entrega; el registro de comentarios (RF-07) llega en la semana 10."""
        return bd.consultar("pkg_comentario.pr_listar_por_ticket", [id_ticket])


# ============================================================ PANEL RESUMEN
class Panel:
    @staticmethod
    def resumen() -> dict[str, float]:
        valores = bd.ejecutar(
            "pkg_reportes.pr_panel_resumen", [], [int, int, int, int, int, int, float], confirmar=False
        )
        claves = ("abiertos", "en_proceso", "sin_asignar", "criticos",
                  "equipos_disponibles", "licencias_por_vencer", "promedio_horas")
        return dict(zip(claves, valores))

    @staticmethod
    def tickets_por_tecnico() -> Resultado:
        return bd.consultar("pkg_reportes.pr_tickets_por_tecnico")
