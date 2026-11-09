"""Ventana principal: inicio de sesión, menú lateral por rol y área de contenido."""
from __future__ import annotations

import tkinter as tk
from tkinter import messagebox, ttk

from app.db.conexion import ErrorBaseDatos, ErrorNegocio, bd
from app.gui import estilos as e
from app.gui.componentes import Campo, centrar, ejecutar, pedir
from app.gui.secciones import (SeccionAsignaciones, SeccionDepartamentos, SeccionEmpleados, SeccionEquipos,
                               SeccionPanel, SeccionTecnicos)
from app.gui.tickets import SeccionTickets
from app.servicios.soporte import Seguridad, Sesion


NOMBRE_ROL = {"ADMIN": "Administrador", "TECNICO": "Técnico", "EMPLEADO": "Empleado"}


# ======================================================================= LOGIN
class PantallaLogin(tk.Frame):
    def __init__(self, raiz: "Aplicacion") -> None:
        super().__init__(raiz, bg=e.AZUL_OSCURO)
        self.raiz = raiz

        tarjeta = tk.Frame(self, bg=e.BLANCO, padx=44, pady=40)
        tarjeta.place(relx=0.5, rely=0.5, anchor="center")

        tk.Label(tarjeta, text="Nexora", bg=e.BLANCO, fg=e.AZUL, font=(raiz.familia, 26, "bold")).pack()
        tk.Label(tarjeta, text="Soporte TI y Activos", bg=e.BLANCO, fg=e.MORADO,
                 font=(raiz.familia, 12)).pack(pady=(0, 26))

        self.usuario = tk.StringVar()
        self.contrasena = tk.StringVar()
        for texto, variable, oculto in (("Usuario", self.usuario, False), ("Contraseña", self.contrasena, True)):
            ttk.Label(tarjeta, text=texto, style="Campo.TLabel").pack(anchor="w")
            entrada = ttk.Entry(tarjeta, textvariable=variable, width=32, show="•" if oculto else "")
            entrada.pack(fill="x", pady=(2, 14), ipady=3)
            entrada.bind("<Return>", lambda _e: self.ingresar())
            if not oculto:
                entrada.focus_set()

        self.boton = ttk.Button(tarjeta, text="Iniciar sesión", style="Primario.TButton", command=self.ingresar)
        self.boton.pack(fill="x", pady=(6, 0), ipady=4)
        self.mensaje = tk.Label(tarjeta, text="", bg=e.BLANCO, fg=e.ROJO, wraplength=280)
        self.mensaje.pack(pady=(12, 0))

    def ingresar(self) -> None:
        usuario, contrasena = self.usuario.get().strip(), self.contrasena.get()
        if not usuario or not contrasena:
            self.mensaje.configure(text="Escriba su usuario y contraseña.")
            return
        self.boton.state(["disabled"])
        self.update_idletasks()
        try:
            sesion = Seguridad.iniciar_sesion(usuario, contrasena)
        except (ErrorNegocio, ErrorBaseDatos) as exc:
            self.mensaje.configure(text=str(exc))
            self.contrasena.set("")
            return
        finally:
            self.boton.state(["!disabled"])
        self.raiz.abrir_sesion(sesion)


