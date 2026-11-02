"""Componentes reutilizables: tabla, formulario modal, tarjetas y manejo de errores."""
from __future__ import annotations

import tkinter as tk
from dataclasses import dataclass, field
from datetime import date, datetime
from tkinter import messagebox, ttk
from typing import Any, Callable, Sequence

from app.db.conexion import ErrorBaseDatos, ErrorNegocio, Resultado
from app.gui import estilos as e


# ------------------------------------------------------------------ utilidades
def formatear(valor: Any) -> str:
    if valor is None:
        return ""
    if isinstance(valor, datetime):
        return valor.strftime("%d/%m/%Y %H:%M") if (valor.hour or valor.minute) else valor.strftime("%d/%m/%Y")
    if isinstance(valor, date):
        return valor.strftime("%d/%m/%Y")
    if isinstance(valor, float):
        return f"{valor:,.2f}"
    return str(valor)


def ejecutar(ventana: tk.Misc, accion: Callable[[], Any], exito: str | None = None) -> Any:
    """Ejecuta una llamada a la base de datos mostrando los errores en un cuadro de diálogo."""
    try:
        resultado = accion()
    except ErrorNegocio as exc:
        messagebox.showwarning("No se pudo completar", str(exc), parent=ventana)
        return None
    except ErrorBaseDatos as exc:
        messagebox.showerror("Error de base de datos", str(exc), parent=ventana)
        return None
    if exito:
        messagebox.showinfo("Listo", exito, parent=ventana)
    return True if resultado is None else resultado


def centrar(ventana: tk.Toplevel | tk.Tk, ancho: int, alto: int) -> None:
    ventana.update_idletasks()
    x = (ventana.winfo_screenwidth() - ancho) // 2
    y = (ventana.winfo_screenheight() - alto) // 3
    ventana.geometry(f"{ancho}x{alto}+{max(x, 0)}+{max(y, 0)}")


# ------------------------------------------------------------------ tabla
@dataclass
class Columna:
    clave: str
    titulo: str
    ancho: int = 120
    alinear: str = "w"


class Tabla(ttk.Frame):
    """Treeview con barras de desplazamiento, filas alternas y color por estado."""

    def __init__(self, padre: tk.Misc, columnas: Sequence[Columna], columna_color: str | None = None,
                 al_doble_clic: Callable[[], None] | None = None) -> None:
        super().__init__(padre, style="Tarjeta.TFrame")
        self.columnas = list(columnas)
        self.columna_color = columna_color.upper() if columna_color else None
        self._datos: dict[str, dict] = {}

        self.arbol = ttk.Treeview(self, columns=[c.clave for c in self.columnas],
                                  show="headings", selectmode="browse")
        for c in self.columnas:
            self.arbol.heading(c.clave, text=c.titulo, anchor=c.alinear,
                               command=lambda k=c.clave: self._ordenar(k, False))
            self.arbol.column(c.clave, width=c.ancho, minwidth=50, anchor=c.alinear, stretch=True)
        self.arbol.tag_configure("par", background="#FAFBFE")
        for estado, color in e.COLOR_ESTADO.items():
            self.arbol.tag_configure(estado, foreground=color)

        barra_v = ttk.Scrollbar(self, orient="vertical", command=self.arbol.yview)
        barra_h = ttk.Scrollbar(self, orient="horizontal", command=self.arbol.xview)
        self.arbol.configure(yscrollcommand=barra_v.set, xscrollcommand=barra_h.set)
        self.arbol.grid(row=0, column=0, sticky="nsew")
        barra_v.grid(row=0, column=1, sticky="ns")
        barra_h.grid(row=1, column=0, sticky="ew")
        self.rowconfigure(0, weight=1)
        self.columnconfigure(0, weight=1)

        self.vacio = ttk.Label(self, text="", style="Subtitulo.TLabel", background=e.BLANCO)
        if al_doble_clic:
            self.arbol.bind("<Double-1>", lambda _ev: al_doble_clic())

    def cargar(self, resultado: Resultado, texto_vacio: str = "No hay registros para mostrar.") -> None:
        self.arbol.delete(*self.arbol.get_children())
        self._datos.clear()
        for i, fila in enumerate(resultado.como_diccionarios()):
            valores = [formatear(fila.get(c.clave.upper())) for c in self.columnas]
            etiquetas = ["par"] if i % 2 else []
            if self.columna_color and fila.get(self.columna_color) in e.COLOR_ESTADO:
                etiquetas.append(str(fila[self.columna_color]))
            iid = self.arbol.insert("", "end", values=valores, tags=etiquetas)
            self._datos[iid] = fila
        if self._datos:
            self.vacio.place_forget()
        else:
            self.vacio.configure(text=texto_vacio)
            self.vacio.place(relx=0.5, rely=0.5, anchor="center")

    def seleccionado(self) -> dict | None:
        seleccion = self.arbol.selection()
        return self._datos.get(seleccion[0]) if seleccion else None

    def _ordenar(self, clave: str, descendente: bool) -> None:
        filas = [(self.arbol.set(i, clave), i) for i in self.arbol.get_children("")]

        def llave(par: tuple[str, str]):
            texto = par[0].replace(",", "")
            try:
                return (0, float(texto))
            except ValueError:
                try:
                    return (0, datetime.strptime(texto[:10], "%d/%m/%Y").timestamp())
                except ValueError:
                    return (1, texto.lower())

        filas.sort(key=llave, reverse=descendente)
        for posicion, (_, iid) in enumerate(filas):
            self.arbol.move(iid, "", posicion)
        self.arbol.heading(clave, command=lambda: self._ordenar(clave, not descendente))


