#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
ADDON_DIR=${SCRIPT_DIR:h}
CACHE_DIR=${EASYACHIEVEMENT_CACHE_DIR:-${SCRIPT_DIR}/.cache}
PYTHON_BIN=${PYTHON_BIN:-python3}
USER_AGENT="EasyAchievement reward database updater"

BUILD=${1:-}
if [[ -z "${BUILD}" ]]; then
    mkdir -p "${CACHE_DIR}"
    BUILDS_JSON="${CACHE_DIR}/builds.json"
    curl -L --fail --silent --show-error --retry 3 \
        -A "${USER_AGENT}" "https://wago.tools/api/builds" \
        -o "${BUILDS_JSON}.tmp"
    mv "${BUILDS_JSON}.tmp" "${BUILDS_JSON}"
    BUILD=$("${PYTHON_BIN}" - "${BUILDS_JSON}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    builds = json.load(handle).get("wow", [])
builds = [row for row in builds if not row.get("is_bgdl")]
if not builds:
    raise SystemExit("wago.tools did not return a retail build")
print(max(builds, key=lambda row: row.get("created_at", ""))["version"])
PY
    )
fi

BUILD_DIR="${CACHE_DIR}/${BUILD}"
LOCALIZED_TABLES=(Achievement BattlePetSpecies Creature Mount Toy HouseDecor ItemSparse TransmogSet)
COMMON_TABLES=(RetroactiveDecorReward ItemEffect ItemXItemEffect ItemModifiedAppearance TransmogSetItem)

download_table() {
    local table=$1
    local locale=$2
    local destination=$3
    mkdir -p "${destination:h}"
    echo "Downloading ${table} (${locale})"
    curl -L --fail --silent --show-error --retry 3 \
        -A "${USER_AGENT}" \
        "https://wago.tools/db2/${table}/csv?build=${BUILD}&locale=${locale}" \
        -o "${destination}.tmp"
    mv "${destination}.tmp" "${destination}"
}

for locale in enUS zhCN; do
    for table in ${LOCALIZED_TABLES[@]}; do
        download_table "${table}" "${locale}" \
            "${BUILD_DIR}/${locale}/${table}.csv"
    done
done

for table in ${COMMON_TABLES[@]}; do
    download_table "${table}" enUS \
        "${BUILD_DIR}/common/${table}.csv"
done

"${PYTHON_BIN}" "${SCRIPT_DIR}/build_reward_database.py" \
    --input "${BUILD_DIR}" \
    --output "${ADDON_DIR}/Data/AchievementRewardDatabase.lua" \
    --unresolved "${BUILD_DIR}/unresolved-model-rewards.csv" \
    --build "${BUILD}"

echo "Generated Data/AchievementRewardDatabase.lua"
echo "Review unresolved candidates at ${BUILD_DIR}/unresolved-model-rewards.csv"
