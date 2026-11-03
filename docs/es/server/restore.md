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
La restauración se rechaza por defecto. Para volver deliberadamente a un estado anterior, antepón `WW_RESTORE_OVER_DATA=yes` al comando.
:::

Antes de reemplazar nada, la herramienta siempre hace copia del estado actual (`db-…-before-restore.dump`), también en un servidor vacío. Si no puede saber si hay una familia, o si esa copia falla, se detiene sin cambiar nada.

Sin el antiguo `.env`, instala con `--api` y `--web` y restaura. Recuperarás datos, pero habrá que conectar de nuevo los dispositivos.

### Copias cifradas {#encrypted}

Una copia lo contiene todo, también los hashes de las contraseñas y los secretos de los códigos de dos factores. La herramienta la deja legible solo para su propietario, en un directorio que solo él puede abrir. Si las copias están en una carpeta compartida que otros leen en la red, o quieres protegerlas igualmente, cifra cada archivo cuando el `backup.env` junto a la herramienta (`chmod 600`) contiene una de estas líneas:

```bash
# Recomendado: con age (apt install age). El servidor solo conoce la clave pública.
BACKUP_AGE_RECIPIENT=age1…
# O con una frase de contraseña larga (openssl, ya instalado):
BACKUP_PASSPHRASE='…'
```

Crea la clave de age una vez en tu portátil con `age-keygen -o wuselwall-backup.key`; la línea `public key: age1…` va en `backup.env`, el archivo `wuselwall-backup.key` en el gestor de contraseñas y **no** en el servidor. La frase también va en el gestor de contraseñas. Sin la clave o la frase, una copia cifrada no sirve de nada.

Las copias se llaman entonces `db-….dump.age` o `db-….dump.enc`. Para restaurar una, descífrala primero y pasa a `restore` el archivo descifrado:

```bash
age -d -i /path/to/wuselwall-backup.key -o db-2026-10-14-0330-nightly.dump db-2026-10-14-0330-nightly.dump.age
# o, con la frase (openssl la pide):
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in db-2026-10-14-0330-nightly.dump.enc -out db-2026-10-14-0330-nightly.dump
```

Borra después el archivo descifrado. El simulacro de restauración (`infra/backup/restore-drill.sh`) lee las copias cifradas directamente, con `BACKUP_PASSPHRASE` o con `BACKUP_AGE_IDENTITY=/path/to/wuselwall-backup.key`.

## En Supabase {#at-supabase}

Usa **Database → Backups** según tu plan. El proyecto puede quedar inaccesible durante la restauración. Para una copia propia, sigue el [procedimiento oficial con CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Cifra los archivos: contienen los datos familiares.

Las copias permiten trasladarse entre Supabase y un servidor propio, pero el recorrido completo aún no está documentado paso a paso.
