#!/usr/bin/env bash
# 1회성: SP1Helios 컨트랙트 배포 시 필요한 genesis 파라미터 생성
# Sepolia 비콘체인의 특정 slot을 기준점으로 InitParams 만들기
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVFILE="${1:-$ROOT/prover/config/metadium-testnet.env}"

if [ ! -f "$ENVFILE" ]; then
  echo "Error: env file not found: $ENVFILE"
  echo "Copy prover/env.example → prover/config/metadium-testnet.env and fill in values."
  exit 1
fi

set -a; . "$ENVFILE"; set +a

cd "$ROOT/vendor/sp1-helios/script"
cargo run --release --bin genesis -- \
  --source-chain-id "${SOURCE_CHAIN_ID}" \
  --source-consensus-rpc "${SOURCE_CONSENSUS_RPC}"

echo "✓ genesis.json 생성됨 (vendor/sp1-helios/script/)"
echo "  → contracts/script/Deploy.s.sol 에서 이 값을 사용해 SP1Helios 배포"
