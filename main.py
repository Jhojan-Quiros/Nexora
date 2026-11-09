"""Sistema de Gestión de Soporte TI y Activos - Nexora Technologies S.A.

    python main.py            -> interfaz gráfica (Tkinter)
    python main.py --consola  -> interfaz de consola
"""
import sys

if __name__ == "__main__":
    if "--consola" in sys.argv:
        from app.ui.consola import ejecutar
    else:
        from app.gui.aplicacion import ejecutar_gui as ejecutar
    ejecutar()
