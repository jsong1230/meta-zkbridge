#!/usr/bin/env bash
# SP1-Helios operator 데몬 — Sepolia → Metadium testnet
# 150번 서버(H100 GPU)에서 PM2로 상시 실행
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVFILE="${1:-$ROOT/prover/config/metadium-testnet.env}"

if [ ! -f "$ENVFILE" ]; then
  echo "Error: env file not found: $ENVFILE"
  echo "Copy prover/env.example → prover/config/metadium-testnet.env and fill in values."
  exit 1
fi

# shellcheck disable=SC1090
set -a; . "$ENVFILE"; set +a

# 필수 검증
: "${CONTRACT_ADDRESS:?CONTRACT_ADDRESS not set — deploy SP1Helios first}"
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"
: "${SP1_PROVER:?SP1_PROVER not set (mock|local|cuda|network)}"

# PATH 보장 (PM2 systemd 환경에선 cargo/foundry가 PATH에 없을 수 있음)
export PATH="$HOME/.cargo/bin:$HOME/.sp1/bin:$HOME/.foundry/bin:$PATH"

# GPU 격리: CUDA_VISIBLE_DEVICES 가 env에 설정돼 있으면 export
if [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
  export CUDA_VISIBLE_DEVICES
  echo "Using GPU device(s): $CUDA_VISIBLE_DEVICES"
fi

# SP1 prover 모드 전달
export SP1_PROVER
export SP1_SKIP_PROGRAM_BUILD=true   # pre-built ELF 사용, 소스 재컴파일 방지
export RUSTUP_TOOLCHAIN=stable       # rust-toolchain 파일 무시, stable 사용

cd "$ROOT/vendor/sp1-helios/script"

cargo run --release --bin operator -- \
  --rpc-url "${DEST_RPC_URL}" \
  --contract-address "${CONTRACT_ADDRESS}" \
  --source-chain-id "${SOURCE_CHAIN_ID}" \
  --source-consensus-rpc "${SOURCE_CONSENSUS_RPC}" \
  --private-key "${PRIVATE_KEY}" \
  --loop-delay-mins "${LOOP_DELAY_MINS:-30}"
