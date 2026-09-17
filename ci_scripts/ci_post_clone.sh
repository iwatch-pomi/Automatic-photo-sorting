#!/bin/sh
set -e

# Xcode Cloud の環境変数から Secrets.xcconfig を自動生成するスクリプト。
# ローカルでは Secrets.xcconfig を手動作成するため、このスクリプトは CI 環境でのみ実行される。
# App Store Connect → Xcode Cloud → Environment Variables に以下を登録しておくこと:
#   REVENUECAT_API_KEY         (シークレット設定を有効にすること)
#   GAD_APPLICATION_IDENTIFIER (AdMob アプリ ID。ca-app-pub-XXXX~YYYY 形式。未設定時はテストIDにフォールバック)
#   GAD_BANNER_UNIT_ID         (本番バナー広告ユニットID。任意)
#   GAD_INTERSTITIAL_UNIT_ID   (本番インタースティシャル広告ユニットID。任意)
# ※ AdMob の App ID・広告ユニットID は秘密情報ではないが、設定管理のため env で注入する。
# ※ Xcode Cloud は "CI_" で始まる変数名を予約しているため使用不可。

XCCONFIG_PATH="${CI_PRIMARY_REPOSITORY_PATH}/ClassSnap/Config/Secrets.xcconfig"

# AdMob App ID が未設定だと SDK 初期化時にクラッシュするため、Google 公式テスト App ID にフォールバックする。
GAD_APP_ID="${GAD_APPLICATION_IDENTIFIER:-ca-app-pub-3940256099942544~1458002511}"

echo "ci_post_clone: Secrets.xcconfig を生成します..."
echo "  出力先: ${XCCONFIG_PATH}"

# 親ディレクトリが存在しない場合は作成
mkdir -p "$(dirname "${XCCONFIG_PATH}")"

# 既存ファイルを上書きして生成
cat > "${XCCONFIG_PATH}" << EOF
// このファイルは ci_post_clone.sh によって自動生成されました。
// 手動で編集しないでください。
REVENUECAT_API_KEY = ${REVENUECAT_API_KEY}
GAD_APPLICATION_IDENTIFIER = ${GAD_APP_ID}
GAD_BANNER_UNIT_ID = ${GAD_BANNER_UNIT_ID}
GAD_INTERSTITIAL_UNIT_ID = ${GAD_INTERSTITIAL_UNIT_ID}
EOF

echo "ci_post_clone: Secrets.xcconfig の生成が完了しました。"

# --- Swift Package の解決 ---
# Xcode Cloud のビルド（archive）は自動パッケージ解決が無効で、Package.resolved が
# 完全・最新でないと「out-of-date resolved file」エラーで停止する。
# 依存を追加/更新した際に手元で Package.resolved を再生成できない場合に備え、
# ここで明示的に解決して最新の Package.resolved を生成しておく（明示解決は無効設定の対象外）。
echo "ci_post_clone: Swift Package を解決します..."
xcodebuild -resolvePackageDependencies \
  -project "${CI_PRIMARY_REPOSITORY_PATH}/ClassSnap.xcodeproj" \
  -scheme ClassSnap
echo "ci_post_clone: Swift Package の解決が完了しました。"
