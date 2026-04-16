# contracts/

Metadium testnet (chainId 12)에 배포될 SP1-Helios 관련 Solidity 컨트랙트.

## 구성

```
src/SP1Helios.sol              — 이더리움 light client state 저장·업데이트 (upstream 복사)
script/Deploy.s.sol            — SP1Helios 배포 (solc ^0.8.22)
script/DeployVerifier.s.sol    — SP1VerifierGroth16 배포 (solc =0.8.20 고정)
lib/sp1-contracts/             — forge install 의존성
lib/forge-std/                 — forge install 의존성
```

## 배포 흐름 (Metadium testnet)

### Step 1 — Genesis 생성

prover/ 쪽에서 Sepolia 기준점 slot의 파라미터를 뽑아 `genesis.json` 을 생성:

```bash
cd ../prover && ./genesis.sh
cp ../vendor/sp1-helios/script/genesis.json ./contracts/genesis.json
```

### Step 2 — SP1VerifierGroth16 배포 (1회성)

```bash
cd contracts
forge script script/DeployVerifier.s.sol \
  --rpc-url $METADIUM_TESTNET_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```

출력된 verifier 주소를 `genesis.json` 의 `.verifier` 필드에 기입.

### Step 3 — SP1Helios 배포

```bash
forge script script/Deploy.s.sol \
  --rpc-url $METADIUM_TESTNET_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```

출력된 SP1Helios 주소를 `prover/config/metadium-testnet.env` 의 `CONTRACT_ADDRESS` 에 기입.

### Step 3-Alt — 목검증기로 먼저 돌리고 싶을 때

ZK 검증을 스킵한 파이프라인 테스트가 필요하면:

```bash
MOCK=1 forge script script/Deploy.s.sol \
  --rpc-url $METADIUM_TESTNET_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```

`genesis.json` 의 `.verifier` 가 0x0 일 때만 동작. SP1MockVerifier 를 함께 배포.

## 빌드

```bash
forge build
```

`foundry.toml` 에서 solc 버전을 고정하지 않았기 때문에 forge가 파일별 pragma에 따라 필요한 컴파일러를 자동 선택한다 (0.8.20 과 ^0.8.22 혼재).
