# meta-zkbridge

## 프로젝트
Metadium ZK 기반 탈중앙화 cross-chain bridge (Succinct SP1-Helios)

## 기술 스택
- Prover: Rust + Succinct SP1
- Contracts: Solidity ^0.8.24
- Target: Metadium testnet (chainId 12) ↔ Sepolia

## 디렉토리 (계획)
- `prover/` — Rust SP1 prover 프로그램
- `contracts/` — Solidity verifier 컨트랙트
- `relayer/` — off-chain relay (Rust)
- `docs/` — 설계 문서

## Phase
- Phase 1: Ethereum → Metadium 단방향 PoC
- Phase 2: 양방향
- Phase 3: 토큰 브릿지 (lock/mint)

## 참고
- 상위 프로젝트: meta-agents, MetaLotto, MetaPool (110번 서버 testnet)
- CI/CD: jsong-cicd-01
