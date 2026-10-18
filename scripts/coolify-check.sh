#!/usr/bin/env bash
# Verifica que los compose declarados para Coolify cumplen el contrato mínimo
# (nada que salte Traefik, nombres estables, parametrización por variables).
# No toca secretos reales: usa valores ficticios x123… y https://ejemplo.invalid.
#
# Salida:
#   0 -> todos los compose del contrato rinden y pasan las comprobaciones
#   1 -> falla de contrato (servicio y motivo por línea)
#   2 -> error de uso (dependencias, compose inválido, etc.)
#
# Las apps declaradas siguen el formato:
#   base_dir|compose_file|bd
# bd = "supabase-rest" | "supabase-pg"
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

command -v docker >/dev/null || { echo "docker no está instalado" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq no está instalado" >&2; exit 2; }
docker compose version >/dev/null || { echo "docker compose (plugin) no está disponible" >&2; exit 2; }

# Apps declaradas en el contrato de este repo.
apps=(
  "/|compose.supabase.yaml|supabase-rest"
)

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

failures=0

for entry in "${apps[@]}"; do
  base_dir="${entry%%|*}"
  rest="${entry#*|}"
  compose_file="${rest%%|*}"
  bd="${rest##*|}"

  abs_base_dir="${project_root}${base_dir}"
  compose_path="${abs_base_dir}/${compose_file}"

  if [[ ! -f "${compose_path}" ]]; then
    echo "${compose_path}: archivo inexistente" >&2
    failures=$((failures + 1))
    continue
  fi

  env_file="${tmp_root}/env.${compose_file//\//_}.env"

  # Extrae ${VAR} y ${VAR:-default} del compose (sin capturar ${VAR:?…}).
  # Las requeridas (con :?) se rellenan con x123…; las opcionales con su default si existe.
  vars="$(grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*(:[-?][^}]*)?\}' "${compose_path}" \
    | sed -E 's/^\$\{([A-Za-z_][A-Za-z0-9_]*).*/\1/' \
    | sort -u)"

  : > "${env_file}"
  for var in ${vars}; do
    case "${var}" in
      # Direcciones que el compose trata como URL/host deben llevar https://ejemplo.invalid.
      SUPABASE_URL|PUBLIC_ORIGIN|DB_HOST|SUPABASE_REST_URL)
        echo "${var}=https://ejemplo.invalid" >> "${env_file}"
        ;;
      # Para supabase-pg el chequeo exige DB_SSLMODE=disable y DB_NAME=mvp_prueba.
      DB_NAME)
        if [[ "${bd}" == "supabase-pg" ]]; then
          echo "${var}=mvp_prueba" >> "${env_file}"
        else
          echo "${var}=x1234567890" >> "${env_file}"
        fi
        ;;
      DB_SSLMODE)
        if [[ "${bd}" == "supabase-pg" ]]; then
          echo "${var}=disable" >> "${env_file}"
        else
          echo "${var}=x1234567890" >> "${env_file}"
        fi
        ;;
      *)
        echo "${var}=x1234567890" >> "${env_file}"
        ;;
    esac
  done

  rendered="${tmp_root}/render.${compose_file//\//_}.json"
  if ! docker compose \
      --project-directory "${abs_base_dir}" \
      -f "${compose_path}" \
      --env-file "${env_file}" \
      config --format json > "${rendered}" 2> "${tmp_root}/render.err"; then
    echo "${compose_file}: docker compose config falló:" >&2
    cat "${tmp_root}/render.err" >&2
    failures=$((failures + 1))
    continue
  fi

  # Contrato punto 2: nada de 'name:' fijo a nivel raíz del compose.
  if grep -qE '^name:' "${compose_path}"; then
    echo "${compose_file}: name fijo en raíz" >&2
    failures=$((failures + 1))
  fi

  jq_query='
    .services // {}
    | to_entries[]
    | select((.value.profiles // []) | length == 0)
    | . as $entry
    | [
        (if ($entry.value.ports // [] | length) > 0 then "ports" else empty end),
        (if ($entry.value.container_name // null) != null then "container_name" else empty end),
        (if ($entry.value.privileged // false) == true then "privileged" else empty end),
        (if ($entry.value.cap_add // [] | length) > 0 then "cap_add" else empty end),
        (if ($entry.value.devices // [] | length) > 0 then "devices" else empty end),
        (if ($entry.value.network_mode // null) == "host" then "network_mode=host" else empty end),
        (if ($entry.value.pid // null) == "host" then "pid=host" else empty end),
        (if ($entry.value.ipc // null) == "host" then "ipc=host" else empty end),
        (
          ($entry.value.security_opt // [])
          | map(select(test("unconfined")))
          | if length > 0 then "security_opt=unconfined" else empty end
        )
      ]
    | .[]
    | "\($entry.key):\(.)"
  '

  # Si jq falla por sintaxis o por forma inesperada, set -euo pipefail lo propaga
  # como exit 2; no se traga con || true para no aprobar cuando debería fallar.
  bad="$(jq -r "${jq_query}" "${rendered}")"
  if [[ -n "${bad}" ]]; then
    while IFS= read -r line; do
      echo "${compose_file}: ${line}" >&2
      failures=$((failures + 1))
    done <<< "${bad}"
  fi

  # Bind mounts fuera del repo o que monten docker.sock. Se compara la raíz del
  # bind contra el project_root del repo: fuera del repo o que mencione
  # docker.sock se considera peligroso.
  bind_query='
    [
      .services // {}
      | to_entries[]
      | select((.value.profiles // []) | length == 0)
      | .value.volumes // []
      | to_entries[]
      | select(.value.type == "bind")
      | .value.source
    ]
    | map(select(
        ( ((. == $root) or startswith($root + "/")) | not )
        or test("docker\\.sock")
      ))
    | .[]
  '
  bad_binds="$(jq --arg root "${project_root}" -r "${bind_query}" "${rendered}")"
  if [[ -n "${bad_binds}" ]]; then
    while IFS= read -r source; do
      echo "${compose_file}: bind fuera del repo o expone docker.sock: ${source}" >&2
      failures=$((failures + 1))
    done <<< "${bad_binds}"
  fi

  # Contrato punto 2 (continuación): redes y volúmenes no pueden tener 'name:'
  # fijo. Coolify pone el nombre del proyecto al desplegar; si el compose lo
  # fija, choca con el despliegue. Se re-renderiza con --project-name
  # coolifycheck para que compose ponga sufijo predecible y poder comparar.
  rendered_names="${tmp_root}/render-names.${compose_file//\//_}.json"
  if ! docker compose \
      --project-name coolifycheck \
      --project-directory "${abs_base_dir}" \
      -f "${compose_path}" \
      --env-file "${env_file}" \
      config --format json > "${rendered_names}" 2> "${tmp_root}/render-names.err"; then
    echo "${compose_file}: docker compose config (re-render) falló:" >&2
    cat "${tmp_root}/render-names.err" >&2
    failures=$((failures + 1))
  else
    name_query='
      (.networks // {} | to_entries[]) as $n
      | select($n.value.external != true)
      | select($n.value.name != "coolifycheck_\($n.key)")
      | "red:\($n.key): name fijo (\($n.value.name))"
      ,
      (.volumes // {} | to_entries[]) as $v
      | select($v.value.external != true)
      | select($v.value.name != "coolifycheck_\($v.key)")
      | "volumen:\($v.key): name fijo (\($v.value.name))"
    '
    bad_names="$(jq -r "${name_query}" "${rendered_names}")"
    if [[ -n "${bad_names}" ]]; then
      while IFS= read -r line; do
        echo "${compose_file}: ${line}" >&2
        failures=$((failures + 1))
      done <<< "${bad_names}"
    fi
  fi

  # Para supabase-pg: DB_NAME=mvp_prueba y DB_SSLMODE=disable deben aparecer
  # en el render (variables del servicio o renderizadas en un DSN/URL).
  if [[ "${bd}" == "supabase-pg" ]]; then
    found_name="$(jq -r '[.. | objects | select(has("DB_NAME")) | .DB_NAME] | any(. == "mvp_prueba")' "${rendered}")"
    found_ssl="$(jq -r '[.. | strings | select(test("disable"))] | any(. == "disable" or startswith("disable"))' "${rendered}")"
    if [[ "${found_name}" != "true" ]]; then
      echo "${compose_file}: DB_NAME=mvp_prueba no aparece en el render" >&2
      failures=$((failures + 1))
    fi
    if [[ "${found_ssl}" != "true" ]]; then
      echo "${compose_file}: DB_SSLMODE=disable no aparece en el render" >&2
      failures=$((failures + 1))
    fi
  fi
done

if (( failures > 0 )); then
  echo "coolify-check: ${failures} comprobación(es) fallida(s)" >&2
  exit 1
fi

echo "coolify-check: OK"