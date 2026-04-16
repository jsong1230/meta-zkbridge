# meta-zkbridge

Metadium ZK-based trustless cross-chain bridge powered by Succinct SP1-Helios.

## 목표

- **Trustless**: multisig/validator 신뢰 불필요 — 수학적 검증만으로 동작
- **Bidirectional**: Ethereum ↔ Metadium 양방향 메시지/토큰 전달
- **Open source**: MIT 라이선스, 누구나 검증·배포 가능

## 아키텍처

```
Ethereum (source)          Metadium (destination)
      ↓                            ↑
  블록/상태                    증명 검증
      ↓                            ↑
  SP1-Helios Prover ─── ZK proof ───┐
  (Rust, off-chain)                 │
                                    │
  Metadium Verifier 컨트랙트 ←──────┘
  (Solidity on Metadium)
```

## 로드맵

### Phase 1: PoC — 단방향 (Ethereum → Metadium)
- SP1-Helios Ethereum light client 배포
- Metadium testnet에 Verifier 컨트랙트 배포
- Sepolia → Metadium testnet ZK 메시지 전달 검증

### Phase 2: 양방향
- Metadium PoA light client (Rust 작성)
- Ethereum에 배포
- 양방향 메시지 전달

### Phase 3: 토큰 브릿지
- Lock/Mint 로직 추가
- META ↔ wrapped META (ETH)

## 기술 스택

- **Prover**: Rust + Succinct SP1
- **Contracts**: Solidity ^0.8.24
- **Light Client**: Helios (Ethereum) + 커스텀 (Metadium PoA)
- **Target Chains**: Metadium testnet (12) / Sepolia

## 참고

- [Succinct SP1](https://blog.succinct.xyz/introducing-sp1/)
- [SP1-Helios](https://github.com/succinctlabs/sp1-helios)
- [Gnosis Hashi × SP1](https://www.gnosis.io/blog/succincts-ethereum-zk-light-client-and-the-road-to-trust-minimzed-bridges-with-hashi)

## 라이선스

MIT
