"""Servicios de catálogos: departamentos, empleados, técnicos, equipos y licencias.

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
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, _sn(solo_activos)])

    @classmethod
    def obtener(cls, id_departamento: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_departamento, "N"]).primero()

    @classmethod
    def registrar(cls, nombre: str, ubicacion: str) -> int:
        return bd.guardar(f"{cls.PKG}.pr_guardar", None, [nombre, ubicacion])

    @classmethod
    def modificar(cls, id_departamento: int, nombre: str, ubicacion: str) -> None:
        bd.guardar(f"{cls.PKG}.pr_guardar", id_departamento, [nombre, ubicacion])

    @classmethod
    def desactivar(cls, id_departamento: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_activo", [id_departamento, "N"])

    @classmethod
    def activar(cls, id_departamento: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_activo", [id_departamento, "S"])

    @classmethod
    def eliminar(cls, id_departamento: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_departamento])


# ============================================================ EMPLEADOS (RF-01)
class Empleados:
    PKG = "pkg_empleado"
    ROLES = ("ADMIN", "TECNICO", "EMPLEADO")

    @classmethod
    def listar(cls, id_departamento: int | None = None, solo_activos: bool = False) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, id_departamento, _sn(solo_activos), None])

    @classmethod
    def buscar(cls, texto: str) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, None, "N", texto])

    @classmethod
    def obtener(cls, id_empleado: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_empleado, None, "N", None]).primero()

    @classmethod
    def registrar(cls, id_departamento: int, nombre: str, correo: str, usuario: str,
                  contrasena: str, rol: str) -> int:
        return bd.guardar(f"{cls.PKG}.pr_guardar", None,
                          [id_departamento, nombre, correo, usuario, contrasena, rol])

    @classmethod
    def modificar(cls, id_empleado: int, id_departamento: int, nombre: str, correo: str,
                  rol: str) -> None:
        bd.guardar(f"{cls.PKG}.pr_guardar", id_empleado,
                   [id_departamento, nombre, correo, None, None, rol])

    @classmethod
    def desactivar(cls, id_empleado: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_activo", [id_empleado, "N"])

    @classmethod
    def activar(cls, id_empleado: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_activo", [id_empleado, "S"])

    @classmethod
    def eliminar(cls, id_empleado: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_empleado])

    @classmethod
    def restablecer_contrasena(cls, id_empleado: int, nueva: str) -> None:
        """El administrador fija una nueva contraseña sin conocer la anterior."""
        bd.ejecutar("pkg_seguridad.pr_cambiar_contrasena", [id_empleado, None, nueva])


# ============================================================ TÉCNICOS
class Tecnicos:
    PKG = "pkg_tecnico"
    NIVELES = ("JUNIOR", "INTERMEDIO", "SENIOR")

    @classmethod
    def listar(cls, solo_activos: bool = False) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, _sn(solo_activos)])

    @classmethod
    def obtener(cls, id_tecnico: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_tecnico, "N"]).primero()

    @classmethod
    def registrar(cls, id_empleado: int, especialidad: str, nivel: str) -> int:
        return bd.guardar(f"{cls.PKG}.pr_guardar", None, [id_empleado, especialidad, nivel])

    @classmethod
    def modificar(cls, id_tecnico: int, especialidad: str, nivel: str) -> None:
        bd.guardar(f"{cls.PKG}.pr_guardar", id_tecnico, [None, especialidad, nivel])

    @classmethod
    def desactivar(cls, id_tecnico: int) -> int:
        """Devuelve cuántos tickets volvieron a la cola."""
        (reasignados,) = bd.ejecutar(f"{cls.PKG}.pr_cambiar_activo", [id_tecnico, "N"], [int])
        return reasignados

    @classmethod
    def activar(cls, id_tecnico: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_activo", [id_tecnico, "S"], [int])

    @classmethod
    def menor_carga(cls) -> int | None:
        return bd.funcion(f"{cls.PKG}.fn_menor_carga", int)


# ============================================================ EQUIPOS (RF-02)
class Equipos:
    PKG = "pkg_equipo"
    TIPOS = ("LAPTOP", "ESCRITORIO", "SERVIDOR", "MONITOR", "IMPRESORA", "RED", "OTRO")
    ESTADOS = ("DISPONIBLE", "ASIGNADO", "REPARACION", "BAJA")

    @classmethod
    def listar(cls, estado: str | None = None, tipo: str | None = None) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, estado, tipo])

    @classmethod
    def obtener(cls, id_equipo: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_equipo, None, None]).primero()

    @classmethod
    def registrar(cls, tipo: str, marca: str, modelo: str, serie: str, fecha_compra: date) -> int:
        return bd.guardar(f"{cls.PKG}.pr_guardar", None, [tipo, marca, modelo, serie, fecha_compra])

    @classmethod
    def modificar(cls, id_equipo: int, tipo: str, marca: str, modelo: str, serie: str,
                  fecha_compra: date) -> None:
        bd.guardar(f"{cls.PKG}.pr_guardar", id_equipo, [tipo, marca, modelo, serie, fecha_compra])

    @classmethod
    def cambiar_estado(cls, id_equipo: int, estado: str) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_estado", [id_equipo, estado])

    @classmethod
    def dar_baja(cls, id_equipo: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_cambiar_estado", [id_equipo, "BAJA"])

    @classmethod
    def eliminar(cls, id_equipo: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_equipo])

    @classmethod
    def resumen_inventario(cls) -> str:
        return bd.funcion(f"{cls.PKG}.fn_resumen_inventario", str)


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
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, None, "S"])

    @classmethod
    def historial_equipo(cls, id_equipo: int) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_equipo, None, "N"])

    @classmethod
    def historial_empleado(cls, id_empleado: int) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, id_empleado, "N"])


# ============================================================ LICENCIAS (RF-08, RF-09)
class Licencias:
    PKG = "pkg_licencia"

    @classmethod
    def listar(cls) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, None])

    @classmethod
    def por_vencer(cls, dias: int = 30) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [None, dias])

    @classmethod
    def obtener(cls, id_licencia: int) -> dict | None:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_licencia, None]).primero()

    @classmethod
    def registrar(cls, software: str, proveedor: str, clave: str, vencimiento: date,
                  cantidad: int) -> int:
        return bd.guardar(f"{cls.PKG}.pr_guardar", None,
                          [software, proveedor, clave, vencimiento, cantidad])

    @classmethod
    def modificar(cls, id_licencia: int, software: str, proveedor: str, clave: str,
                  vencimiento: date, cantidad: int) -> None:
        bd.guardar(f"{cls.PKG}.pr_guardar", id_licencia,
                   [software, proveedor, clave, vencimiento, cantidad])

    @classmethod
    def eliminar(cls, id_licencia: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_eliminar", [id_licencia])


# ============================================================ ASIGNACIÓN DE LICENCIAS (RF-08)
class AsignacionLicencias:
    PKG = "pkg_asignacion_licencia"

    @classmethod
    def listar(cls, id_licencia: int | None = None, id_empleado: int | None = None,
               id_equipo: int | None = None) -> Resultado:
        return bd.consultar(f"{cls.PKG}.fn_listar", [id_licencia, id_empleado, id_equipo])

    @classmethod
    def asignar_a_empleado(cls, id_licencia: int, id_empleado: int) -> int:
        (nuevo_id,) = bd.ejecutar(f"{cls.PKG}.pr_asignar", [id_licencia, id_empleado, None], [int])
        return nuevo_id

    @classmethod
    def asignar_a_equipo(cls, id_licencia: int, id_equipo: int) -> int:
        (nuevo_id,) = bd.ejecutar(f"{cls.PKG}.pr_asignar", [id_licencia, None, id_equipo], [int])
        return nuevo_id

    @classmethod
    def revocar(cls, id_asignacion: int) -> None:
        bd.ejecutar(f"{cls.PKG}.pr_revocar", [id_asignacion], [int])

    @classmethod
    def revocar_vencidas(cls) -> int:
        (revocadas,) = bd.ejecutar(f"{cls.PKG}.pr_revocar", [None], [int])
        return revocadas