# ------------------------------------------------------------------ formulario
@dataclass
class Campo:
    clave: str
    etiqueta: str
    tipo: str = "texto"          # texto | contrasena | multilinea | opciones | catalogo | fecha
    opciones: Sequence[Any] = field(default_factory=tuple)  # catalogo: [(id, texto), ...]
    valor: Any = None
    obligatorio: bool = True


class Formulario(tk.Toplevel):
    """Diálogo modal que devuelve un diccionario con los valores capturados (o None)."""

    def __init__(self, padre: tk.Misc, titulo: str, campos: Sequence[Campo],
                 texto_boton: str = "Guardar") -> None:
        super().__init__(padre)
        self.title(titulo)
        self.configure(bg=e.BLANCO)
        self.resizable(False, False)
        self.transient(padre.winfo_toplevel())
        self.resultado: dict[str, Any] | None = None
        self.campos = list(campos)
        self._widgets: dict[str, Any] = {}

        cuerpo = ttk.Frame(self, style="Tarjeta.TFrame", padding=24)
        cuerpo.pack(fill="both", expand=True)
        ttk.Label(cuerpo, text=titulo, style="Titulo.TLabel", background=e.BLANCO).grid(
            row=0, column=0, sticky="w", pady=(0, 14))

        fila = 1
        for campo in self.campos:
            texto = campo.etiqueta + (" *" if campo.obligatorio else "")
            ttk.Label(cuerpo, text=texto, style="Campo.TLabel").grid(row=fila, column=0, sticky="w")
            fila += 1
            widget = self._crear_widget(cuerpo, campo)
            widget.grid(row=fila, column=0, sticky="ew", pady=(2, 10))
            fila += 1
        cuerpo.columnconfigure(0, weight=1, minsize=380)

        botones = ttk.Frame(cuerpo, style="Tarjeta.TFrame")
        botones.grid(row=fila, column=0, sticky="e", pady=(6, 0))
        ttk.Button(botones, text="Cancelar", command=self.destroy).pack(side="left", padx=(0, 8))
        ttk.Button(botones, text=texto_boton, style="Primario.TButton", command=self._aceptar).pack(side="left")

        self.bind("<Escape>", lambda _e: self.destroy())
        self.update_idletasks()
        centrar(self, max(self.winfo_reqwidth(), 440), self.winfo_reqheight())
        self.grab_set()
        primero = next(iter(self._widgets.values()), None)
        if primero is not None:
            primero.focus_set()
        self.wait_window()

    def _crear_widget(self, padre: tk.Misc, campo: Campo):
        if campo.tipo == "multilinea":
            widget = tk.Text(padre, height=5, width=46, wrap="word", relief="solid", bd=1,
                             highlightthickness=0, font="TkDefaultFont")
            if campo.valor:
                widget.insert("1.0", campo.valor)
        elif campo.tipo in ("opciones", "catalogo"):
            textos = [o[1] if campo.tipo == "catalogo" else o for o in campo.opciones]
            if not campo.obligatorio:
                textos = ["(ninguno)", *textos]
            widget = ttk.Combobox(padre, values=textos, state="readonly")
            if campo.tipo == "catalogo":
                actual = next((t for i, t in campo.opciones if i == campo.valor), None)
            else:
                actual = campo.valor
            if actual is not None and actual in textos:
                widget.set(actual)
            elif not campo.obligatorio:
                widget.set("(ninguno)")
        else:
            widget = ttk.Entry(padre, show="•" if campo.tipo == "contrasena" else "")
            if campo.valor is not None:
                texto = campo.valor.strftime("%d/%m/%Y") if isinstance(campo.valor, (date, datetime)) else str(campo.valor)
                widget.insert(0, texto)
            if campo.tipo == "fecha" and campo.valor is None:
                widget.insert(0, date.today().strftime("%d/%m/%Y"))
            widget.bind("<Return>", lambda _e: self._aceptar())
        self._widgets[campo.clave] = widget
        return widget

    def _leer(self, campo: Campo) -> Any:
        widget = self._widgets[campo.clave]
        if campo.tipo == "multilinea":
            texto = widget.get("1.0", "end").strip()
        else:
            texto = widget.get().strip()
        if texto in ("", "(ninguno)"):
            if campo.obligatorio:
                raise ValueError(f"El campo «{campo.etiqueta}» es obligatorio.")
            return None
        if campo.tipo == "catalogo":
            return next(i for i, t in campo.opciones if t == texto)
        if campo.tipo == "fecha":
            try:
                return datetime.strptime(texto, "%d/%m/%Y").date()
            except ValueError as exc:
                raise ValueError(f"«{campo.etiqueta}» debe tener el formato dd/mm/aaaa.") from exc
        return texto

    def _aceptar(self) -> None:
        try:
            valores = {c.clave: self._leer(c) for c in self.campos}
        except ValueError as exc:
            messagebox.showwarning("Revise los datos", str(exc), parent=self)
            return
        self.resultado = valores
        self.destroy()


