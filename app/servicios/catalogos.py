"""Servicios de catálogos: departamentos, empleados, técnicos y equipos.

Cada función solo invoca un procedimiento o función de un paquete PL/SQL.
"""
from __future__ import annotations

from datetime import date

from app.db.conexion import Resultado, bd


def _sn(valor: bool) -> str:
    return "S" if valor else "N"


# ============================================================ DEPARTAMENTOS (RF-01)
class Departamentos:
    PKG = "pkg_departamento"

    @classmethod
    def listar(cls, solo_activos: bool = False) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_listar", [_sn(solo_activos)])

    @classmethod
    def obtener(cls, id_departamento: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.pr_obtener", [id_departamento]).primero()

    @classmethod
    def registrar(cls, nombre: str, ubicacion: str) -> int:
        (nuevo_id,) = bd.ejecutar(f"{cls.PKG}.pr_insertar", [nombre, ubicacion], [int])
        return nuevo_id

    @classmethod
    def modificar(cls, id_departamento: int, nombre: str, ubicacion: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_actualizar", [id_departamento, nombre, ubicacion])

    @classmethod
    def desactivar(cls, id_departamento: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_desactivar", [id_departamento])

    @classmethod
    def activar(cls, id_departamento: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_activar", [id_departamento])

    @classmethod
    def eliminar(cls, id_departamento: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_departamento])


# ============================================================ EMPLEADOS (RF-01)
class Empleados:
    PKG = "pkg_empleado"
    ROLES = ("ADMIN", "TECNICO", "EMPLEADO")

    @classmethod
    def listar(cls, id_departamento: int | None = None, solo_activos: bool = False) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_listar", [id_departamento, _sn(solo_activos)])

    @classmethod
    def buscar(cls, texto: str) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_buscar", [texto])

    @classmethod
    def obtener(cls, id_empleado: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.pr_obtener", [id_empleado]).primero()

    @classmethod
    def registrar(cls, id_departamento: int, nombre: str, correo: str, usuario: str,
                  contrasena: str, rol: str) -> int:
        (nuevo_id,) = bd.ejecutar(
            f"{cls.PKG}.pr_insertar",
            [id_departamento, nombre, correo, usuario, contrasena, rol],
            [int],
        )
        return nuevo_id

    @classmethod
    def modificar(cls, id_empleado: int, id_departamento: int, nombre: str, correo: str,
                  rol: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_actualizar", [id_empleado, id_departamento, nombre, correo, rol])

    @classmethod
    def desactivar(cls, id_empleado: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_desactivar", [id_empleado])

    @classmethod
    def activar(cls, id_empleado: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_activar", [id_empleado])

    @classmethod
    def eliminar(cls, id_empleado: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_empleado])

    @classmethod
    def restablecer_contrasena(cls, id_empleado: int, nueva: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_restablecer_contrasena", [id_empleado, nueva])


# ============================================================ TÉCNICOS
class Tecnicos:
    PKG = "pkg_tecnico"
    NIVELES = ("JUNIOR", "INTERMEDIO", "SENIOR")

    @classmethod
    def listar(cls, solo_activos: bool = False) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_listar", [_sn(solo_activos)])

    @classmethod
    def obtener(cls, id_tecnico: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.pr_obtener", [id_tecnico]).primero()

    @classmethod
    def registrar(cls, id_empleado: int, especialidad: str, nivel: str) -> int:
        (nuevo_id,) = bd.ejecutar(f"{cls.PKG}.pr_insertar", [id_empleado, especialidad, nivel], [int])
        return nuevo_id

    @classmethod
    def modificar(cls, id_tecnico: int, especialidad: str, nivel: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_actualizar", [id_tecnico, especialidad, nivel])

    @classmethod
    def desactivar(cls, id_tecnico: int) -> int:
        """Devuelve cuántos tickets volvieron a la cola."""
        (reasignados,) = bd.ejecutar(f"{cls.PKG}.pr_desactivar", [id_tecnico], [int])
        return reasignados

    @classmethod
    def activar(cls, id_tecnico: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_activar", [id_tecnico])

    @classmethod
    def menor_carga(cls) -> int | None:
        return bd.funcion(f"{cls.PKG}.fn_tecnico_menor_carga", int)


# ============================================================ EQUIPOS (RF-02)
class Equipos:
    PKG = "pkg_equipo"
    TIPOS = ("LAPTOP", "ESCRITORIO", "SERVIDOR", "MONITOR", "IMPRESORA", "RED", "OTRO")
    ESTADOS = ("DISPONIBLE", "ASIGNADO", "REPARACION", "BAJA")

    @classmethod
    def listar(cls, estado: str | None = None, tipo: str | None = None) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_listar", [estado, tipo])

    @classmethod
    def obtener(cls, id_equipo: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.pr_obtener", [id_equipo]).primero()

    @classmethod
    def registrar(cls, tipo: str, marca: str, modelo: str, serie: str, fecha_compra: date) -> int:
        (nuevo_id,) = bd.ejecutar(
            f"{cls.PKG}.pr_insertar", [tipo, marca, modelo, serie, fecha_compra], [int]
        )
        return nuevo_id

    @classmethod
    def modificar(cls, id_equipo: int, tipo: str, marca: str, modelo: str, serie: str,
                  fecha_compra: date) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_actualizar", [id_equipo, tipo, marca, modelo, serie, fecha_compra])

    @classmethod
    def cambiar_estado(cls, id_equipo: int, estado: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_estado", [id_equipo, estado])

    @classmethod
    def dar_baja(cls, id_equipo: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_dar_baja", [id_equipo])

    @classmethod
    def eliminar(cls, id_equipo: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_equipo])

    @classmethod
    def resumen_inventario(cls) -> str:
        (texto,) = bd.ejecutar(f"{cls.PKG}.pr_resumen_inventario", [], [str], confirmar=False)
        return texto


# ============================================================ ASIGNACIÓN DE EQUIPOS (RF-03)
class AsignacionEquipos:
    PKG = "pkg_asignacion_equipo"

    @classmethod
    def asignar(cls, id_equipo: int, id_empleado: int) -> int:
        (nuevo_id,) = bd.ejecutar(f"{cls.PKG}.pr_asignar", [id_equipo, id_empleado], [int])
        return nuevo_id

    @classmethod
    def devolver(cls, id_equipo: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_devolver", [id_equipo])

    @classmethod
    def activas(cls) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_listar_activas")

    @classmethod
    def historial_equipo(cls, id_equipo: int) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_historial_equipo", [id_equipo])

    @classmethod
    def historial_empleado(cls, id_empleado: int) -> Resultado:
        return bd.consultar(f"{cls.PKG}.pr_historial_empleado", [id_empleado])
