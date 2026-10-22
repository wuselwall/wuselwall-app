# Restaurar una copia de seguridad

Prueba la restauración en otra máquina o una máquina virtual antes de necesitarla. Una copia solo sirve si se puede restaurar.

## En casa {#at-home}

La herramienta restaura un archivo `db-….dump` en un servidor **recién instalado**. Conserva el antiguo **`stack/.env`** para mantener claves y sesiones de dispositivos.

1. Apunta `api.` y `web.` a la nueva máquina.
2. Descomprime la misma versión o una posterior e instala con el archivo anterior:

   ```bash
   ./wuselwall install --env /path/to/old.env
   ```

3. Restaura:

   ```bash
   ./wuselwall restore /path/to/db-2026-10-14-0330-nightly.dump
   ```

4. Comprueba el móvil: con las claves anteriores debería conservar la sesión.

La herramienta detiene los otros servicios, reemplaza la base, reinicia, aplica migraciones necesarias y programa los trabajos. Después cuenta hogares, miembros, dispositivos y cuentas.

::: warning Un servidor con datos
La restauración se rechaza por defecto. Para volver deliberadamente a un estado anterior, antepón `WW_RESTORE_OVER_DATA=yes` al comando. Primero se hace copia del estado actual.
:::

Sin el antiguo `.env`, instala con `--api` y `--web` y restaura. Recuperarás datos, pero habrá que conectar de nuevo los dispositivos.

## En Supabase {#at-supabase}

Usa **Database → Backups** según tu plan. El proyecto puede quedar inaccesible durante la restauración. Para una copia propia, sigue el [procedimiento oficial con CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Cifra los archivos: contienen los datos familiares.

Las copias permiten trasladarse entre Supabase y un servidor propio, pero el recorrido completo aún no está documentado paso a paso.
