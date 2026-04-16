# meta-zkbridge 설계 문서

## 배경

메타디움 생태계 활성화를 위한 인프라 프로젝트. 기존 메타디움 testnet 서비스(meta-agents, MetaLotto, MetaPool)에 추가로, Ethereum과의 탈중앙화 cross-chain bridge를 구축한다.

### 왜 zk-bridge인가

대부분의 기존 bridge는 multisig 또는 federation 기반으로, 완전한 탈중앙화와는 거리가 멀다. 실제로 대형 해킹 사례도 multisig bridge에서 발생했다.

**주요 bridge 해킹 사례:**
- Ronin: $625M (multisig key 탈취)
- Multichain: $126M (multisig 운영자 문제)
- Nomad: $190M (optimistic bridge 로직 결함)

완전 탈중앙화된 bridge를 만들려면 **ZK 증명을 통해 상대 체인의 상태를 수학적으로 검증**하는 방식이 필요하다.

## Bridge 방식 비교

| 방식 | 탈중앙화 | 자체 구축 | 비용/난이도 | 비고 |
|------|---------|----------|------------|------|
| Succinct SP1-Helios | 높음 | 가능 (MIT) | 중~상 | **채택** |
| Polyhedra zkBridge | 높음 | 불가 (상업) | 협의 | 기성품 |
| LayerZero | 낮음~중 | 부분 | 낮음 | multisig 의존 |
| Wormhole | 중 | 부분 | 낮음 | 19 Guardian |
| Axelar | 중~높음 | 부분 | 중 | PoS validator 75+ |
| ChainBridge | 낮음 | 가능 | 낮음 | multisig relayer |

## 선택: Succinct SP1-Helios

**선택 이유:**
1. MIT 라이선스, 완전 오픈소스 — 자체 구축·수정 가능
2. Ethereum light client을 ZK로 증명 → 메타디움에 단일 Verifier 컨트랙트만 필요
3. SP1 Hypercube로 Ethereum 블록 증명이 12초 이내
4. 이미 IoTeX, Gnosis 등이 채택해 검증된 방식

**기술적 원리:**
- Helios: Rust로 작성된 portable Ethereum light client
- SP1: Rust 프로그램을 ZK 증명으로 변환하는 zkVM
- SP1-Helios: Helios의 consensus 검증 로직을 SP1로 증명 → 이 증명을 상대 체인에서 검증

## 아키텍처

```
┌───────────────────┐                  ┌──────────────────────┐
│   Ethereum        │                  │   Metadium           │
│   (source)        │                  │   (destination)      │
│                   │                  │                      │
│   Block + State   │                  │   Verifier Contract  │
└─────────┬─────────┘                  │   (Solidity)         │
          │                            └──────────▲───────────┘
          │ 블록 헤더 / 상태                         │
          ▼                                        │
┌───────────────────┐                              │
│   SP1-Helios      │                              │
│   Prover          │ ─── ZK proof ────────────────┘
│   (Rust, offline) │
└───────────────────┘
```

### 데이터 흐름

1. **Prover (off-chain)**: Helios로 Ethereum 블록/상태 수신
2. **ZK 증명 생성**: SP1으로 light client consensus 검증을 증명
3. **On-chain 검증**: 증명을 메타디움 Verifier 컨트랙트에 전달
4. **상태 업데이트**: 검증 통과 시 메타디움에서 "이더리움 상태 X가 유효함" 확정

## 로드맵

### Phase 1: PoC — 단방향 (Ethereum → Metadium)
**목표**: Sepolia testnet의 특정 상태를 Metadium testnet에서 증명 가능

**작업:**
- SP1-Helios 프로버 구축 (Rust)
- Metadium Verifier 컨트랙트 (Solidity)
- Sepolia 상태 → Metadium 전달 검증
- Relayer 기본 스크립트

**성공 기준:**
- Sepolia 블록 1개의 상태 root를 Metadium에서 검증 통과

### Phase 2: 양방향
**목표**: Metadium → Ethereum 방향도 구축

**작업:**
- Metadium PoA light client Rust 구현
- Ethereum용 Metadium Verifier 컨트랙트
- 양방향 메시지 전달

**난이도 포인트:**
- 메타디움은 PoA (Proof of Authority) 기반 → Ethereum PoS와는 consensus 검증 로직이 완전히 다름
- Metadium governance contract 기반 validator 집합 변경을 증명해야 함

### Phase 3: 토큰 브릿지
**목표**: META ↔ wrapped META (ETH)

**작업:**
- Lock/Mint 로직 컨트랙트
- META (Metadium native) → wMETA (Ethereum ERC-20)
- 역방향: wMETA burn → META unlock

