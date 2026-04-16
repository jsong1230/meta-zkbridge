# Succinct Prover Network — 설정 가이드

Phase 1 PoC에서 SP1 proof 생성에 위탁할 **Succinct Prover Network** 온보딩 절차.

## 왜 이 네트워크를 쓰는가

- Phase 1은 단순성 우선 → 자체 H100 hosting 세팅 부담 회피
- mainnet 운영 서비스 (2025년 8월 론칭)
- 결제: USDC 예치 또는 PROVE 토큰. proof 생성 시 실사용량만큼 차감

## 환경변수 (최종 목표)

`.env.local`에 채워야 할 값:

```bash
SP1_PROVER=network
NETWORK_RPC_URL=https://rpc.succinct.xyz/
NETWORK_PRIVATE_KEY=0x...   # Succinct 네트워크용 별도 EOA (중요: 지갑 분리)
```

## 셋업 절차 (사용자 액션 필요)

### 1. 전용 dev wallet 생성
mainnet 자금이 없는 별도 EOA를 만들어 사용. 이미 DEPLOYER 키와 분리할 것.

```bash
~/.foundry/bin/cast wallet new
```

**주의:** Metadium testnet 배포용(`DEPLOYER_PRIVATE_KEY`)과 Prover Network용은 **다른 키로 분리**한다. 혹시 Succinct 측에서 서명 요청을 잘못 남기거나 탈취되더라도 브릿지 배포 계정에 영향이 없도록.

### 2. Succinct 공식 포털 가입
URL: https://docs.succinct.xyz → Developers 섹션 / 또는 https://www.succinct.xyz/

가입 시 위에서 만든 dev wallet 주소를 연결.

### 3. 크레딧 충전
두 가지 방법:

| 방법 | 설명 |
|------|------|
| **USDC 예치** | Succinct 네트워크 컨트랙트에 USDC 보내 credit으로 전환. PoC 시작엔 **$20~$50** 정도로 충분할 것 (proof 몇 회 실험용) |
| **PROVE 토큰 예치** | 거래소(MEXC, Coinbase 등)에서 PROVE 구매 → Succinct 네트워크에 예치 |

초기 PoC엔 USDC가 더 편함. PROVE는 토큰 가격 변동 리스크 존재.

### 4. `.env.local` 업데이트
```bash
SP1_PROVER=network
NETWORK_RPC_URL=https://rpc.succinct.xyz/
NETWORK_PRIVATE_KEY=0x<위에서 만든 dev wallet private key>
```

### 5. 테스트 proof 1회 생성
SP1 CLI나 Rust 스크립트로 간단한 프로그램 실행 → proof 요청 → credit 차감 확인.

공식 예제: https://github.com/succinctlabs/sp1/tree/main/examples

## 비용 모니터링 권장

- Succinct 대시보드에서 잔액 수시 확인
- 테스트용 월 예산 가드레일 설정 (예: $50/월)
- proof 주기를 늦춰 비용 제어 가능 (epoch 단위 → sync committee period 단위)

## 정리

- **가입 + 충전은 사용자 액션 필요** (자동화 불가, 브라우저에서 직접)
- 설정 완료 후 `.env.local` 값만 알려주면 코드 쪽은 바로 연동 가능
- 개발 초기는 `SP1_PROVER=mock` 으로 완전 무료 로직 검증 → 검증 끝나면 `network` 전환

## 참고

- [Succinct Docs](https://docs.succinct.xyz/)
- [SP1 예제](https://github.com/succinctlabs/sp1/tree/main/examples)
- [SP1 Hypercube mainnet 공지](https://blog.succinct.xyz/sp1-hypercube-is-now-live-on-mainnet/)
- [첫 proof 생성 가이드 (커뮤니티)](https://awesamarth.hashnode.dev/how-to-generate-your-first-proof-on-succinct-network)
