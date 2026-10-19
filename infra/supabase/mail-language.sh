#!/bin/sh
# Keep SMTP template selection/subject and the email hook on one server language.
# Usage: sh mail-language.sh stack/.env [de|en|fr|es]
# Existing configuration and credentials are preserved; legacy stacks default to de.
set -eu
file=${1:?usage: mail-language.sh stack/.env [de|en|fr|es]}
[ -f "$file" ] || { printf '%s\n' 'mail-language: configuration is missing' >&2; exit 2; }
language=${2:-}
if [ -z "$language" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      MAIL_LANGUAGE=*)
        language=${line#MAIL_LANGUAGE=}
        case "$language" in
          \"*\") language=${language#\"}; language=${language%\"} ;;
          \'*\') language=${language#\'}; language=${language%\'} ;;
        esac
        ;;
    esac
  done < "$file"
  language=${language:-de}
fi
case "$language" in
  de) subject='Dein WuselWall-Code' ;;
  en) subject='Your WuselWall code' ;;
  fr) subject='Votre code WuselWall' ;;
  es) subject='Tu código de WuselWall' ;;
  *) printf '%s\n' 'mail-language: language must be de, en, fr or es' >&2; exit 2 ;;
esac
umask 077
tmp=$(mktemp "$file.language.XXXXXX")
trap 'rm -f "$tmp"' 0
trap 'exit 1' HUP INT TERM
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in MAIL_LANGUAGE=*|MAIL_CODE_SUBJECT=*) continue ;; esac
  printf '%s\n' "$line"
done < "$file" > "$tmp"
printf "MAIL_LANGUAGE='%s'\nMAIL_CODE_SUBJECT='%s'\n" "$language" "$subject" >> "$tmp"
chmod 600 "$tmp"
mv "$tmp" "$file"
