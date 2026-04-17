# 배포 가이드

## 토폴로지

| 역할 | 서버 | 접속 |
|------|------|------|
| 개발/스캐폴딩 | mini-jsong (31) | `ssh jsong@10.150.255.31` |
| CI/CD runner | jsong-cicd-01 (156) | `ssh jsong@10.150.254.156` |
| Prover + Operator | cp-gpusrv-1 (150) | `ssh jsong@192.168.0.150` |
| MVP 서비스 (향후) | jsong-demo-01 (110) | `ssh jsong@10.150.254.110` |

## 배포된 컨트랙트 (Metadium testnet, chainId 12)

| 컨트랙트 | 주소 | 비고 |
|---------|------|------|
| **SP1VerifierPlonk v5.0.0** | `0x57e492c55b6a57e61ad3c71a0e3b94ed4819905f` | PLONK selector `0xd4e8ecd2` |
| **SP1Helios** | `0x0CADa87D92C9067c824f65b41589F1Ec7a9c5A35` | head: 10047680→**10048256** (ZK 검증 통과) |
| Deployer EOA | `0x5Dc65d54DdE087ffa1dFB0A0e5Ce4911974652e0` | guardian 겸용 |

**Phase 1 PoC 검증 완료** (2026-04-16): Sepolia slot 10048256의 consensus가 ZK proof로 Metadium testnet에서 수학적으로 검증됨.

### 이전 배포 (deprecated)

| 컨트랙트 | 주소 | 상태 |
|---------|------|------|
| SP1VerifierGroth16 v6.1.0 | `0xb18d6a81a22be8c2f3fefb0b3a7f10a86c7158ea` | ❌ sp1-sdk v5.2.4는 PLONK 사용, Groth16 selector 불일치 |
| SP1Helios (1차) | `0xEaF9Ceb5da50C7396fa6111aC498ff3a34Be94D7` | ❌ v6.1.0 verifier 연결, genesis stale |
| SP1Helios (2차) | `0xfd5ed476fe824bb07d424958afff995c9869a152` | ❌ v6.1.0 verifier 연결 |

## Metadium testnet 특이사항

- **EVM version**: `paris` 고정 (`foundry.toml`) — testnet은 pre-Camellia 상태라 PUSH0(Shanghai+) 미지원
- **Gas price**: legacy tx, `100 gwei` 명시
- **Chain ID**: 12
- **Sepolia finalized slot**: 항상 epoch의 마지막 slot(mod32=31)에서 찍힘 — operator에 checkpoint 체크 패치 필요

## 컨트랙트 재배포 순서

```bash
cd contracts
set -a && . ../.env.local && set +a
COMMON="--rpc-url $METADIUM_TESTNET_RPC --private-key $DEPLOYER_PRIVATE_KEY --broadcast --legacy --with-gas-price 100000000000"

# Step 1 — PLONK verifier 배포 (1회성)
forge script script/DeployVerifier.s.sol $COMMON

# Step 2 — genesis.json의 .verifier를 위 주소로 수정

# Step 3 — SP1Helios 배포
forge script script/Deploy.s.sol $COMMON
```

## 150번 Operator 배포

### Prover 환경

| 항목 | 값 |
|------|-----|
| GPU | H100 NVL #1 (NVIDIA_VISIBLE_DEVICES=1, Ollama가 GPU 0 점유) |
| SP1_PROVER | cuda |
| SP1 SDK | v5.2.4 (PLONK proof 생성) |
| Rust toolchain | stable (rust-toolchain 파일 제거 필요) |
| build.rs | no-op으로 교체 (pre-built ELF 사용) |

### 배포 명령

```bash
./scripts/deploy-to-150.sh
```

### Operator 패치 사항 (vendor/sp1-helios에 적용)

1. `script/rust-toolchain` 파일 삭제 — stable toolchain 사용
2. `script/build.rs` → `fn main() {}` 로 교체 — pre-built ELF 사용
3. `script/src/operator.rs:69` — checkpoint slot 체크 비활성화 (Sepolia 호환)

### 상태 확인

```bash
ssh jsong@192.168.0.150 'pm2 ls; pm2 logs meta-zkbridge-operator --lines 50 --nostream'

# on-chain head 확인
cast call 0x0CADa87D92C9067c824f65b41589F1Ec7a9c5A35 "head()(uint256)" --rpc-url https://api.metadium.com/dev
```

## Proving 성능 (실측, H100 NVL)

| 단계 | 소요 시간 |
|------|----------|
| prove core | ~78s |
| compress | ~60s |
| shrink | ~0.1s |
| wrap_bn254 | ~1.1s |
| wrap_plonk (Groth16/PLONK) | ~54s |
| **총 proving** | **~3.5분** |
| on-chain verification gas | ~270k gas (testnet에서 실비 무시) |

## Dashboard UI (110번 서버 정적 배포)

`ui/` 는 Metadium testnet RPC를 브라우저에서 직접 조회하는 read-only 대시보드 (vanilla HTML + ethers.js, 백엔드 없음).

### 로컬 프리뷰

```bash
cd ui && python3 -m http.server 8080
# http://localhost:8080
```

### 110번 배포

```bash
./scripts/deploy-ui-to-110.sh
# rsync → jsong@10.150.254.110:/home/jsong/www/meta-zkbridge-ui
# pm2 startOrReload (nginx 불필요, python3 http.server 8080 데몬화)
```

접속:
- LAN: `http://10.150.254.110:8080`
- Tailscale: `http://jsong-demo-01:8080`

### 설정

`ui/app.js` 상단 `CONFIG`:
- `explorer`: Metadium testnet 블록익스플로러 확정되면 URL 기입 → 자동으로 tx/address 링크 활성화
- `pollMs`: 새로고침 주기 (기본 15s)
- `eventLookbackBlocks`: HeadUpdate 이벤트 조회 범위 (기본 20,000 블록 ≈ 5.5시간)

## CI/CD → 자동 배포 (향후)

현재 `deploy-to-150.sh` 는 **수동 실행** 상정. CI 파이프라인에서 자동 배포하려면:
- `main` push 시 `.github/workflows/deploy.yml` 추가
- 156 runner에서 `scripts/deploy-to-150.sh` 실행

자동화 전 manual 배포로 안정화 권장.
