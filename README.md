# Nexora — Sistema de Gestión de Soporte TI y Activos

## Requisitos

- Oracle Database (XE 21c, 23ai Free o 19c) y SQL Developer.
- Python 3.11 o superior (el instalador de python.org ya incluye Tkinter).

## Cómo ejecutarlo

1. **Crear el usuario de la base de datos** (solo la primera vez).
   En SQL Developer conéctese como `SYSTEM`, abra `database/00_crear_usuario.sql` y presione **F5**.
   Al terminar, el script indica el nombre de servicio que debe usar (por ejemplo `XEPDB1`, `FREEPDB1` u `ORCLPDB`).

2. **Instalar el esquema.**
   Cree una conexión con el usuario `nexora` / `Nexora2026` y ese nombre de servicio.
   Abra `database/instalar.sql` y presione **F5**. Se crean las tablas, vistas, paquetes, triggers y datos de prueba.

3. **Verificar la instalación** (opcional).
   Ejecute `database/09_pruebas_y_conteo.sql` con **F5**. La última consulta (objetos inválidos) debe devolver 0 filas.

4. **Preparar el entorno de Python.**

   ```bash
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   copy .env.example .env
   ```

   En Linux o Mac use `source .venv/bin/activate` y `cp .env.example .env`.

5. **Configurar la conexión.**
   Abra `.env` y ajuste `NEXORA_DB_DSN` con el nombre de servicio del paso 1, por ejemplo
   `localhost:1521/XEPDB1`.

6. **Ejecutar el programa.**

   ```bash
   python main.py
   ```

   Para usar la versión de consola: `python main.py --consola`.

7. **Iniciar sesión** con alguno de los usuarios de prueba:

   | Usuario | Contraseña | Rol |
   |---|---|---|
   | `admin` | `Admin2026` | Administrador de TI |
   | `lmora`, `crojas`, `avargas` | `Tecnico2026` | Técnico |
   | `jperez`, `msolis`, `kcastro` | `Empleado2026` | Empleado |
