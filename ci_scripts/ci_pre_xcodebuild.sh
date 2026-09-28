#!/bin/sh
set -e

# Xcode Cloud のビルド直前フック。
# アプリ本体とウィジェット拡張（ClassSnapWidgetExtension）の
# ビルド番号（CFBundleVersion）を必ず一致させるためのスクリプト。
#
# 背景:
#   GENERATE_INFOPLIST_FILE=YES のため、CFBundleVersion は各ターゲットの
#   CURRENT_PROJECT_VERSION から生成される。Xcode Cloud のビルド番号自動採番が
#   本体だけに効くと、本体と拡張で CFBundleVersion が食い違い、
#   「Preparing build for App Store Connect failed」で失敗する。
#   そこで全ターゲットの CURRENT_PROJECT_VERSION を同じ値
#   （Xcode Cloud のビルド番号 CI_BUILD_NUMBER）に統一する。

PBXPROJ="${CI_PRIMARY_REPOSITORY_PATH}/ClassSnap.xcodeproj/project.pbxproj"

if [ -z "${CI_BUILD_NUMBER}" ]; then
    echo "ci_pre_xcodebuild: CI_BUILD_NUMBER が未設定のためスキップします。"
    exit 0
fi

if [ ! -f "${PBXPROJ}" ]; then
    echo "ci_pre_xcodebuild: project.pbxproj が見つかりません: ${PBXPROJ}"
    exit 0
fi

echo "ci_pre_xcodebuild: 全ターゲットの CURRENT_PROJECT_VERSION を ${CI_BUILD_NUMBER} に統一します。"
# 本体・ウィジェット両ターゲット（Debug/Release）すべての CURRENT_PROJECT_VERSION を書き換える
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" "${PBXPROJ}"
echo "ci_pre_xcodebuild: 完了。"
