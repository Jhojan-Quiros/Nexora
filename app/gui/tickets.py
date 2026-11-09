"""Pantalla de tickets (RF-04, RF-05, RF-06), adaptada al rol del usuario."""
from __future__ import annotations

import tkinter as tk
from tkinter import messagebox, ttk

from app.gui import estilos as e
from app.gui.componentes import Campo, Columna, Tabla, centrar, ejecutar, formatear, pedir, requiere_seleccion
from app.gui.secciones import Seccion
from app.servicios.catalogos import AsignacionEquipos, Empleados, Tecnicos
from app.servicios.soporte import Tickets

TODOS = "Todos"


class SeccionTickets(Seccion):
    """Modos: 'admin' (todo), 'tecnico' (mis tickets / sin asignar), 'empleado' (mis solicitudes)."""

    def __init__(self, padre: tk.Misc, sesion, modo: str) -> None:
        self.modo = modo
        self.titulo = {"admin": "Tickets de soporte", "tecnico": "Mis tickets",
                       "empleado": "Mis solicitudes de soporte"}[modo]
        self.subtitulo = {"admin": "Creación, asignación, seguimiento y cierre (RF-04 a RF-06)",
                          "tecnico": "Atienda sus tickets o tome uno de la cola",
                          "empleado": "Reporte un problema y siga su avance"}[modo]
        super().__init__(padre, sesion)

    # ------------------------------------------------------------------ construcción
    def construir(self) -> None:
        b = self.barra
        b.boton("+ Nuevo ticket", self.nuevo, "Primario.TButton")
        b.boton("Ver detalle", self.detalle)
        if self.modo == "admin":
            b.boton("Asignar técnico", self.asignar)
            b.boton("Asignación automática", self.automatico)
        if self.modo == "tecnico":
            b.boton("Tomar ticket", self.tomar)
        if self.modo in ("admin", "tecnico"):
            b.boton("Cambiar estado", self.cambiar_estado)
        b.boton("Editar", self.editar)
        if self.modo == "admin":
            b.boton("Eliminar", self.eliminar, "Peligro.TButton")

        filtros = ttk.Frame(self)
        filtros.pack(fill="x", pady=(0, 10))
        if self.modo == "tecnico":
            ttk.Label(filtros, text="Vista:").pack(side="left")
            self.f_vista = ttk.Combobox(filtros, state="readonly", width=18,
                                        values=["Asignados a mí", "Cola sin asignar"])
            self.f_vista.set("Asignados a mí")
            self.f_vista.pack(side="left", padx=(6, 14))
            self.f_vista.bind("<<ComboboxSelected>>", lambda _e: self.refrescar())
        self.f_estado = self._combo(filtros, "Estado:", Tickets.ESTADOS)
        self.f_prioridad = self._combo(filtros, "Prioridad:", Tickets.PRIORIDADES)
        self.sin_asignar = tk.BooleanVar(value=False)
        if self.modo == "admin":
            ttk.Checkbutton(filtros, text="Solo sin técnico", variable=self.sin_asignar,
                            command=self.refrescar).pack(side="left")
        ttk.Button(filtros, text="Actualizar", command=self.refrescar).pack(side="right")

        columnas = [
            Columna("ID_TICKET", "#", 50, "center"), Columna("TITULO", "Título", 220),
            Columna("CATEGORIA", "Categoría", 95), Columna("PRIORIDAD", "Prioridad", 85),
            Columna("ESTADO", "Estado", 105),
        ]
        if self.modo != "empleado":
            columnas.append(Columna("SOLICITANTE", "Solicitante", 160))
        columnas += [Columna("TECNICO", "Técnico", 160), Columna("FECHA_CREACION", "Creado", 120),
                     Columna("HORAS_RESOLUCION", "Horas", 70, "e")]
        self.tabla = Tabla(self, columnas, columna_color="ESTADO", al_doble_clic=self.detalle)
        self.tabla.pack(fill="both", expand=True)

    def _combo(self, padre: tk.Misc, texto: str, valores) -> ttk.Combobox:
        ttk.Label(padre, text=texto).pack(side="left")
        combo = ttk.Combobox(padre, values=[TODOS, *valores], state="readonly", width=13)
        combo.set(TODOS)
        combo.pack(side="left", padx=(6, 14))
        combo.bind("<<ComboboxSelected>>", lambda _e: self.refrescar())
        return combo

    @staticmethod
    def _valor(combo: ttk.Combobox) -> str | None:
        return None if combo.get() == TODOS else combo.get()

    # ------------------------------------------------------------------ datos
    def refrescar(self) -> None:
        estado, prioridad = self._valor(self.f_estado), self._valor(self.f_prioridad)
        id_tecnico = id_empleado = None
        sin_asignar = self.sin_asignar.get()
        if self.modo == "empleado":
            id_empleado = self.sesion.id_empleado
        elif self.modo == "tecnico":
            if self.f_vista.get() == "Cola sin asignar":
                sin_asignar = True
            else:
                id_tecnico = self.sesion.id_tecnico
        r = ejecutar(self, lambda: Tickets.filtrar(estado, prioridad, id_tecnico, id_empleado, sin_asignar))
        if r is not None:
            self.tabla.cargar(r, "No hay tickets con esos filtros.")

    def _seleccion(self) -> dict | None:
        fila = self.tabla.seleccionado()
        return fila if requiere_seleccion(self, fila, "un ticket") else None

    # ------------------------------------------------------------------ acciones
    def nuevo(self) -> None:
        id_empleado = self.sesion.id_empleado
        if self.modo == "admin":
            empleados = ejecutar(self, lambda: [(x["ID_EMPLEADO"], x["NOMBRE_COMPLETO"])
                                                for x in Empleados.listar(None, True).como_diccionarios()])
            if not empleados:
                return
            quien = pedir(self, "¿Para quién es el ticket?",
                          [Campo("empleado", "Empleado solicitante", "catalogo", empleados, id_empleado)], "Continuar")
            if not quien:
                return
            id_empleado = quien["empleado"]

        historial = ejecutar(self, lambda: AsignacionEquipos.historial_empleado(id_empleado))
        if historial is None:
            return
        equipos = [(q["ID_EQUIPO"], f"{q['EQUIPO']} ({q['NUMERO_SERIE']})")
                   for q in historial.como_diccionarios() if q["SITUACION"] == "VIGENTE"]
        d = pedir(self, "Nuevo ticket de soporte", [
            Campo("titulo", "Título"),
            Campo("descripcion", "Descripción del problema", "multilinea"),
            Campo("categoria", "Categoría", "opciones", Tickets.CATEGORIAS),
            Campo("prioridad", "Prioridad", "opciones", Tickets.PRIORIDADES, "MEDIA"),
            Campo("equipo", "Equipo afectado", "catalogo", equipos, obligatorio=False),
        ], "Crear ticket")
        if not d:
            return
        nuevo = ejecutar(self, lambda: Tickets.crear(id_empleado, d["equipo"], d["titulo"], d["descripcion"],
                                                     d["categoria"], d["prioridad"]))
        if nuevo is not None:
            messagebox.showinfo("Ticket creado", f"Se creó el ticket #{nuevo} en estado ABIERTO.", parent=self)
            self.refrescar()

    def detalle(self) -> None:
        fila = self._seleccion()
        if fila:
            DetalleTicket(self, fila["ID_TICKET"])

    def asignar(self) -> None:
        fila = self._seleccion()
        if not fila:
            return
        lista = ejecutar(self, lambda: Tecnicos.listar(True))
        if lista is None:
            return
        tecnicos = [(t["ID_TECNICO"], f"{t['NOMBRE_COMPLETO']} — {t['ESPECIALIDAD']} "
                                       f"({t['TICKETS_ACTIVOS']} activos)") for t in lista.como_diccionarios()]
        sugerido = ejecutar(self, Tecnicos.menor_carga)
        d = pedir(self, f"Asignar ticket #{fila['ID_TICKET']}", [
            Campo("tecnico", "Técnico (se sugiere el de menor carga)", "catalogo", tecnicos,
                  sugerido if sugerido is not True else None)], "Asignar")
        if d and ejecutar(self, lambda: Tickets.asignar_tecnico(fila["ID_TICKET"], d["tecnico"]),
                          "Ticket asignado; pasó a EN_PROCESO.") is not None:
            self.refrescar()

    def automatico(self) -> None:
        if not messagebox.askyesno("Asignación automática", "¿Repartir todos los tickets sin técnico según "
                                   "la prioridad y la carga de cada técnico?", parent=self):
            return
        total = ejecutar(self, Tickets.asignar_automatico)
        if total is not None:
            messagebox.showinfo("Listo", f"Se asignaron {total} ticket(s).", parent=self)
            self.refrescar()

    def tomar(self) -> None:
        fila = self._seleccion()
        if not fila:
            return
        if fila.get("TECNICO"):
            messagebox.showinfo("Ya asignado", "Ese ticket ya tiene técnico.", parent=self)
            return
        if ejecutar(self, lambda: Tickets.asignar_tecnico(fila["ID_TICKET"], self.sesion.id_tecnico),
                    f"El ticket #{fila['ID_TICKET']} ahora es suyo.") is not None:
            self.f_vista.set("Asignados a mí")
            self.refrescar()

    def cambiar_estado(self) -> None:
        fila = self._seleccion()
        if not fila:
            return
        detalle = ejecutar(self, lambda: Tickets.obtener(fila["ID_TICKET"]))
        if not detalle or detalle is True:
            return
        if self.modo == "tecnico" and detalle["ID_TECNICO"] != self.sesion.id_tecnico:
            messagebox.showwarning("No permitido", "Solo puede cambiar el estado de sus tickets.", parent=self)
            return
        d = pedir(self, f"Estado del ticket #{fila['ID_TICKET']} (actual: {detalle['ESTADO']})", [
            Campo("estado", "Nuevo estado", "opciones", Tickets.ESTADOS, detalle["ESTADO"])], "Cambiar")
        if d and ejecutar(self, lambda: Tickets.cambiar_estado(fila["ID_TICKET"], d["estado"]),
                          f"Ticket #{fila['ID_TICKET']} ahora está {d['estado']}.") is not None:
            self.refrescar()

    def editar(self) -> None:
        fila = self._seleccion()
        if not fila:
            return
        t = ejecutar(self, lambda: Tickets.obtener(fila["ID_TICKET"]))
        if not t or t is True:
            return
        if self.modo != "admin" and t["ID_EMPLEADO"] != self.sesion.id_empleado:
            messagebox.showwarning("No permitido", "Solo puede editar los tickets que usted creó.", parent=self)
            return
        d = pedir(self, f"Editar ticket #{t['ID_TICKET']}", [
            Campo("titulo", "Título", valor=t["TITULO"]),
            Campo("descripcion", "Descripción", "multilinea", valor=t["DESCRIPCION"]),
            Campo("categoria", "Categoría", "opciones", Tickets.CATEGORIAS, t["CATEGORIA"]),
            Campo("prioridad", "Prioridad", "opciones", Tickets.PRIORIDADES, t["PRIORIDAD"]),
        ])
        if d and ejecutar(self, lambda: Tickets.modificar(t["ID_TICKET"], d["titulo"], d["descripcion"],
                                                          d["categoria"], d["prioridad"]),
                          "Ticket actualizado.") is not None:
            self.refrescar()

    def eliminar(self) -> None:
        fila = self._seleccion()
        if fila and messagebox.askyesno("Eliminar", f"¿Eliminar el ticket #{fila['ID_TICKET']}?\n"
                                        "Solo se permite si está ABIERTO y sin técnico.", parent=self):
            if ejecutar(self, lambda: Tickets.eliminar(fila["ID_TICKET"]), "Ticket eliminado.") is not None:
                self.refrescar()


