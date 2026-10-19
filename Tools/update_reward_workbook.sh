#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
ADDON_DIR=${SCRIPT_DIR:h}
CACHE_DIR=${EASYACHIEVEMENT_CACHE_DIR:-${SCRIPT_DIR}/.cache}
PYTHON_BIN=${PYTHON_BIN:-python3}
NODE_BIN=${NODE_BIN:-node}
ARTIFACT_MODULES=${ARTIFACT_NODE_MODULES:-${HOME}/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules}
BUILD=${1:-}

if [[ -z "${BUILD}" ]]; then
    BUILD=$(ls -1 "${CACHE_DIR}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
fi
if [[ -z "${BUILD}" || ! -d "${CACHE_DIR}/${BUILD}" ]]; then
    echo "No cached wago.tools build found. Run update_reward_database.sh first." >&2
    exit 1
fi
if [[ ! -d "${ARTIFACT_MODULES}/@oai/artifact-tool" ]]; then
    echo "@oai/artifact-tool was not found. Set ARTIFACT_NODE_MODULES." >&2
    exit 1
fi
if [[ "${NODE_BIN}" == "node" && -x "${HOME}/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node" ]]; then
    NODE_BIN=${HOME}/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT
ln -s "${ARTIFACT_MODULES}" "${TEMP_DIR}/node_modules"
cp "${SCRIPT_DIR}/build_reward_workbook.mjs" "${TEMP_DIR}/build_reward_workbook.mjs"

"${PYTHON_BIN}" "${SCRIPT_DIR}/export_reward_workbook_data.py" \
    --input "${CACHE_DIR}/${BUILD}" \
    --output "${TEMP_DIR}/reward-workbook.json" \
    --build "${BUILD}"

mkdir -p "${ADDON_DIR}/Exports"
"${NODE_BIN}" "${TEMP_DIR}/build_reward_workbook.mjs" \
    "${TEMP_DIR}/reward-workbook.json" \
    "${ADDON_DIR}/Exports/EasyAchievement_奖励成就.xlsx"

echo "Generated Exports/EasyAchievement_奖励成就.xlsx"
