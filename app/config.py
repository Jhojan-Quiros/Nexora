"""Configuración de la conexión, leída de variables de entorno o del archivo .env."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

try:  # python-dotenv es opcional
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
except ImportError:  # pragma: no cover
    pass


@dataclass(frozen=True)
class Configuracion:
    usuario: str
    contrasena: str
    dsn: str


CONFIG = Configuracion(
    usuario=os.getenv("NEXORA_DB_USER", "nexora"),
    contrasena=os.getenv("NEXORA_DB_PASSWORD", "Nexora2026"),
    dsn=os.getenv("NEXORA_DB_DSN", "localhost:1521/XEPDB1"),
)