def pedir(padre: tk.Misc, titulo: str, campos: Sequence[Campo], texto_boton: str = "Guardar") -> dict | None:
    return Formulario(padre, titulo, campos, texto_boton).resultado


# ------------------------------------------------------------------ piezas de sección
class Encabezado(ttk.Frame):
    def __init__(self, padre: tk.Misc, titulo: str, subtitulo: str = "") -> None:
        super().__init__(padre)
        ttk.Label(self, text=titulo, style="Titulo.TLabel").pack(anchor="w")
        if subtitulo:
            ttk.Label(self, text=subtitulo, style="Subtitulo.TLabel").pack(anchor="w", pady=(2, 0))


class BarraBotones(ttk.Frame):
    def __init__(self, padre: tk.Misc) -> None:
        super().__init__(padre)

    def boton(self, texto: str, comando: Callable[[], None], estilo: str = "TButton",
              derecha: bool = False) -> ttk.Button:
        b = ttk.Button(self, text=texto, command=comando, style=estilo)
        b.pack(side="right" if derecha else "left", padx=(0, 6) if not derecha else (6, 0))
        return b


class Kpi(ttk.Frame):
    def __init__(self, padre: tk.Misc, texto: str, color: str = e.AZUL) -> None:
        super().__init__(padre, style="Tarjeta.TFrame", padding=(18, 14))
        borde = tk.Frame(self, bg=color, width=4)
        borde.pack(side="left", fill="y", padx=(0, 14))
        contenido = ttk.Frame(self, style="Tarjeta.TFrame")
        contenido.pack(side="left", fill="both", expand=True)
        self.valor = ttk.Label(contenido, text="–", style="KpiValor.TLabel", foreground=color)
        self.valor.pack(anchor="w")
        ttk.Label(contenido, text=texto, style="KpiTexto.TLabel").pack(anchor="w")

    def poner(self, valor: Any) -> None:
        self.valor.configure(text=formatear(valor) if valor is not None else "0")


def requiere_seleccion(ventana: tk.Misc, fila: dict | None, que: str = "un registro") -> bool:
    if fila is None:
        messagebox.showinfo("Seleccione", f"Primero seleccione {que} en la tabla.", parent=ventana)
        return False
    return True