# ======================================================================= PRINCIPAL
class PantallaPrincipal(tk.Frame):
    def __init__(self, raiz: "Aplicacion", sesion: Sesion) -> None:
        super().__init__(raiz, bg=e.FONDO)
        self.raiz = raiz
        self.sesion = sesion
        self.actual: tk.Widget | None = None
        self.botones: dict[str, tk.Label] = {}

        lateral = tk.Frame(self, bg=e.AZUL_OSCURO, width=230)
        lateral.pack(side="left", fill="y")
        lateral.pack_propagate(False)
        tk.Label(lateral, text="Nexora", bg=e.AZUL_OSCURO, fg=e.BLANCO,
                 font=(raiz.familia, 18, "bold")).pack(anchor="w", padx=22, pady=(22, 0))
        tk.Label(lateral, text="Soporte TI y Activos", bg=e.AZUL_OSCURO, fg="#B9C0E8",
                 font=(raiz.familia, 9)).pack(anchor="w", padx=22, pady=(0, 22))

        self.opciones = self._opciones_por_rol()
        for nombre, _ in self.opciones:
            boton = tk.Label(lateral, text=f"   {nombre}", anchor="w", bg=e.AZUL_OSCURO, fg="#DDE1F5",
                             font=(raiz.familia, 10), padx=12, pady=10, cursor="hand2")
            boton.pack(fill="x")
            boton.bind("<Button-1>", lambda _e, n=nombre: self.mostrar(n))
            boton.bind("<Enter>", lambda _e, b=boton, n=nombre: self._hover(b, n, True))
            boton.bind("<Leave>", lambda _e, b=boton, n=nombre: self._hover(b, n, False))
            self.botones[nombre] = boton

        pie = tk.Frame(lateral, bg=e.AZUL_OSCURO)
        pie.pack(side="bottom", fill="x", padx=22, pady=18)
        tk.Label(pie, text=sesion.nombre, bg=e.AZUL_OSCURO, fg=e.BLANCO, font=(raiz.familia, 10, "bold"),
                 anchor="w", wraplength=190, justify="left").pack(anchor="w")
        tk.Label(pie, text=f"{NOMBRE_ROL.get(sesion.rol, 'Empleado')} · {sesion.departamento}", bg=e.AZUL_OSCURO, fg="#B9C0E8",
                 font=(raiz.familia, 9), anchor="w", wraplength=190, justify="left").pack(anchor="w", pady=(0, 10))
        for texto, comando in (("Cambiar contraseña", self.cambiar_contrasena), ("Cerrar sesión", raiz.cerrar_sesion)):
            enlace = tk.Label(pie, text=texto, bg=e.AZUL_OSCURO, fg="#9FB0FF", cursor="hand2",
                              font=(raiz.familia, 9, "underline"))
            enlace.pack(anchor="w", pady=1)
            enlace.bind("<Button-1>", lambda _e, c=comando: c())

        self.contenido = tk.Frame(self, bg=e.FONDO)
        self.contenido.pack(side="left", fill="both", expand=True)
        self.mostrar(self.opciones[0][0])

    def _opciones_por_rol(self):
        s = self.sesion
        if s.es_admin:
            return [
                ("Panel resumen", lambda p: SeccionPanel(p, s)),
                ("Tickets", lambda p: SeccionTickets(p, s, "admin")),
                ("Empleados", lambda p: SeccionEmpleados(p, s)),
                ("Departamentos", lambda p: SeccionDepartamentos(p, s)),
                ("Técnicos", lambda p: SeccionTecnicos(p, s)),
                ("Equipos", lambda p: SeccionEquipos(p, s)),
                ("Asignación de equipos", lambda p: SeccionAsignaciones(p, s)),
            ]
        if s.es_tecnico:
            return [("Mis tickets", lambda p: SeccionTickets(p, s, "tecnico"))]
        return [("Mis solicitudes", lambda p: SeccionTickets(p, s, "empleado"))]

    def _hover(self, boton: tk.Label, nombre: str, dentro: bool) -> None:
        if nombre != getattr(self, "_activo", None):
            boton.configure(bg=e.AZUL if dentro else e.AZUL_OSCURO)

    def mostrar(self, nombre: str) -> None:
        if self.actual is not None:
            self.actual.destroy()
        self._activo = nombre
        for n, b in self.botones.items():
            b.configure(bg=e.MORADO if n == nombre else e.AZUL_OSCURO,
                        fg=e.BLANCO if n == nombre else "#DDE1F5")
        fabrica = dict(self.opciones)[nombre]
        self.actual = fabrica(self.contenido)
        self.actual.pack(fill="both", expand=True)

    def cambiar_contrasena(self) -> None:
        d = pedir(self, "Cambiar mi contraseña", [
            Campo("actual", "Contraseña actual", "contrasena"),
            Campo("nueva", "Nueva contraseña (8+ caracteres, letras y números)", "contrasena"),
            Campo("repetir", "Repita la nueva contraseña", "contrasena"),
        ], "Cambiar")
        if not d:
            return
        if d["nueva"] != d["repetir"]:
            messagebox.showwarning("Revise", "Las contraseñas nuevas no coinciden.", parent=self)
            return
        ejecutar(self, lambda: Seguridad.cambiar_contrasena(self.sesion.id_empleado, d["actual"], d["nueva"]),
                 "Contraseña actualizada.")


# ======================================================================= APLICACIÓN
class Aplicacion(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Nexora Technologies — Soporte TI y Activos")
        self.familia = e.aplicar_tema(self)
        self.minsize(1100, 640)
        centrar(self, 1280, 760)
        self.pantalla: tk.Widget | None = None
        self.protocol("WM_DELETE_WINDOW", self.salir)
        self.conectado = False

        try:
            bd.conectar()
        except (ErrorBaseDatos, ErrorNegocio) as exc:
            self.withdraw()
            messagebox.showerror("Sin conexión a Oracle",
                                 f"{exc}\n\nRevise el archivo .env (usuario, contraseña y NEXORA_DB_DSN).")
            self.destroy()
            return
        self.conectado = True
        self._cambiar(PantallaLogin(self))

    def _cambiar(self, pantalla: tk.Widget) -> None:
        if self.pantalla is not None:
            self.pantalla.destroy()
        self.pantalla = pantalla
        pantalla.pack(fill="both", expand=True)

    def abrir_sesion(self, sesion: Sesion) -> None:
        self._cambiar(PantallaPrincipal(self, sesion))

    def cerrar_sesion(self) -> None:
        if messagebox.askyesno("Cerrar sesión", "¿Desea cerrar la sesión?", parent=self):
            self._cambiar(PantallaLogin(self))

    def salir(self) -> None:
        bd.cerrar()
        self.destroy()


def ejecutar_gui() -> None:
    app = Aplicacion()
    if app.conectado:
        app.mainloop()
