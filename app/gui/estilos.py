"""Paleta, fuentes y tema ttk de la interfaz."""
from __future__ import annotations

import tkinter as tk
from tkinter import font as tkfont
from tkinter import ttk

# Paleta inspirada en los colores institucionales (azul y morado)
AZUL = "#2E3A8C"
AZUL_OSCURO = "#1F2766"
AZUL_CLARO = "#E8EBF7"
MORADO = "#7A2E8C"
FONDO = "#F4F5FA"
BLANCO = "#FFFFFF"
TEXTO = "#1E2233"
TEXTO_SUAVE = "#5B6178"
BORDE = "#D5D9E8"
VERDE = "#1E7A4C"
ROJO = "#B3261E"
AMBAR = "#A35F00"

COLOR_ESTADO = {
    "ABIERTO": "#1F5FBF",
    "EN_PROCESO": AMBAR,
    "RESUELTO": VERDE,
    "CERRADO": TEXTO_SUAVE,
    "DISPONIBLE": VERDE,
    "ASIGNADO": "#1F5FBF",
    "REPARACION": AMBAR,
    "BAJA": TEXTO_SUAVE,
    "CRITICA": ROJO,
    "N": TEXTO_SUAVE,
}


def _familia() -> str:
    disponibles = set(tkfont.families())
    for candidata in ("Segoe UI", "Helvetica Neue", "Ubuntu", "DejaVu Sans", "Arial"):
        if candidata in disponibles:
            return candidata
    return "TkDefaultFont"


def aplicar_tema(raiz: tk.Tk) -> str:
    familia = _familia()
    for nombre in ("TkDefaultFont", "TkTextFont", "TkMenuFont", "TkHeadingFont"):
        tkfont.nametofont(nombre).configure(family=familia, size=10)
    raiz.configure(bg=FONDO)

    estilo = ttk.Style(raiz)
    estilo.theme_use("clam")

    estilo.configure(".", font=(familia, 10), background=FONDO, foreground=TEXTO)
    estilo.configure("TFrame", background=FONDO)
    estilo.configure("Tarjeta.TFrame", background=BLANCO, relief="flat")
    estilo.configure("Lateral.TFrame", background=AZUL_OSCURO)
    estilo.configure("TLabel", background=FONDO, foreground=TEXTO)
    estilo.configure("Tarjeta.TLabel", background=BLANCO)
    estilo.configure("Titulo.TLabel", font=(familia, 18, "bold"), foreground=AZUL_OSCURO)
    estilo.configure("Subtitulo.TLabel", font=(familia, 10), foreground=TEXTO_SUAVE)
    estilo.configure("KpiValor.TLabel", font=(familia, 24, "bold"), background=BLANCO, foreground=AZUL)
    estilo.configure("KpiTexto.TLabel", font=(familia, 9), background=BLANCO, foreground=TEXTO_SUAVE)
    estilo.configure("Campo.TLabel", font=(familia, 9, "bold"), background=BLANCO, foreground=TEXTO_SUAVE)

    estilo.configure("TButton", padding=(10, 5), width=-1, background=BLANCO, bordercolor=BORDE, relief="flat")
    estilo.map("TButton", background=[("active", AZUL_CLARO)])
    estilo.configure("Primario.TButton", background=AZUL, foreground=BLANCO, bordercolor=AZUL)
    estilo.map("Primario.TButton", background=[("active", AZUL_OSCURO), ("disabled", BORDE)],
               foreground=[("disabled", TEXTO_SUAVE)])
    estilo.configure("Peligro.TButton", foreground=ROJO)

    estilo.configure("TEntry", fieldbackground=BLANCO, bordercolor=BORDE, padding=5)
    estilo.configure("TCombobox", fieldbackground=BLANCO, bordercolor=BORDE, padding=4)
    estilo.map("TCombobox", fieldbackground=[("readonly", BLANCO)])
    estilo.configure("TCheckbutton", background=FONDO)

    estilo.configure("Treeview", background=BLANCO, fieldbackground=BLANCO, rowheight=28,
                     bordercolor=BORDE, font=(familia, 10))
    estilo.configure("Treeview.Heading", background=AZUL_CLARO, foreground=AZUL_OSCURO,
                     font=(familia, 9, "bold"), relief="flat", padding=(6, 6))
    estilo.map("Treeview", background=[("selected", AZUL)], foreground=[("selected", BLANCO)])
    estilo.map("Treeview.Heading", background=[("active", BORDE)])
    return familia
