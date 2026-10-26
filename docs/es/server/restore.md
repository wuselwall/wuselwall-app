# Restaurar una copia de seguridad

Prueba la restauración en otra máquina o una máquina virtual antes de necesitarla. Una copia solo sirve si se puede restaurar.

## En casa o alquilado {#at-home}

La herramienta restaura un archivo `db-….dump` en un servidor **recién instalado**. Conserva el antiguo **`stack/.env`** para mantener claves y sesiones de dispositivos.

1. Apunta tu dominio a la nueva máquina.
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
