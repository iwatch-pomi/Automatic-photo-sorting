#!/bin/sh
set -e

# Xcode Cloud の環境変数から Secrets.xcconfig を自動生成するスクリプト。
# ローカルでは Secrets.xcconfig を手動作成するため、このスクリプトは CI 環境でのみ実行される。
# App Store Connect → Xcode Cloud → Environment Variables に以下を登録しておくこと:
#   CI_REVENUECAT_API_KEY  (シークレット設定を有効にすること)

XCCONFIG_PATH="${CI_PRIMARY_REPOSITORY_PATH}/ClassSnap/Config/Secrets.xcconfig"

echo "ci_post_clone: Secrets.xcconfig を生成します..."
echo "  出力先: ${XCCONFIG_PATH}"

# 親ディレクトリが存在しない場合は作成
mkdir -p "$(dirname "${XCCONFIG_PATH}")"

# 既存ファイルを上書きして生成
cat > "${XCCONFIG_PATH}" << EOF
// このファイルは ci_post_clone.sh によって自動生成されました。
// 手動で編集しないでください。
REVENUECAT_API_KEY = ${CI_REVENUECAT_API_KEY}
EOF

echo "ci_post_clone: Secrets.xcconfig の生成が完了しました。"
