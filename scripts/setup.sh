#!/usr/bin/env bash
# meta-zkbridge — 개발 환경 초기 세팅
# 신규 클론 직후 1회 실행
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> 1/3: sp1-helios upstream 클론 (vendor/)"
if [ ! -d vendor/sp1-helios ]; then
  mkdir -p vendor
  git clone --depth 1 https://github.com/succinctlabs/sp1-helios.git vendor/sp1-helios
else
  echo "vendor/sp1-helios 이미 존재. 스킵."
fi

echo "==> 2/3: Foundry 의존성 설치"
if [ ! -d contracts/lib/forge-std ] || [ ! -d contracts/lib/sp1-contracts ]; then
  (cd contracts && ~/.foundry/bin/forge install --no-git --shallow foundry-rs/forge-std succinctlabs/sp1-contracts)
else
  echo "contracts/lib 이미 세팅됨. 스킵."
fi

echo "==> 3/3: build sanity check"
(cd contracts && ~/.foundry/bin/forge build --silent)

echo "✓ 설정 완료. 다음 할 일:"
echo "  - .env.local 파일에 RPC URL·private key 채우기"
echo "  - docs/PROVER_NETWORK_SETUP.md 절차 따라 Succinct 계정 생성"
