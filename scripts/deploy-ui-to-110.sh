#!/usr/bin/env bash
# meta-zkbridge UI — 110번 (jsong-demo-01) 정적 배포
# python3 -m http.server 를 pm2로 데몬화 (nginx 불필요)
set -euo pipefail

TARGET_USER="jsong"
TARGET_HOST="10.150.254.110"
REMOTE_DIR="${REMOTE_DIR:-/home/jsong/www/meta-zkbridge-ui}"
PM2_CONFIG_REMOTE="${PM2_CONFIG_REMOTE:-/home/jsong/www/meta-zkbridge-ui/ui-ecosystem.config.js}"
PORT="${PORT:-8080}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/aws-jsong-nopass.pem}"

SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_UI="$REPO_ROOT/ui"
LOCAL_PM2_CFG="$REPO_ROOT/deploy/ui-ecosystem.config.js"

echo "==> [1/4] Ensure remote dirs exist on $TARGET_HOST"
ssh $SSH_OPTS "$TARGET_USER@$TARGET_HOST" "mkdir -p '$REMOTE_DIR' /home/jsong/logs"

echo "==> [2/4] Rsync ui/ → $TARGET_HOST:$REMOTE_DIR"
rsync -avz --delete -e "ssh $SSH_OPTS" \
  --exclude='.DS_Store' \
  "$LOCAL_UI/" "$TARGET_USER@$TARGET_HOST:$REMOTE_DIR/"

echo "==> [3/4] Copy pm2 ecosystem config"
scp $SSH_OPTS "$LOCAL_PM2_CFG" "$TARGET_USER@$TARGET_HOST:$PM2_CONFIG_REMOTE"

echo "==> [4/4] pm2 startOrReload"
ssh $SSH_OPTS "$TARGET_USER@$TARGET_HOST" "
  pm2 startOrReload '$PM2_CONFIG_REMOTE' --update-env
  pm2 save
  pm2 ls
"

cat <<EOF

✓ UI 배포 완료
  - 서버: http://$TARGET_HOST:$PORT
  - Tailscale: http://jsong-demo-01:$PORT (MagicDNS)
  - 로그: ssh jsong@$TARGET_HOST 'pm2 logs meta-zkbridge-ui'
EOF
