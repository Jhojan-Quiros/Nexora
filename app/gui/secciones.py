"""Secciones del administrador: panel, departamentos, empleados, técnicos, equipos y asignaciones."""
from __future__ import annotations

import tkinter as tk
from tkinter import messagebox, ttk

from app.gui import estilos as e
from app.gui.componentes import (BarraBotones, Campo, Columna, Encabezado, Kpi, Tabla, ejecutar,
                                 pedir, requiere_seleccion)
from app.servicios.catalogos import AsignacionEquipos, Departamentos, Empleados, Equipos, Tecnicos
from app.servicios.soporte import Panel, Sesion


class Seccion(ttk.Frame):
    """Base de todas las pantallas: encabezado, barra de botones y contenido."""

    titulo = ""
    subtitulo = ""

    def __init__(self, padre: tk.Misc, sesion: Sesion) -> None:
        super().__init__(padre, padding=(28, 22))
        self.sesion = sesion
        Encabezado(self, self.titulo, self.subtitulo).pack(fill="x", pady=(0, 16))
        self.barra = BarraBotones(self)
        self.barra.pack(fill="x", pady=(0, 10))
        self.construir()
        self.refrescar()

    def construir(self) -> None:  # pragma: no cover - lo implementan las subclases
        raise NotImplementedError

    def refrescar(self) -> None:
        pass


def _catalogo_departamentos() -> list[tuple[int, str]]:
    return [(d["ID_DEPARTAMENTO"], d["NOMBRE"]) for d in Departamentos.listar(True).como_diccionarios()]


def _catalogo_empleados() -> list[tuple[int, str]]:
    return [(x["ID_EMPLEADO"], f"{x['NOMBRE_COMPLETO']} — {x['DEPARTAMENTO']}")
            for x in Empleados.listar(None, True).como_diccionarios()]


