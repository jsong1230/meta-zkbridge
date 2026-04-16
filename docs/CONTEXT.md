# Context: 이 프로젝트가 시작된 배경

## 상위 목표

**메타디움 생태계 활성화.** CTO Jeffrey Song이 설정한 최상위 목표.

## 메타디움 현황 (2026-04)

- 시가총액 $16M, META $0.0094, 100만+ 지갑
- DID 특허 93건, MyKeepin 운영 중
- Camellia Hard Fork (geth v1.13.14 기반) 검증 완료, 배포 전 단계
- "기술은 준비됐지만 쓰는 사람이 적다"는 것이 핵심 문제

## 기존 testnet 서비스 (jsong-demo-01, 10.150.254.110)

| 서비스 | 포트 | 설명 |
|--------|------|------|
| meta-agents | 3100 | AI 에이전트 DID + 트레이딩 리더보드 |
| MetaLotto | 3300 | META 토큰 온체인 복권 DApp |
| MetaPool | 3200 | META 토큰 Binary 예측 마켓 |

모두 Metadium testnet (chainId 12)에 배포. PM2로 운영.

## 생태계 확장 아이디어

현 3개 서비스 위에 추가로:
1. **Meta Portal** — 통합 대시보드
2. **MetaBadge** — 크로스서비스 업적 NFT
3. **MetaSwap** — 간단한 DEX
4. **meta-zkbridge** — **이 프로젝트** (탈중앙 bridge)

우선순위: 4번(zkBridge)부터 착수. 이유는 다른 체인 자산의 메타디움 유입 인프라가 되기 때문.

## 왜 "진짜" 탈중앙 bridge인가

CTO 질문: "탈중앙화된 bridge 없을까?"

답변: 대부분의 기존 bridge는 multisig/federation 의존. 진짜 탈중앙은 zk-bridge뿐. 자세한 비교는 `DESIGN.md` 참조.

**차별화 포인트:** "한국 퍼블릭 체인 중 자체 zk-bridge를 갖는 것"은 메타디움만의 기술적 차별화가 될 수 있음.

## 관련 인프라

- **go-metadium**: camellia 브랜치 운영 중 (geth v1.13.14, Cancun EIPs)
- **CI/CD**: jsong-cicd-01 (10.150.254.156) — GitHub Actions self-hosted runner
- **서비스 호스트**: jsong-demo-01 (10.150.254.110) — PM2 기반 Node.js 서비스
- **GPU 서버**: 150/151 — SP1 프로버 실행 가능

## 참고 세션

이 문서는 claude-agent (개인비서 세션)에서 2026-04-15~16 사이 논의한 내용을 정리한 것.

실제 개발은 meta-zkbridge 리포에서 별도 세션으로 진행 예정.
