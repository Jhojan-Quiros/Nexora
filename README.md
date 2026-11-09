# Nexora — Sistema de Gestión de Soporte TI y Activos

Proyecto del curso de Lenguajes de Bases de Datos (Universidad Fidélitas, III cuatrimestre 2026).
Autor: Jhojan Andrey Quirós Cascante.

Este entregable cubre el **50 % del sistema** (segundo entregable, semana 9):

- La **base de datos completa** en Oracle: las 9 tablas del modelo relacional, cada una con su CRUD
  en procedimientos almacenados.
- El **programa en Python con interfaz gráfica Tkinter** con los módulos de departamentos, empleados, técnicos, equipos,
  asignación de equipos y tickets (RF-01 a RF-06), además del inicio de sesión por rol (RF-12).

## Regla del proyecto: sin SQL en el código

El programa **no contiene ninguna sentencia SQL**. Cada operación llama a un procedimiento o función
de un paquete PL/SQL mediante `cursor.callproc()` o `cursor.callfunc()` (archivo
`app/db/conexion.py`). Las consultas devuelven un `SYS_REFCURSOR` abierto sobre una vista.

## Objetos programados

| Objeto | Mínimo | Entregado | Dónde |
|---|---|---|---|
| Procedimientos almacenados | 25 | 83 | Dentro de los 12 paquetes |
| Vistas | 10 | 15 | `02_vistas.sql` |
| Funciones | 15 | 29 | Dentro de los 12 paquetes |
| Paquetes | 10 | 12 | `03` a `06` |
| Triggers | 5 | 7 | `07_triggers.sql` |
| Cursores explícitos | 15 | 18 | Cuerpos de los paquetes (marcados `-- CURSOR n`) |

El script `09_pruebas_y_conteo.sql` cuenta estos objetos directamente desde el diccionario de Oracle.

**Paquetes:** `pkg_utilidades`, `pkg_seguridad`, `pkg_departamento`, `pkg_tecnico`, `pkg_empleado`,
`pkg_equipo`, `pkg_licencia`, `pkg_asignacion_equipo`, `pkg_asignacion_licencia`, `pkg_ticket`,
`pkg_comentario`, `pkg_reportes`.

**Triggers:** normalización de empleados, validación de baja de equipos, sincronización del estado
del equipo con su asignación, bloqueo de licencias vencidas, valores iniciales del ticket, ciclo de
vida del ticket (y fecha de cierre automática), y bloqueo de comentarios en tickets cerrados.

## Ajustes al modelo del documento

- Se agregó la columna `activo` a `departamento`, `empleado` y `tecnico` para cumplir RF-01
  (“desactivar”) sin perder el historial.
- Se agregó `fecha_registro` a `empleado`.
- Un índice único parcial garantiza que un equipo tenga **una sola asignación vigente**.
- Se creó el departamento *Tecnologías de Información*, al que pertenecen el administrador y los técnicos.

## Instalación

1. **Crear el usuario** (una sola vez). En SQL Developer conéctese como `SYSTEM` a la PDB
   (`XEPDB1` en Oracle XE 21c, `FREEPDB1` en Oracle 23ai Free) y ejecute `database/00_crear_usuario.sql`.
2. **Crear el esquema.** Cree una conexión con el usuario `nexora` / `Nexora2026`, abra
   `database/instalar.sql` y presione **F5** (Ejecutar script). Crea tablas, vistas, paquetes,
   triggers y datos de prueba.
3. **Verificar.** Ejecute `database/09_pruebas_y_conteo.sql` con F5. La última consulta
   (objetos inválidos) debe devolver 0 filas.
4. **Programa.**

   ```bash
   python -m venv .venv
   .venv\Scripts\activate          # Windows  (Linux/Mac: source .venv/bin/activate)
   pip install -r requirements.txt
   copy .env.example .env          # ajuste el DSN si usa FREEPDB1
   python main.py              # interfaz gráfica (Tkinter)
   python main.py --consola    # versión de consola (opcional)
   ```

   `python-oracledb` funciona en modo *thin*: no necesita Oracle Instant Client.
   Tkinter viene incluido con el instalador de Python para Windows (python.org).

## Usuarios de prueba

| Usuario | Contraseña | Rol |
|---|---|---|
| `admin` | `Admin2026` | Administrador de TI |
| `lmora`, `crojas`, `avargas` | `Tecnico2026` | Técnico |
| `jperez`, `msolis`, `kcastro`, … | `Empleado2026` | Empleado |

## Estructura

```
nexora/
├── main.py
├── requirements.txt
├── .env.example
├── app/
│   ├── config.py               # lectura de .env
│   ├── db/conexion.py          # conexión, callproc/callfunc y traducción de errores
│   ├── servicios/
│   │   ├── catalogos.py        # departamentos, empleados, técnicos, equipos, asignaciones
│   │   └── soporte.py          # sesión, tickets, panel
│   ├── gui/                    # INTERFAZ GRÁFICA (Tkinter)
│   │   ├── aplicacion.py       # ventana, login y menú lateral por rol
│   │   ├── secciones.py        # panel, departamentos, empleados, técnicos, equipos, asignaciones
│   │   ├── tickets.py          # tickets y ficha de detalle
│   │   ├── componentes.py      # tabla, formularios modales, tarjetas
│   │   └── estilos.py          # colores y tema
│   └── ui/                     # versión de consola
│       ├── consola.py
│       ├── menu_admin.py
│       ├── menu_tickets.py
│       └── utilidades.py       # entradas validadas y tablas en consola
└── database/
    ├── 00_crear_usuario.sql
    ├── 01_tablas.sql ... 08_datos_prueba.sql
    ├── 09_pruebas_y_conteo.sql
    └── instalar.sql
```

## Requerimientos cubiertos en esta entrega

| RF | Estado |
|---|---|
| RF-01 Empleados y departamentos | Base de datos + programa |
| RF-02 Equipos | Base de datos + programa |
| RF-03 Asignación con historial | Base de datos + programa |
| RF-04 Crear ticket | Base de datos + programa |
| RF-05 Asignar técnico y cambiar estado | Base de datos + programa (incluye asignación automática por carga) |
| RF-06 Consultar tickets con filtros | Base de datos + programa |
| RF-12 Inicio de sesión por rol | Base de datos + programa (adelantado de la semana 13) |
| RF-07 Comentarios | Base de datos lista; el programa los muestra, el registro llega en la semana 10 |
| RF-08, RF-09 Licencias | Base de datos lista; interfaz en la semana 11 |
| RF-10, RF-11 Reportes y CSV | Base de datos lista; interfaz y CSV en la semana 12 |

## Seguridad

- Contraseñas guardadas como hash SHA-256 (`STANDARD_HASH`), con el usuario como sal.
- Todos los valores viajan como parámetros enlazados; no hay concatenación de SQL.
- Los procedimientos no hacen `COMMIT`: el programa confirma cada operación o la revierte si falla.
- Las credenciales de la base de datos viven en `.env`, que está en `.gitignore`.
