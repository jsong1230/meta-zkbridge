# prover/

Phase 1에서는 **upstream [sp1-helios](https://github.com/succinctlabs/sp1-helios)를 거의 그대로 사용**하고, 이 디렉토리는 Metadium testnet 대상 설정·실행 래퍼만 담는다.

## 왜 자체 Rust 크레이트를 지금 만들지 않나

- sp1-helios는 이미 `source_chain_id` / `rpc_url` / `contract_address` 를 CLI 인자로 받음 → destination을 Metadium으로 바꾸는데 코드 수정 불필요
- Phase 1 목표는 "Sepolia → Metadium 단방향 proof 검증" — 기능 검증에 집중
- Phase 2에서 Metadium PoA light client를 작성할 때 이 디렉토리에 Cargo workspace 신설 예정

## 구성

```
prover/
├── README.md                   이 파일
├── env.example                 필수 env 템플릿
├── genesis.sh                  1회성: 초기 상태 genesis 생성
├── run-operator.sh             상시: Sepolia 폴링 → proof 생성 → Metadium에 전송
└── config/
    └── metadium-testnet.env    우리 배포 환경 값
```

## 실행 순서

1. `contracts/` 에서 `SP1Helios.sol` + `SP1Verifier` 를 Metadium testnet에 배포 → 컨트랙트 주소 확보
2. `prover/config/metadium-testnet.env` 에 컨트랙트 주소 + RPC + private key 기입
3. `./genesis.sh` 1회 실행 — sync committee period 초기값 세팅
4. `./run-operator.sh` 데몬 실행 (110번 서버에 PM2로 상시)

## 의존성

- upstream 코드 위치: `../vendor/sp1-helios/` (setup.sh로 clone)
- Rust + SP1 toolchain (rustup + sp1up)
- `$SP1_PROVER=network` 모드로 Succinct Prover Network 사용

## 향후 (Phase 2 이후)

- `prover/metadium-poa/` — Metadium PoA consensus를 SP1 program으로 구현
- `prover/operator/` — 양방향 릴레이 로직 (Ethereum→Metadium + Metadium→Ethereum)