# ======================================================================= PANEL
class SeccionPanel(Seccion):
    titulo = "Panel de soporte TI"
    subtitulo = "Resumen en tiempo real de tickets, equipos y licencias"

    def construir(self) -> None:
        self.barra.boton("Actualizar", self.refrescar)
        rejilla = ttk.Frame(self)
        rejilla.pack(fill="x")
        definiciones = [
            ("abiertos", "Tickets abiertos", e.AZUL),
            ("sin_asignar", "Sin técnico asignado", e.MORADO),
            ("en_proceso", "En proceso", e.AMBAR),
            ("criticos", "Pendientes críticos", e.ROJO),
            ("promedio_horas", "Horas promedio de resolución", e.VERDE),
            ("equipos_disponibles", "Equipos disponibles", e.AZUL),
            ("licencias_por_vencer", "Licencias por vencer (30 días)", e.ROJO),
        ]
        self.kpis: dict[str, Kpi] = {}
        for i, (clave, texto, color) in enumerate(definiciones):
            tarjeta = Kpi(rejilla, texto, color)
            tarjeta.grid(row=i // 4, column=i % 4, sticky="nsew", padx=(0, 12), pady=(0, 12))
            self.kpis[clave] = tarjeta
        for c in range(4):
            rejilla.columnconfigure(c, weight=1, uniform="kpi")

        ttk.Label(self, text="Carga de trabajo por técnico", font=("TkDefaultFont", 11, "bold")).pack(
            anchor="w", pady=(8, 6))
        self.tabla = Tabla(self, [
            Columna("TECNICO", "Técnico", 220), Columna("ESPECIALIDAD", "Especialidad", 170),
            Columna("NIVEL", "Nivel", 90), Columna("TOTAL", "Total", 70, "center"),
            Columna("EN_PROCESO", "En proceso", 90, "center"),
            Columna("RESUELTOS", "Resueltos", 90, "center"), Columna("CERRADOS", "Cerrados", 90, "center"),
            Columna("PROMEDIO_HORAS", "Prom. horas", 100, "e"),
        ])
        self.tabla.pack(fill="both", expand=True)

    def refrescar(self) -> None:
        datos = ejecutar(self, Panel.resumen)
        if datos is None:
            return
        for clave, tarjeta in self.kpis.items():
            tarjeta.poner(datos.get(clave))
        resultado = ejecutar(self, Panel.tickets_por_tecnico)
        if resultado is not None:
            self.tabla.cargar(resultado)


# ======================================================================= DEPARTAMENTOS
class SeccionDepartamentos(Seccion):
    titulo = "Departamentos"
    subtitulo = "Registrar, modificar, desactivar y eliminar departamentos (RF-01)"

    def construir(self) -> None:
        self.barra.boton("+ Nuevo", self.nuevo, "Primario.TButton")
        self.barra.boton("Editar", self.editar)
        self.barra.boton("Activar / desactivar", self.alternar)
        self.barra.boton("Eliminar", self.eliminar, "Peligro.TButton")
        self.barra.boton("Actualizar", self.refrescar, derecha=True)
        self.tabla = Tabla(self, [
            Columna("ID_DEPARTAMENTO", "ID", 60, "center"), Columna("NOMBRE", "Nombre", 260),
            Columna("UBICACION", "Ubicación", 240), Columna("EMPLEADOS_ACTIVOS", "Empleados", 100, "center"),
            Columna("ACTIVO", "Activo", 80, "center"),
        ], columna_color="ACTIVO", al_doble_clic=self.editar)
        self.tabla.pack(fill="both", expand=True)

    def refrescar(self) -> None:
        r = ejecutar(self, Departamentos.listar)
        if r is not None:
            self.tabla.cargar(r)

    def nuevo(self) -> None:
        datos = pedir(self, "Nuevo departamento", [Campo("nombre", "Nombre"), Campo("ubicacion", "Ubicación")])
        if datos and ejecutar(self, lambda: Departamentos.registrar(datos["nombre"], datos["ubicacion"]),
                              "Departamento registrado.") is not None:
            self.refrescar()

    def editar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un departamento"):
            return
        datos = pedir(self, "Editar departamento", [
            Campo("nombre", "Nombre", valor=fila["NOMBRE"]),
            Campo("ubicacion", "Ubicación", valor=fila["UBICACION"]),
        ])
        if datos and ejecutar(self, lambda: Departamentos.modificar(
                fila["ID_DEPARTAMENTO"], datos["nombre"], datos["ubicacion"]), "Departamento actualizado.") is not None:
            self.refrescar()

    def alternar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un departamento"):
            return
        if fila["ACTIVO"] == "S":
            accion, mensaje = (lambda: Departamentos.desactivar(fila["ID_DEPARTAMENTO"])), "Departamento desactivado."
        else:
            accion, mensaje = (lambda: Departamentos.activar(fila["ID_DEPARTAMENTO"])), "Departamento activado."
        if ejecutar(self, accion, mensaje) is not None:
            self.refrescar()

    def eliminar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un departamento"):
            return
        if messagebox.askyesno("Eliminar", f"¿Eliminar definitivamente «{fila['NOMBRE']}»?", parent=self):
            if ejecutar(self, lambda: Departamentos.eliminar(fila["ID_DEPARTAMENTO"]),
                        "Departamento eliminado.") is not None:
                self.refrescar()


# ======================================================================= EMPLEADOS
class SeccionEmpleados(Seccion):
    titulo = "Empleados"
    subtitulo = "Colaboradores y usuarios del sistema (RF-01)"

    def construir(self) -> None:
        self.barra.boton("+ Nuevo", self.nuevo, "Primario.TButton")
        self.barra.boton("Editar", self.editar)
        self.barra.boton("Activar / desactivar", self.alternar)
        self.barra.boton("Restablecer contraseña", self.contrasena)
        self.barra.boton("Equipos asignados", self.equipos)
        self.barra.boton("Eliminar", self.eliminar, "Peligro.TButton")

        filtros = ttk.Frame(self)
        filtros.pack(fill="x", pady=(0, 10))
        ttk.Label(filtros, text="Buscar:").pack(side="left")
        self.texto = tk.StringVar()
        entrada = ttk.Entry(filtros, textvariable=self.texto, width=32)
        entrada.pack(side="left", padx=(6, 12))
        entrada.bind("<Return>", lambda _e: self.refrescar())
        self.solo_activos = tk.BooleanVar(value=False)
        ttk.Checkbutton(filtros, text="Solo activos", variable=self.solo_activos,
                        command=self.refrescar).pack(side="left")
        ttk.Button(filtros, text="Buscar", command=self.refrescar).pack(side="left", padx=8)

        self.tabla = Tabla(self, [
            Columna("ID_EMPLEADO", "ID", 55, "center"), Columna("NOMBRE_COMPLETO", "Nombre", 220),
            Columna("CORREO", "Correo", 200), Columna("USUARIO", "Usuario", 100),
            Columna("ROL", "Rol", 90), Columna("DEPARTAMENTO", "Departamento", 180),
            Columna("ACTIVO", "Activo", 65, "center"),
        ], columna_color="ACTIVO", al_doble_clic=self.editar)
        self.tabla.pack(fill="both", expand=True)

    def refrescar(self) -> None:
        texto = self.texto.get().strip() if hasattr(self, "texto") else ""
        if texto:
            r = ejecutar(self, lambda: Empleados.buscar(texto))
        else:
            r = ejecutar(self, lambda: Empleados.listar(None, self.solo_activos.get()))
        if r is not None:
            self.tabla.cargar(r)

    def nuevo(self) -> None:
        deptos = ejecutar(self, _catalogo_departamentos)
        if not deptos:
            return
        datos = pedir(self, "Nuevo empleado", [
            Campo("depto", "Departamento", "catalogo", deptos),
            Campo("nombre", "Nombre completo"),
            Campo("correo", "Correo institucional"),
            Campo("usuario", "Usuario"),
            Campo("contrasena", "Contraseña inicial (8+ caracteres, letras y números)", "contrasena"),
            Campo("rol", "Rol", "opciones", Empleados.ROLES, "EMPLEADO"),
        ])
        if datos and ejecutar(self, lambda: Empleados.registrar(
                datos["depto"], datos["nombre"], datos["correo"], datos["usuario"],
                datos["contrasena"], datos["rol"]), "Empleado registrado.") is not None:
            if datos["rol"] == "TECNICO":
                messagebox.showinfo("Recuerde", "Regístrelo también en «Técnicos» para que pueda recibir tickets.",
                                    parent=self)
            self.refrescar()

    def editar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un empleado"):
            return
        actual = ejecutar(self, lambda: Empleados.obtener(fila["ID_EMPLEADO"]))
        deptos = ejecutar(self, _catalogo_departamentos)
        if not actual or not deptos:
            return
        datos = pedir(self, "Editar empleado", [
            Campo("depto", "Departamento", "catalogo", deptos, actual["ID_DEPARTAMENTO"]),
            Campo("nombre", "Nombre completo", valor=actual["NOMBRE_COMPLETO"]),
            Campo("correo", "Correo institucional", valor=actual["CORREO"]),
            Campo("rol", "Rol", "opciones", Empleados.ROLES, actual["ROL"]),
        ])
        if datos and ejecutar(self, lambda: Empleados.modificar(
                fila["ID_EMPLEADO"], datos["depto"], datos["nombre"], datos["correo"], datos["rol"]),
                "Empleado actualizado.") is not None:
            self.refrescar()

    def alternar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un empleado"):
            return
        if fila["ACTIVO"] == "S":
            if fila["ID_EMPLEADO"] == self.sesion.id_empleado:
                messagebox.showwarning("No permitido", "No puede desactivar su propio usuario.", parent=self)
                return
            if not messagebox.askyesno("Desactivar", "Se registrará la devolución de sus equipos y se liberarán "
                                       "sus licencias. ¿Continuar?", parent=self):
                return
            ok = ejecutar(self, lambda: Empleados.desactivar(fila["ID_EMPLEADO"]), "Empleado desactivado.")
        else:
            ok = ejecutar(self, lambda: Empleados.activar(fila["ID_EMPLEADO"]), "Empleado activado.")
        if ok is not None:
            self.refrescar()

    def contrasena(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un empleado"):
            return
        datos = pedir(self, f"Contraseña de {fila['USUARIO']}",
                      [Campo("nueva", "Nueva contraseña", "contrasena")], "Restablecer")
        if datos:
            ejecutar(self, lambda: Empleados.restablecer_contrasena(fila["ID_EMPLEADO"], datos["nueva"]),
                     "Contraseña restablecida.")

    def equipos(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un empleado"):
            return
        r = ejecutar(self, lambda: AsignacionEquipos.historial_empleado(fila["ID_EMPLEADO"]))
        if r is not None:
            VentanaTabla(self, f"Equipos de {fila['NOMBRE_COMPLETO']}", r, [
                Columna("EQUIPO", "Equipo", 200), Columna("NUMERO_SERIE", "Serie", 130),
                Columna("FECHA_INICIO", "Desde", 110), Columna("FECHA_FIN", "Hasta", 110),
                Columna("SITUACION", "Situación", 100)])

    def eliminar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un empleado"):
            return
        if messagebox.askyesno("Eliminar", f"¿Eliminar definitivamente a {fila['NOMBRE_COMPLETO']}?\n"
                               "Solo es posible si no tiene historial.", parent=self):
            if ejecutar(self, lambda: Empleados.eliminar(fila["ID_EMPLEADO"]), "Empleado eliminado.") is not None:
                self.refrescar()


# ======================================================================= TÉCNICOS
class SeccionTecnicos(Seccion):
    titulo = "Técnicos"
    subtitulo = "Personal de TI que atiende los tickets"

    def construir(self) -> None:
        self.barra.boton("+ Nuevo", self.nuevo, "Primario.TButton")
        self.barra.boton("Editar", self.editar)
        self.barra.boton("Activar / desactivar", self.alternar)
        self.barra.boton("Actualizar", self.refrescar, derecha=True)
        self.tabla = Tabla(self, [
            Columna("ID_TECNICO", "ID", 55, "center"), Columna("NOMBRE_COMPLETO", "Nombre", 230),
            Columna("CORREO", "Correo", 200), Columna("ESPECIALIDAD", "Especialidad", 180),
            Columna("NIVEL", "Nivel", 100), Columna("TICKETS_ACTIVOS", "Tickets activos", 110, "center"),
            Columna("ACTIVO", "Activo", 65, "center"),
        ], columna_color="ACTIVO", al_doble_clic=self.editar)
        self.tabla.pack(fill="both", expand=True)

    def refrescar(self) -> None:
        r = ejecutar(self, Tecnicos.listar)
        if r is not None:
            self.tabla.cargar(r)

    def nuevo(self) -> None:
        empleados = ejecutar(self, _catalogo_empleados)
        if not empleados:
            return
        datos = pedir(self, "Nuevo técnico", [
            Campo("empleado", "Empleado", "catalogo", empleados),
            Campo("especialidad", "Especialidad"),
            Campo("nivel", "Nivel", "opciones", Tecnicos.NIVELES, "JUNIOR"),
        ])
        if datos and ejecutar(self, lambda: Tecnicos.registrar(
                datos["empleado"], datos["especialidad"], datos["nivel"]), "Técnico registrado.") is not None:
            self.refrescar()

    def editar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un técnico"):
            return
        datos = pedir(self, "Editar técnico", [
            Campo("especialidad", "Especialidad", valor=fila["ESPECIALIDAD"]),
            Campo("nivel", "Nivel", "opciones", Tecnicos.NIVELES, fila["NIVEL"]),
        ])
        if datos and ejecutar(self, lambda: Tecnicos.modificar(
                fila["ID_TECNICO"], datos["especialidad"], datos["nivel"]), "Técnico actualizado.") is not None:
            self.refrescar()

    def alternar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un técnico"):
            return
        if fila["ACTIVO"] == "S":
            if not messagebox.askyesno("Desactivar", "Sus tickets pendientes volverán a la cola sin asignar. "
                                       "¿Continuar?", parent=self):
                return
            total = ejecutar(self, lambda: Tecnicos.desactivar(fila["ID_TECNICO"]))
            if total is not None:
                messagebox.showinfo("Listo", f"Técnico desactivado. {total} ticket(s) devueltos a la cola.", parent=self)
                self.refrescar()
        elif ejecutar(self, lambda: Tecnicos.activar(fila["ID_TECNICO"]), "Técnico activado.") is not None:
            self.refrescar()


# ======================================================================= EQUIPOS
class SeccionEquipos(Seccion):
    titulo = "Equipos"
    subtitulo = "Inventario de equipos de cómputo y red (RF-02)"

    def construir(self) -> None:
        self.barra.boton("+ Nuevo", self.nuevo, "Primario.TButton")
        self.barra.boton("Editar", self.editar)
        self.barra.boton("Disponible / reparación", self.estado)
        self.barra.boton("Historial", self.historial)
        self.barra.boton("Dar de baja", self.baja, "Peligro.TButton")
        self.barra.boton("Eliminar", self.eliminar, "Peligro.TButton")

        filtros = ttk.Frame(self)
        filtros.pack(fill="x", pady=(0, 10))
        ttk.Label(filtros, text="Estado:").pack(side="left")
        self.f_estado = ttk.Combobox(filtros, values=["Todos", *Equipos.ESTADOS], state="readonly", width=14)
        self.f_estado.set("Todos")
        self.f_estado.pack(side="left", padx=(6, 14))
        ttk.Label(filtros, text="Tipo:").pack(side="left")
        self.f_tipo = ttk.Combobox(filtros, values=["Todos", *Equipos.TIPOS], state="readonly", width=14)
        self.f_tipo.set("Todos")
        self.f_tipo.pack(side="left", padx=(6, 14))
        for combo in (self.f_estado, self.f_tipo):
            combo.bind("<<ComboboxSelected>>", lambda _e: self.refrescar())
        self.resumen = ttk.Label(filtros, text="", style="Subtitulo.TLabel")
        self.resumen.pack(side="right")

        self.tabla = Tabla(self, [
            Columna("ID_EQUIPO", "ID", 55, "center"), Columna("TIPO", "Tipo", 100),
            Columna("MARCA", "Marca", 100), Columna("MODELO", "Modelo", 160),
            Columna("NUMERO_SERIE", "N.º serie", 130), Columna("ESTADO", "Estado", 110),
            Columna("FECHA_COMPRA", "Compra", 100), Columna("ASIGNADO_A", "Asignado a", 200),
        ], columna_color="ESTADO", al_doble_clic=self.editar)
        self.tabla.pack(fill="both", expand=True)

    @staticmethod
    def _valor(combo: ttk.Combobox) -> str | None:
        return None if combo.get() == "Todos" else combo.get()

    def refrescar(self) -> None:
        r = ejecutar(self, lambda: Equipos.listar(self._valor(self.f_estado), self._valor(self.f_tipo)))
        if r is not None:
            self.tabla.cargar(r)
        texto = ejecutar(self, Equipos.resumen_inventario)
        if texto:
            self.resumen.configure(text=f"Inventario → {texto}")

    def _campos(self, fila: dict | None = None) -> list[Campo]:
        fila = fila or {}
        fecha = fila.get("FECHA_COMPRA")
        return [
            Campo("tipo", "Tipo", "opciones", Equipos.TIPOS, fila.get("TIPO", "LAPTOP")),
            Campo("marca", "Marca", valor=fila.get("MARCA")),
            Campo("modelo", "Modelo", valor=fila.get("MODELO")),
            Campo("serie", "Número de serie", valor=fila.get("NUMERO_SERIE")),
            Campo("fecha", "Fecha de compra (dd/mm/aaaa)", "fecha", valor=fecha.date() if fecha else None),
        ]

    def nuevo(self) -> None:
        d = pedir(self, "Nuevo equipo", self._campos())
        if d and ejecutar(self, lambda: Equipos.registrar(d["tipo"], d["marca"], d["modelo"], d["serie"], d["fecha"]),
                          "Equipo registrado como DISPONIBLE.") is not None:
            self.refrescar()

    def editar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un equipo"):
            return
        d = pedir(self, "Editar equipo", self._campos(fila))
        if d and ejecutar(self, lambda: Equipos.modificar(fila["ID_EQUIPO"], d["tipo"], d["marca"], d["modelo"],
                                                          d["serie"], d["fecha"]), "Equipo actualizado.") is not None:
            self.refrescar()

    def estado(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un equipo"):
            return
        d = pedir(self, "Cambiar estado", [
            Campo("estado", "Nuevo estado", "opciones", ("DISPONIBLE", "REPARACION"), fila["ESTADO"])], "Cambiar")
        if d and ejecutar(self, lambda: Equipos.cambiar_estado(fila["ID_EQUIPO"], d["estado"]),
                          "Estado actualizado.") is not None:
            self.refrescar()

    def historial(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un equipo"):
            return
        r = ejecutar(self, lambda: AsignacionEquipos.historial_equipo(fila["ID_EQUIPO"]))
        if r is not None:
            VentanaTabla(self, f"Historial del equipo {fila['NUMERO_SERIE']}", r, [
                Columna("EMPLEADO", "Empleado", 220), Columna("FECHA_INICIO", "Desde", 110),
                Columna("FECHA_FIN", "Hasta", 110), Columna("SITUACION", "Situación", 100),
                Columna("DIAS", "Días", 70, "center")])

    def baja(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un equipo"):
            return
        if messagebox.askyesno("Dar de baja", f"La baja de {fila['NUMERO_SERIE']} es definitiva. ¿Continuar?",
                               parent=self):
            if ejecutar(self, lambda: Equipos.dar_baja(fila["ID_EQUIPO"]), "Equipo dado de baja.") is not None:
                self.refrescar()

    def eliminar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "un equipo"):
            return
        if messagebox.askyesno("Eliminar", "Solo se puede eliminar un equipo sin historial. ¿Continuar?", parent=self):
            if ejecutar(self, lambda: Equipos.eliminar(fila["ID_EQUIPO"]), "Equipo eliminado.") is not None:
                self.refrescar()


# ======================================================================= ASIGNACIONES
class SeccionAsignaciones(Seccion):
    titulo = "Asignación de equipos"
    subtitulo = "Entrega, traspaso y devolución con historial (RF-03)"

    def construir(self) -> None:
        self.barra.boton("+ Asignar equipo", self.asignar, "Primario.TButton")
        self.barra.boton("Traspasar a otro empleado", self.traspasar)
        self.barra.boton("Registrar devolución", self.devolver)
        self.barra.boton("Actualizar", self.refrescar, derecha=True)
        self.tabla = Tabla(self, [
            Columna("ID_EQUIPO", "ID equipo", 75, "center"), Columna("TIPO", "Tipo", 100),
            Columna("EQUIPO", "Equipo", 200), Columna("NUMERO_SERIE", "N.º serie", 130),
            Columna("EMPLEADO", "Empleado", 200), Columna("DEPARTAMENTO", "Departamento", 170),
            Columna("FECHA_INICIO", "Desde", 100), Columna("DIAS_ASIGNADO", "Días", 60, "center"),
        ])
        self.tabla.pack(fill="both", expand=True)

    def refrescar(self) -> None:
        r = ejecutar(self, AsignacionEquipos.activas)
        if r is not None:
            self.tabla.cargar(r, "No hay equipos asignados.")

    def _elegir_empleado(self, titulo: str, equipos: list[tuple[int, str]] | None = None) -> dict | None:
        empleados = ejecutar(self, _catalogo_empleados)
        if not empleados:
            return None
        campos = [Campo("empleado", "Empleado que recibe", "catalogo", empleados)]
        if equipos is not None:
            campos.insert(0, Campo("equipo", "Equipo disponible", "catalogo", equipos))
        return pedir(self, titulo, campos, "Asignar")

    def asignar(self) -> None:
        disponibles = ejecutar(self, lambda: Equipos.listar("DISPONIBLE"))
        if disponibles is None:
            return
        equipos = [(q["ID_EQUIPO"], f"{q['TIPO']} {q['MARCA']} {q['MODELO']} ({q['NUMERO_SERIE']})")
                   for q in disponibles.como_diccionarios()]
        if not equipos:
            messagebox.showinfo("Sin equipos", "No hay equipos disponibles para asignar.", parent=self)
            return
        d = self._elegir_empleado("Asignar equipo", equipos)
        if d and ejecutar(self, lambda: AsignacionEquipos.asignar(d["equipo"], d["empleado"]),
                          "Equipo asignado.") is not None:
            self.refrescar()

    def traspasar(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "una asignación"):
            return
        d = self._elegir_empleado(f"Traspasar {fila['NUMERO_SERIE']}")
        if d and ejecutar(self, lambda: AsignacionEquipos.asignar(fila["ID_EQUIPO"], d["empleado"]),
                          "Traspaso registrado en el historial.") is not None:
            self.refrescar()

    def devolver(self) -> None:
        fila = self.tabla.seleccionado()
        if not requiere_seleccion(self, fila, "una asignación"):
            return
        if messagebox.askyesno("Devolución", f"¿Registrar la devolución de {fila['EQUIPO']} por "
                               f"{fila['EMPLEADO']}?", parent=self):
            if ejecutar(self, lambda: AsignacionEquipos.devolver(fila["ID_EQUIPO"]),
                        "Devolución registrada; el equipo quedó DISPONIBLE.") is not None:
                self.refrescar()


# ======================================================================= VENTANA AUXILIAR
class VentanaTabla(tk.Toplevel):
    """Ventana emergente de solo lectura con una tabla."""

    def __init__(self, padre: tk.Misc, titulo: str, resultado, columnas: list[Columna]) -> None:
        super().__init__(padre)
        self.title(titulo)
        self.configure(bg=e.FONDO)
        self.transient(padre.winfo_toplevel())
        marco = ttk.Frame(self, padding=18)
        marco.pack(fill="both", expand=True)
        ttk.Label(marco, text=titulo, font=("TkDefaultFont", 12, "bold")).pack(anchor="w", pady=(0, 10))
        tabla = Tabla(marco, columnas)
        tabla.pack(fill="both", expand=True)
        tabla.cargar(resultado)
        ttk.Button(marco, text="Cerrar", command=self.destroy).pack(anchor="e", pady=(10, 0))
        self.geometry("760x380")
