#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configuración
# =========================
REPO_URL="https://github.com/intersystems-ib/workshop-cicd-demo"
BRANCH="main"

# Clon local usado solo para comparar commits
CACHE_REPO="/opt/git-cache/project_repo"

# Carpeta que contendrá SOLO los ficheros a subir a Health Connect
EXPORT_DIR="/projectGit"

# Fichero con el último commit procesado
STATE_FILE="${CACHE_REPO}/.last_sync_commit"

# Limpiar EXPORT_DIR antes de copiar los cambios detectados
CLEAN_EXPORT_DIR="true"

# =========================
# Validaciones
# =========================
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git no está instalado."
  exit 1
fi

mkdir -p "${EXPORT_DIR}"
mkdir -p "$(dirname "${CACHE_REPO}")"

# =========================
# Clonar o actualizar caché
# =========================
if [ ! -d "${CACHE_REPO}/.git" ]; then
  echo "Clonando repositorio en caché..."
  git clone --branch "${BRANCH}" "${REPO_URL}" "${CACHE_REPO}"
else
  echo "Actualizando caché local..."
  git -C "${CACHE_REPO}" fetch origin
  git -C "${CACHE_REPO}" checkout "${BRANCH}"
  git -C "${CACHE_REPO}" reset --hard "origin/${BRANCH}"
fi

REMOTE_COMMIT="$(git -C "${CACHE_REPO}" rev-parse HEAD)"

# =========================
# Primera ejecución
# =========================
if [ ! -f "${STATE_FILE}" ]; then
  echo "Primera ejecución."
  echo "Copiando todo el contenido actual del branch a ${EXPORT_DIR}..."

  if [ "${CLEAN_EXPORT_DIR}" = "true" ]; then
    find "${EXPORT_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  fi

  rsync -av --delete --exclude ".git" "${CACHE_REPO}/" "${EXPORT_DIR}/"

  echo "${REMOTE_COMMIT}" > "${STATE_FILE}"
  echo "Primera exportación completada."
  exit 0
fi

LAST_COMMIT="$(cat "${STATE_FILE}")"

if [ "${LAST_COMMIT}" = "${REMOTE_COMMIT}" ]; then
  echo "No hay cambios nuevos."
  exit 0
fi

echo "Comparando commits:"
echo "  anterior: ${LAST_COMMIT}"
echo "  actual:   ${REMOTE_COMMIT}"

if [ "${CLEAN_EXPORT_DIR}" = "true" ]; then
  echo "Limpiando carpeta de exportación..."
  find "${EXPORT_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

# =========================
# Exportar solo archivos A/M/R
# =========================
while IFS= read -r -d '' status && IFS= read -r -d '' path1; do
  case "${status}" in
    M|A)
      echo "Exportando ${status}: ${path1}"
      mkdir -p "${EXPORT_DIR}/$(dirname "${path1}")"
      cp -f "${CACHE_REPO}/${path1}" "${EXPORT_DIR}/${path1}"
      ;;

    D)
      # Ignoramos borrados
      echo "Ignorando borrado: ${path1}"
      ;;

    R*)
      IFS= read -r -d '' path2
      echo "Exportando renombrado: ${path1} -> ${path2}"
      mkdir -p "${EXPORT_DIR}/$(dirname "${path2}")"
      cp -f "${CACHE_REPO}/${path2}" "${EXPORT_DIR}/${path2}"
      ;;

    *)
      echo "Cambio no manejado automáticamente: ${status} ${path1}"
      ;;
  esac
done < <(git -C "${CACHE_REPO}" diff --name-status -z "${LAST_COMMIT}" "${REMOTE_COMMIT}")

echo "${REMOTE_COMMIT}" > "${STATE_FILE}"
echo "Exportación incremental completada en ${EXPORT_DIR}"echo "Iniciando carga y compilación de ficheros a Health Connect"
(echo '_system'; echo 'SYS'; cat iris.script) | iris session IRISHEALTH
echo "Compilación concluida con éxito"

