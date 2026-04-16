#!/usr/bin/env bash
# SP1-Helios operator 데몬 — Sepolia → Metadium testnet
# 110번 서버에서 PM2로 상시 실행 상정
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVFILE="${1:-$ROOT/prover/config/metadium-testnet.env}"

if [ ! -f "$ENVFILE" ]; then
  echo "Error: env file not found: $ENVFILE"
  echo "Copy prover/env.example → prover/config/metadium-testnet.env and fill in values."
  exit 1
fi

set -a; . "$ENVFILE"; set +a

# 필수 검증
: "${CONTRACT_ADDRESS:?CONTRACT_ADDRESS not set — deploy SP1Helios first}"
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"
: "${SP1_PROVER:?SP1_PROVER not set (mock|local|network)}"

cd "$ROOT/vendor/sp1-helios/script"

# SP1 prover 모드 전달
export SP1_PROVER NETWORK_RPC_URL NETWORK_PRIVATE_KEY

cargo run --release --bin operator -- \
  --rpc-url "${DEST_RPC_URL}" \
  --contract-address "${CONTRACT_ADDRESS}" \
  --source-chain-id "${SOURCE_CHAIN_ID}" \
  --source-consensus-rpc "${SOURCE_CONSENSUS_RPC}" \
  --private-key "${PRIVATE_KEY}" \
  --loop-delay-mins "${LOOP_DELAY_MINS:-30}"
