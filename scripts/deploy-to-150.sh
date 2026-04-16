#!/usr/bin/env bash
# meta-zkbridge — 150번 (cp-gpusrv-1, H100 GPU) operator 배포
# mini-jsong(31) 또는 156 CI/CD runner에서 실행
set -euo pipefail

TARGET_USER="jsong"
TARGET_HOST="192.168.0.150"
TARGET_DIR="/home/jsong/deploy/meta-zkbridge"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/aws-jsong-nopass.pem}"
REPO_URL="${REPO_URL:-https://github.com/jsong1230/meta-zkbridge.git}"
BRANCH="${BRANCH:-main}"

# shellcheck disable=SC2086
ssh_cmd() { command ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$@"; }

echo "==> [1/4] Sync code to 150"
ssh_cmd "$TARGET_USER@$TARGET_HOST" "
  mkdir -p '$(dirname $TARGET_DIR)' ~/logs
  if [ ! -d '$TARGET_DIR/.git' ]; then
    git clone '$REPO_URL' '$TARGET_DIR'
  fi
  cd '$TARGET_DIR' && git fetch --all && git checkout '$BRANCH' && git reset --hard 'origin/$BRANCH'
"

echo "==> [2/4] Setup vendor + deps"
ssh_cmd "$TARGET_USER@$TARGET_HOST" "
  cd '$TARGET_DIR'
  bash scripts/setup.sh
"

echo "==> [3/4] Verify prover config"
ssh_cmd "$TARGET_USER@$TARGET_HOST" "
  if [ ! -f '$TARGET_DIR/prover/config/metadium-testnet.env' ]; then
    echo 'ERROR: prover/config/metadium-testnet.env missing on 150.'
    echo 'Create it from prover/env.example and fill in PRIVATE_KEY.'
    exit 1
  fi
"

echo "==> [4/4] PM2 reload"
ssh_cmd "$TARGET_USER@$TARGET_HOST" "
  export PATH=\"\$HOME/.cargo/bin:\$HOME/.sp1/bin:\$HOME/.foundry/bin:\$PATH\"
  cd '$TARGET_DIR'
  which pm2 >/dev/null 2>&1 || npm install -g pm2
  pm2 startOrReload deploy/ecosystem.config.js --update-env
  pm2 save
  pm2 ls
"

echo "✓ 150 배포 완료. 로그: ssh $TARGET_USER@$TARGET_HOST 'pm2 logs meta-zkbridge-operator'"
