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
        fila = bd.consultar(f"{cls.PKG}.fn_iniciar_sesion", [usuario, contrasena]).primero()
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
        if not actual:
            raise ErrorNegocio("Debe indicar la contraseña actual.")
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
        return bd.guardar(f"{cls.PKG}.pr_guardar", None,
                          [id_empleado, id_equipo, titulo, descripcion, categoria, prioridad])

    @classmethod
    def modificar(cls, id_ticket: int, titulo: str, descripcion: str, categoria: str,
                  prioridad: str) -> None:
        bd.guardar(f"{cls.PKG}.pr_guardar", id_ticket,
                   [None, None, titulo, descripcion, categoria, prioridad])

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
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_ticket, None, None, None, None, "N"]).primero()

    @classmethod
    def filtrar(cls, estado: str | None = None, prioridad: str | None = None,
                id_tecnico: int | None = None, id_empleado: int | None = None,
                sin_asignar: bool = False) -> Resultado:
        return bd.consultar(
            f"{cls.PKG}.fn_listar",
            [None, estado, prioridad, id_tecnico, id_empleado, "S" if sin_asignar else "N"],
        )

    @classmethod
    def comentarios(cls, id_ticket: int) -> Resultado:
        return bd.consultar("pkg_comentario.fn_listar", [id_ticket])

    @classmethod
    def comentar(cls, id_ticket: int, id_tecnico: int, texto: str) -> int:
        """RF-07: registra un comentario de seguimiento del técnico."""
        return bd.guardar("pkg_comentario.pr_guardar", None, [id_ticket, id_tecnico, texto])


# ============================================================ PANEL RESUMEN
class Panel:
    @staticmethod
    def resumen() -> dict[str, float]:
        fila = bd.consultar("pkg_reportes.fn_panel_resumen").primero() or {}
        return {clave.lower(): (valor or 0) for clave, valor in fila.items()}

    @staticmethod
    def tickets_por_tecnico() -> Resultado:
        return bd.consultar("pkg_reportes.fn_reporte", ["TECNICOS", None])


# ============================================================ REPORTES (RF-10, RF-11)
class Reportes:
    TIPOS = ("TECNICOS", "ESTADOS", "RESOLUCION", "EQUIPOS_DEPARTAMENTO", "LICENCIAS_VENCER")

    @staticmethod
    def generar(tipo: str, dias: int = 30) -> Resultado:
        return bd.consultar("pkg_reportes.fn_reporte", [tipo, dias])

    @staticmethod
    def exportar_csv(tipo: str, ruta: str, dias: int = 30) -> int:
        """Guarda el reporte en un archivo CSV (UTF-8 con BOM para Excel). Devuelve las filas escritas."""
        import csv

        resultado = Reportes.generar(tipo, dias)
        with open(ruta, "w", newline="", encoding="utf-8-sig") as archivo:
            escritor = csv.writer(archivo)
            escritor.writerow(resultado.columnas)
            escritor.writerows(resultado.filas)
        return len(resultado)
