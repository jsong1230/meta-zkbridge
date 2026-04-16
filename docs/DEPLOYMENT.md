# 배포 가이드

## 토폴로지

| 역할 | 서버 | 접속 |
|------|------|------|
| 개발/스캐폴딩 | mini-jsong (31) | `ssh jsong@10.150.255.31` |
| CI/CD runner | jsong-cicd-01 (156) | `ssh jsong@10.150.254.156` |
| PoC 런타임 | jsong-demo-01 (110) | `ssh jsong@10.150.254.110` |

## Metadium testnet 컨트랙트 배포 (mini-jsong 또는 156에서)

### 선행조건

- `.env.local` 에 `DEPLOYER_PRIVATE_KEY`, `METADIUM_TESTNET_RPC` 채워짐
- `contracts/genesis.json` 존재 (이건 prover/genesis.sh 실행 결과)

### Metadium testnet 특이사항

- **EVM version**: `paris` 고정 (`foundry.toml`) — testnet은 pre-Camellia 상태라 PUSH0(Shanghai+) 미지원
- **Gas price**: legacy tx, `100 gwei` 명시 — eth_gasPrice는 80 gwei 반환하나 실제 타임아웃 회피 위해 100 gwei 권장
- **Chain ID**: 12

### 배포 명령

```bash
cd contracts
set -a && . ../.env.local && set +a

COMMON="--rpc-url $METADIUM_TESTNET_RPC --private-key $DEPLOYER_PRIVATE_KEY --broadcast --legacy --with-gas-price 100000000000"

# Step 1 — Groth16 verifier 배포 (1회)
forge script script/DeployVerifier.s.sol $COMMON
# 출력 주소를 genesis.json .verifier 필드에 기입

# Step 2 — SP1Helios 배포
forge script script/Deploy.s.sol $COMMON
# 출력 주소를 prover/config/metadium-testnet.env CONTRACT_ADDRESS 에 기입
```

### 기배포 주소 (2026-04-16)

| 컨트랙트 | 주소 | 배포 tx |
|---------|------|---------|
| SP1VerifierGroth16 (v6.1.0) | `0xb18d6a81a22be8c2f3fefb0b3a7f10a86c7158ea` | `0x95a0c153f4d4b6d341104a568ddbe6a8ffa22721db4ca9a24fb76ac4624340da` |

SP1Helios 는 genesis.json 확보 후 배포 예정.

### 기배포 주소 — SP1Helios (2026-04-16)

| 컨트랙트 | 주소 | 배포 tx |
|---------|------|---------|
| SP1Helios | `0xEaF9Ceb5da50C7396fa6111aC498ff3a34Be94D7` | Deploy.s.sol via forge script |

온체인 검증:
- `head()` = 10047488 (Sepolia slot)
- `guardian()` = `0x5Dc65d54DdE087ffa1dFB0A0e5Ce4911974652e0` (deployer)
- `sourceChainId` = 11155111 (Sepolia)
- verifier = `0xb18d6a81a22be8c2f3fefb0b3a7f10a86c7158ea` (SP1VerifierGroth16)

### 목검증기 모드 (ZK 검증 skip, 파이프라인 테스트용)

```bash
MOCK=1 forge script script/Deploy.s.sol \
  --rpc-url $METADIUM_TESTNET_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```
`genesis.json` 의 `.verifier` 가 `0x0` 일 때만 동작.

## 110번 Operator 배포

### 초기 1회성 준비 (사용자 수동)

**110번에 prover 설정 파일을 만들어 둬야 함** (private key 포함이라 자동 배포하지 않음):

```bash
ssh jsong@10.150.254.110 '
  mkdir -p /home/jsong/deploy/meta-zkbridge/prover/config
  nano /home/jsong/deploy/meta-zkbridge/prover/config/metadium-testnet.env
'
# prover/env.example 내용을 참고해 실제 값 채우기
# 특히: CONTRACT_ADDRESS (컨트랙트 배포 후), PRIVATE_KEY, NETWORK_PRIVATE_KEY
```

### 배포 명령

mini-jsong(31) 또는 156 runner 어디서든:

```bash
./scripts/deploy-to-110.sh
```

하는 일:
1. 110에 Rust + SP1 toolchain 설치 (이미 있으면 스킵)
2. `/home/jsong/deploy/meta-zkbridge` 에 repo 동기화 (git clone/pull)
3. `scripts/setup.sh` 실행 — vendor/sp1-helios 클론 + forge deps 설치
4. `prover/config/metadium-testnet.env` 존재 확인
5. PM2 `startOrReload` — `meta-zkbridge-operator` 프로세스 갱신

### 상태 확인

```bash
ssh jsong@10.150.254.110 'pm2 ls; pm2 logs meta-zkbridge-operator --lines 50 --nostream'
```

### PM2 기존 서비스와 병렬 운영

110번엔 이미 `meta-agents`, `metapool`, `metalotto` 3개가 돌고 있음. `meta-zkbridge-operator` 는 4번째로 추가되며 포트 충돌 없음 (operator는 outbound-only, listen port 없음).

## CI/CD → 자동 배포 (향후)

현재 `deploy-to-110.sh` 는 **수동 실행** 상정. CI 파이프라인에서 자동 배포하려면:
- `main` push 시 `.github/workflows/deploy.yml` 추가
- 156 runner에서 `scripts/deploy-to-110.sh` 실행
- 110 SSH key는 156 runner의 `~/.ssh/` 에 배치

자동화 전 manual 배포로 1~2차 검증 권장.
