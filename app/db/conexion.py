"""Módulo de conexión a Oracle.

Toda la comunicación con la base de datos pasa por esta clase y se hace
EXCLUSIVAMENTE llamando procedimientos y funciones almacenados
(callproc / callfunc). El proyecto no contiene sentencias SQL.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Sequence

import oracledb

from app.config import CONFIG


class ErrorNegocio(Exception):
    """Error controlado lanzado por la base de datos (ORA-20001 a ORA-20999)."""


class ErrorBaseDatos(Exception):
    """Error técnico de Oracle (conexión, restricción, objeto inválido...)."""


@dataclass
class Resultado:
    """Filas devueltas por un SYS_REFCURSOR."""

    columnas: list[str] = field(default_factory=list)
    filas: list[tuple] = field(default_factory=list)

    def como_diccionarios(self) -> list[dict[str, Any]]:
        return [dict(zip(self.columnas, fila)) for fila in self.filas]

    def primero(self) -> dict[str, Any] | None:
        datos = self.como_diccionarios()
        return datos[0] if datos else None

    def __len__(self) -> int:
        return len(self.filas)


# Mensajes amigables para errores de Oracle que no son de negocio
_MENSAJES_ORACLE = {
    1: "El registro ya existe (valor duplicado).",
    1400: "Falta un dato obligatorio.",
    2290: "Un valor no cumple las reglas permitidas.",
    2291: "El registro relacionado no existe.",
    2292: "No se puede eliminar: hay registros que dependen de este.",
    4061: "El paquete se recompiló; repita la operación.",
    12541: "No hay un servidor Oracle escuchando en el host/puerto configurado.",
    12514: "El servicio Oracle indicado (DSN) no existe.",
    1017: "Usuario o contraseña de la base de datos incorrectos.",
}


def _traducir_error(exc: oracledb.DatabaseError) -> Exception:
    (error,) = exc.args
    codigo = getattr(error, "code", 0) or 0
    mensaje = getattr(error, "message", str(error))
    if 20000 <= codigo <= 20999:
        primera_linea = mensaje.splitlines()[0]
        texto = primera_linea.split(":", 1)[1].strip() if ":" in primera_linea else primera_linea
        return ErrorNegocio(texto)
    return ErrorBaseDatos(_MENSAJES_ORACLE.get(codigo, f"Error de base de datos: {mensaje.splitlines()[0]}"))


class BaseDatos:
    """Envoltura de una conexión python-oracledb (modo thin, sin Instant Client)."""

    def __init__(self) -> None:
        self._conexion: oracledb.Connection | None = None

    # ------------------------------------------------------------------ ciclo de vida
    def conectar(self) -> None:
        if self._conexion is not None:
            return
        try:
            self._conexion = oracledb.connect(
                user=CONFIG.usuario, password=CONFIG.contrasena, dsn=CONFIG.dsn
            )
        except oracledb.DatabaseError as exc:
            raise _traducir_error(exc) from exc

    def cerrar(self) -> None:
        if self._conexion is not None:
            try:
                self._conexion.close()
            finally:
                self._conexion = None

    def __enter__(self) -> "BaseDatos":
        self.conectar()
        return self

    def __exit__(self, *_: object) -> None:
        self.cerrar()

    @property
    def conexion(self) -> oracledb.Connection:
        if self._conexion is None:
            self.conectar()
        assert self._conexion is not None
        return self._conexion

    # ------------------------------------------------------------------ llamadas
    def ejecutar(
        self,
        procedimiento: str,
        entradas: Sequence[Any] = (),
        salidas: Sequence[type] = (),
        confirmar: bool = True,
    ) -> list[Any]:
        """Ejecuta un procedimiento con parámetros IN seguidos de OUT escalares.

        Devuelve la lista de valores OUT. Hace COMMIT si todo salió bien y
        ROLLBACK si la base de datos lanzó un error.
        """
        cursor = self.conexion.cursor()
        try:
            variables = [
                cursor.var(tipo, 4000) if tipo is str else cursor.var(tipo) for tipo in salidas
            ]
            cursor.callproc(procedimiento, [*entradas, *variables])
            if confirmar:
                self.conexion.commit()
            return [v.getvalue() for v in variables]
        except oracledb.DatabaseError as exc:
            self.conexion.rollback()
            raise _traducir_error(exc) from exc
        finally:
            cursor.close()

    def consultar(self, procedimiento: str, entradas: Sequence[Any] = ()) -> Resultado:
        """Ejecuta un procedimiento cuyo ÚLTIMO parámetro es OUT SYS_REFCURSOR."""
        cursor = self.conexion.cursor()
        try:
            ref = cursor.var(oracledb.DB_TYPE_CURSOR)
            cursor.callproc(procedimiento, [*entradas, ref])
            cursor_resultado = ref.getvalue()
            try:
                columnas = [d[0] for d in cursor_resultado.description]
                filas = cursor_resultado.fetchall()
            finally:
                cursor_resultado.close()
            return Resultado(columnas, filas)
        except oracledb.DatabaseError as exc:
            self.conexion.rollback()
            raise _traducir_error(exc) from exc
        finally:
            cursor.close()

    def funcion(self, nombre: str, tipo_retorno: type, entradas: Sequence[Any] = ()) -> Any:
        """Invoca una función almacenada y devuelve su valor."""
        cursor = self.conexion.cursor()
        try:
            return cursor.callfunc(nombre, tipo_retorno, list(entradas))
        except oracledb.DatabaseError as exc:
            raise _traducir_error(exc) from exc
        finally:
            cursor.close()


# Instancia compartida por toda la aplicación
bd = BaseDatos()
