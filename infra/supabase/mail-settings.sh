#!/bin/sh
# Mail on or off for a compose stack (specs/20, Q48; docs/server "Email").
#
#   sh mail-settings.sh stack/.env status   what the server does now, and whether it fits
#   sh mail-settings.sh stack/.env off      no mail: passwords only, addresses autoconfirmed
#   SMTP_HOST=… SMTP_PORT=… SMTP_USER=… SMTP_PASS=… SMTP_SENDER=… [SMTP_SENDER_NAME=…] \
#     sh mail-settings.sh stack/.env smtp   sign-in codes by mail through that SMTP server
#
# The values come from the environment, never from the command line, so a password does not
# end up in the shell's history or in the process list. Auth autoconfirms addresses exactly
# when the server sends no mail: either through SMTP or through the Scaleway hook
# (make-env.mjs decides the same way at install). Every other line of the file is kept.
# Restart Auth afterwards (`docker compose up -d auth functions`).
set -eu
file=${1:?usage: mail-settings.sh stack/.env status|off|smtp}
action=${2:-status}
[ -f "$file" ] || { printf '%s\n' 'mail-settings: configuration is missing' >&2; exit 2; }

value() {
  sed -n "s/^$1=//p" "$file" | tail -n 1 | sed "s/^'\(.*\)'\$/\1/; s/^\"\(.*\)\"\$/\1/"
}

# Mail is configured when the hook is on or SMTP names a real host. 'localhost' was the
# placeholder of installs before mail became optional: nothing listens there.
smtp_host=$(value SMTP_HOST)
case "$smtp_host" in localhost) smtp_host='' ;; esac
hook=$(value SEND_EMAIL_HOOK_ENABLED)
autoconfirm=$(value ENABLE_EMAIL_AUTOCONFIRM)

# Rewrites the file without the named keys, then appends their new values (NAME=value pairs).
write() {
  umask 077
  tmp=$(mktemp "$file.mail.XXXXXX")
  trap 'rm -f "$tmp"' 0
  trap 'exit 1' HUP INT TERM
  keys=''
  for pair in "$@"; do keys="$keys ${pair%%=*}"; done
  while IFS= read -r line || [ -n "$line" ]; do
    skip=''
    for key in $keys; do
      case "$line" in "$key="*) skip=1 ;; esac
    done
    [ -n "$skip" ] || printf '%s\n' "$line"
  done < "$file" > "$tmp"
  for pair in "$@"; do printf "%s='%s'\n" "${pair%%=*}" "${pair#*=}" >> "$tmp"; done
  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

fail() { printf 'mail-settings: %s\n' "$1" >&2; exit 2; }

# A value goes between single quotes on one line of the .env.
plain() {
  case "$2" in
    *"'"*) fail "$1 must not contain a single quote" ;;
  esac
  [ "$(printf '%s' "$2" | wc -l)" -eq 0 ] || fail "$1 must be one line"
}

case "$action" in
  status)
    if [ "$hook" = true ]; then
      printf 'Mail: Scaleway (send-email hook), from %s\n' "$(value MAIL_FROM)"
      mail=1
    elif [ -n "$smtp_host" ]; then
      printf 'Mail: SMTP %s:%s as %s, from %s\n' "$smtp_host" "$(value SMTP_PORT)" "$(value SMTP_USER)" \
        "$(value SMTP_ADMIN_EMAIL)"
      mail=1
    else
      printf '%s\n' 'Mail: off. Sign-in with email and password; a guardian resets a forgotten password.'
      mail=''
    fi
    if [ -n "$mail" ] && [ "$autoconfirm" = true ]; then
      printf '%s\n' 'Warning: mail is configured but addresses are autoconfirmed (ENABLE_EMAIL_AUTOCONFIRM).'
      printf '%s\n' "  Run 'wuselwall mail smtp' again, or 'wuselwall mail off'."
      exit 3
    fi
    if [ -z "$mail" ] && [ "$autoconfirm" != true ]; then
      printf '%s\n' 'Warning: no mail is configured, so nobody can sign up or sign in with a code.'
      printf '%s\n' "  Run 'wuselwall mail off' (passwords only) or 'wuselwall mail smtp'."
      exit 3
    fi
    ;;
  off)
    # The port stays a number: Auth refuses to start with an empty one.
    port=$(value SMTP_PORT)
    case "$port" in ''|*[!0-9]*) port=587 ;; esac
    write "SMTP_HOST=" "SMTP_PORT=$port" "SMTP_USER=" "SMTP_PASS=" \
      "SEND_EMAIL_HOOK_ENABLED=false" "SEND_EMAIL_HOOK_URI=" "ENABLE_EMAIL_AUTOCONFIRM=true"
    ;;
  smtp)
    host=${SMTP_HOST:-}
    port=${SMTP_PORT:-587}
    user=${SMTP_USER:-}
    pass=${SMTP_PASS:-}
    sender=${SMTP_SENDER:-$user}
    name=${SMTP_SENDER_NAME:-$(value SMTP_SENDER_NAME)}
    name=${name:-WuselWall}
    [ -n "$host" ] || fail 'SMTP_HOST is required (e.g. smtp.gmail.com)'
    case "$host" in localhost|*[!A-Za-z0-9.-]*) fail "SMTP_HOST is not a host name: $host" ;; esac
    case "$port" in ''|*[!0-9]*) fail "SMTP_PORT must be a number (587 or 465): $port" ;; esac
    [ -n "$user" ] || fail 'SMTP_USER is required'
    [ -n "$pass" ] || fail 'SMTP_PASS is required'
    case "$sender" in *?@?*) ;; *) fail "SMTP_SENDER must be an email address: $sender" ;; esac
    for pair in "SMTP_USER=$user" "SMTP_PASS=$pass" "SMTP_SENDER=$sender" "SMTP_SENDER_NAME=$name"; do
      plain "${pair%%=*}" "${pair#*=}"
    done
    # SMTP replaces the Scaleway hook, which Auth would otherwise prefer.
    write "SMTP_HOST=$host" "SMTP_PORT=$port" "SMTP_USER=$user" "SMTP_PASS=$pass" \
      "SMTP_ADMIN_EMAIL=$sender" "SMTP_SENDER_NAME=$name" \
      "SEND_EMAIL_HOOK_ENABLED=false" "SEND_EMAIL_HOOK_URI=" "ENABLE_EMAIL_AUTOCONFIRM=false"
    ;;
  *) fail 'usage: mail-settings.sh stack/.env status|off|smtp' ;;
esac