class DetalleTicket(tk.Toplevel):
    """Ficha completa del ticket con su bitácora de seguimiento."""

    CAMPOS = [("Estado", "ESTADO"), ("Prioridad", "PRIORIDAD"), ("Categoría", "CATEGORIA"),
              ("Solicitante", "SOLICITANTE"), ("Departamento", "DEPARTAMENTO"), ("Técnico", "TECNICO"),
              ("Equipo", "NUMERO_SERIE"), ("Creado", "FECHA_CREACION"), ("Cerrado", "FECHA_CIERRE"),
              ("Horas de resolución", "HORAS_RESOLUCION")]

    def __init__(self, padre: tk.Misc, id_ticket: int) -> None:
        datos = ejecutar(padre, lambda: Tickets.obtener(id_ticket))
        comentarios = ejecutar(padre, lambda: Tickets.comentarios(id_ticket))
        super().__init__(padre)
        self.title(f"Ticket #{id_ticket}")
        self.configure(bg=e.FONDO)
        self.transient(padre.winfo_toplevel())
        if not datos or datos is True:
            self.destroy()
            return

        marco = ttk.Frame(self, padding=22)
        marco.pack(fill="both", expand=True)
        ttk.Label(marco, text=f"#{id_ticket}  {datos['TITULO']}", style="Titulo.TLabel").pack(anchor="w")

        ficha = ttk.Frame(marco, style="Tarjeta.TFrame", padding=16)
        ficha.pack(fill="x", pady=12)
        for i, (texto, clave) in enumerate(self.CAMPOS):
            ttk.Label(ficha, text=texto, style="Campo.TLabel").grid(row=(i // 2) * 2, column=i % 2, sticky="w",
                                                                    padx=(0, 40))
            valor = formatear(datos.get(clave)) or "—"
            color = e.COLOR_ESTADO.get(str(datos.get(clave)), e.TEXTO)
            ttk.Label(ficha, text=valor, style="Tarjeta.TLabel", foreground=color).grid(
                row=(i // 2) * 2 + 1, column=i % 2, sticky="w", pady=(0, 8), padx=(0, 40))

        ttk.Label(marco, text="Descripción", font=("TkDefaultFont", 10, "bold")).pack(anchor="w")
        texto = tk.Text(marco, height=4, wrap="word", relief="flat", bg=e.BLANCO, padx=10, pady=8, font="TkDefaultFont")
        texto.insert("1.0", datos.get("DESCRIPCION") or "")
        texto.configure(state="disabled")
        texto.pack(fill="x", pady=(4, 12))

        ttk.Label(marco, text="Seguimiento", font=("TkDefaultFont", 10, "bold")).pack(anchor="w")
        tabla = Tabla(marco, [Columna("FECHA", "Fecha", 130), Columna("TECNICO", "Técnico", 170),
                              Columna("TEXTO", "Comentario", 380)])
        tabla.pack(fill="both", expand=True, pady=(4, 10))
        if comentarios is not None and comentarios is not True:
            tabla.cargar(comentarios, "Sin comentarios todavía.")
        ttk.Button(marco, text="Cerrar", command=self.destroy).pack(anchor="e")
        centrar(self, 760, 640)
