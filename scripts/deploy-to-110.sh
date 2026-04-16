#!/usr/bin/env bash
# meta-zkbridge — 110번 (jsong-demo-01) 배포 스크립트
# mini-jsong(31) 또는 156 CI/CD runner에서 실행
set -euo pipefail

TARGET_USER="jsong"
TARGET_HOST="10.150.254.110"
TARGET_DIR="/home/jsong/deploy/meta-zkbridge"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/aws-jsong-nopass.pem}"
REPO_URL="${REPO_URL:-https://github.com/jsong1230/meta-zkbridge.git}"
BRANCH="${BRANCH:-main}"

SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
ssh() { command ssh $SSH_OPTS "$@"; }

echo "==> [1/5] Ensure Rust toolchain on 110"
ssh "$TARGET_USER@$TARGET_HOST" '
  if ! command -v cargo >/dev/null 2>&1; then
    curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
  fi
  source "$HOME/.cargo/env"
  if ! command -v sp1up >/dev/null 2>&1; then
    curl -L https://sp1up.succinct.xyz | bash
  fi
  export PATH="$HOME/.sp1/bin:$HOME/.cargo/bin:$PATH"
  if ! command -v cargo-prove >/dev/null 2>&1; then
    sp1up
  fi
  cargo --version && cargo prove --version
'

echo "==> [2/5] Sync code to 110"
ssh "$TARGET_USER@$TARGET_HOST" "
  mkdir -p '$(dirname $TARGET_DIR)' ~/logs
  if [ ! -d '$TARGET_DIR/.git' ]; then
    git clone '$REPO_URL' '$TARGET_DIR'
  fi
  cd '$TARGET_DIR' && git fetch --all && git checkout '$BRANCH' && git reset --hard 'origin/$BRANCH'
"

echo "==> [3/5] Setup vendor + prover deps on 110"
ssh "$TARGET_USER@$TARGET_HOST" "
  cd '$TARGET_DIR'
  bash scripts/setup.sh
"

echo "==> [4/5] Verify prover config exists (110 local file)"
ssh "$TARGET_USER@$TARGET_HOST" "
  if [ ! -f '$TARGET_DIR/prover/config/metadium-testnet.env' ]; then
    echo 'ERROR: prover/config/metadium-testnet.env missing on 110.'
    echo 'Copy prover/env.example there and fill in CONTRACT_ADDRESS, PRIVATE_KEY, NETWORK_PRIVATE_KEY.'
    exit 1
  fi
"

echo "==> [5/5] PM2 reload"
ssh "$TARGET_USER@$TARGET_HOST" "
  cd '$TARGET_DIR'
  pm2 startOrReload deploy/ecosystem.config.js --update-env
  pm2 save
  pm2 ls
"

echo "✓ 110 배포 완료. 로그: ssh $TARGET_USER@$TARGET_HOST 'pm2 logs meta-zkbridge-operator'"
