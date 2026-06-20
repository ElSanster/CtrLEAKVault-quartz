#!/bin/bash
# inject-dates.sh
#
# Recorre cada archivo .md del vault clonado y le inyecta (o actualiza)
# los campos `created` y `modified` en el frontmatter YAML, usando las
# fechas REALES extraídas del historial de git del vault.
#
# Esto evita el warning "isn't yet tracked by git, dates will be inaccurate"
# porque el plugin created-modified-date de Quartz leerá estas fechas
# directamente del frontmatter, sin depender del historial de git del
# repo de Quartz (que se recrea en cada sync).

set -e

VAULT_DIR="vault-content"

cd "$VAULT_DIR"

find . -type f -name "*.md" | while read -r file; do
  # Fecha del primer commit que tocó el archivo (creación)
  created=$(git log --diff-filter=A --follow --format=%aI -1 -- "$file" 2>/dev/null || echo "")
  # Fecha del commit más reciente que tocó el archivo (última modificación)
  modified=$(git log --format=%aI -1 -- "$file" 2>/dev/null || echo "")

  # Si no hay historial (archivo nunca commiteado), saltar
  if [ -z "$modified" ]; then
    continue
  fi
  if [ -z "$created" ]; then
    created="$modified"
  fi

  # Revisar si el archivo ya tiene frontmatter (empieza con ---)
  first_line=$(head -n 1 "$file")

  if [ "$first_line" == "---" ]; then
    # Ya tiene frontmatter: insertar/actualizar created y modified dentro de él
    awk -v created="$created" -v modified="$modified" '
      BEGIN { in_fm=0; fm_done=0; printed_created=0; printed_modified=0 }
      NR==1 && $0=="---" { in_fm=1; print; next }
      in_fm && $0=="---" && !fm_done {
        if (!printed_created) print "created: " created
        if (!printed_modified) print "modified: " modified
        fm_done=1; in_fm=0
        print
        next
      }
      in_fm && /^created:/ { print "created: " created; printed_created=1; next }
      in_fm && /^modified:/ { print "modified: " modified; printed_modified=1; next }
      { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    # No tiene frontmatter: crear uno nuevo
    {
      echo "---"
      echo "created: $created"
      echo "modified: $modified"
      echo "---"
      cat "$file"
    } > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done

cd ..
echo "✅ Fechas inyectadas desde el historial de git del vault"