## 기술 스택

| 레이어 | 기술 |
|--------|------|
| Prover | Rust + Succinct SP1 |
| Smart Contracts | Solidity ^0.8.24 + Foundry |
| Light Client (Eth) | Helios (succinctlabs) |
| Light Client (Metadium) | 커스텀 Rust 구현 (Phase 2) |
| Relayer | Rust 또는 TypeScript |
| Target Chains | Metadium testnet (12), Sepolia |

## 배포 & 실행 환경

### 배포 대상
- **PoC/MVP 배포**: jsong-demo-01 (10.150.254.110) — 기존 meta-agents·그날과 함께 운영
  - Verifier 컨트랙트는 Metadium testnet에 배포, off-chain 컴포넌트(relayer·API 등)는 110번에 호스팅
- CI/CD: jsong-cicd-01 (10.150.254.156) — GitHub Actions self-hosted runner

### SP1 Prover 실행 전략 (Phase 1)

**원칙: PoC 단순성 우선.** 자체 prover 인프라 구축보다 외부 위탁으로 기능 검증에 집중.

| 단계 | Prover 모드 | 비용 | 목적 |
|------|------------|------|------|
| 개발 초기 | `MockProver` | 무료 (오프라인) | 파이프라인 로직 검증 — Rust program, Solidity verifier, operator 전부 엔드투엔드 연결 |
| PoC 실증 | `NetworkProver` (Succinct Prover Network) | PROVE 토큰 유료 | Sepolia → Metadium testnet 실제 Groth16 proof 생성·검증 |

**NetworkProver 선택 근거:**
- 하드웨어 세팅 부담 제로 (H100 드라이버, CUDA 컨테이너 등 불필요)
- 환경변수 하나로 전환 가능 (`SP1_PROVER=network`)
- Succinct 공식이 non-trivial 프로그램은 network 사용을 "highly recommend"
- Phase 2에서 자체 호스팅이 필요해지면 환경변수만 바꾸면 됨

**비용 관리:**
- 결제: PROVE 토큰 (ETH/USDC 직접 결제 불가)
- 가격 구조: proof contests 옥션 — 요청자가 최대 fee 설정, prover들이 경쟁 bid
- 증명 주기로 운영 비용 제어:
  - 최소: sync committee period마다 (~27시간) → 월 ~27회
  - 실시간 필요 시: 매 epoch(~6.4분) → 월 ~6,750회
  - PoC 단계는 최소 주기로 시작, 필요 시 축소
- 월 예산 가드레일을 설정하고 실제 지출 모니터링 필요

### GPU 활용 검토 결과 (Phase 1에서는 미채택)
- 150/151에 H100 NVL 2장씩(94GB ea, CUDA CC 9.0) 확인 완료 — SP1 요구사양 압도적 상회
- 150은 gmet 제거되어 여유 생겼으나 Ollama·TTS 스택 상주, 151은 vLLM 상시 점유
- Phase 1은 NetworkProver로 진행, **자체 hosting 전환은 Phase 2에서 실측 데이터(비용·지연·점유율) 기반으로 재평가**

### 미확정 이슈
- Succinct Prover Network의 실제 per-proof 비용 (옥션 시장가 실측 필요)
- PROVE 토큰 구매 경로·절차
- Metadium에서 Groth16 verifier 실행 시 gas 비용 (EVM 호환이라 ~270k gas 예상이나 실측 필요)

## 오픈 이슈

1. **메타디움 PoA light client**: 기존 구현체가 없음 → 직접 작성 필요
2. **Validator set 업데이트 증명**: PoA governance contract 기반이라 추가 증명 로직 필요
3. **프로버 운영 주체**: PoC는 우리가 운영, 장기적으로는 다수 독립 프로버 구조
4. **Gas cost**: Metadium에서 ZK proof verification gas 비용 측정 필요

## 참고 자료

- [Succinct SP1 Introduction](https://blog.succinct.xyz/introducing-sp1/)
- [SP1-Helios GitHub](https://github.com/succinctlabs/sp1-helios)
- [SP1 Hypercube — Real-time Ethereum proving](https://www.theblock.co/post/355013/succinct-introduces-zkvm-sp1-hypercube-claims-real-time-ethereum-proving)
- [Gnosis × SP1 Hashi](https://www.gnosis.io/blog/succincts-ethereum-zk-light-client-and-the-road-to-trust-minimzed-bridges-with-hashi)
- [IoTeX ZK Light Client Bridge](https://x.com/iotex_io/status/2037254750505492642)
- [Polyhedra zkBridge Docs](https://docs.zkbridge.com) (참고 아키텍처)
