#!/bin/zsh
set -euo pipefail

ADDON_DIR=${0:A:h:h}
TARGET_DIR="/Applications/World of Warcraft/_retail_/Interface/AddOns/EasyAchievement"

mkdir -p "${TARGET_DIR}"
cp "${ADDON_DIR}/EasyAchievement.toc" "${TARGET_DIR}/EasyAchievement.toc"
for directory in Config Core Data Locales Modules; do
    mkdir -p "${TARGET_DIR}/${directory}"
    rsync -a --exclude='.DS_Store' --include='*/' --include='*.lua' \
        --exclude='*' "${ADDON_DIR}/${directory}/" \
        "${TARGET_DIR}/${directory}/"
done

echo "Synced EasyAchievement runtime files to ${TARGET_DIR}"
