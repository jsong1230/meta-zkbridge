# CI/CD 설정

## 토폴로지

| 역할 | 서버 | 비고 |
|------|------|------|
| CI/CD runner | 156 (jsong-cicd-01) | GitHub Actions self-hosted runner |
| 배포 대상 | 110 (jsong-demo-01) | PoC/MVP 런타임 (PM2) |

## 156번에 meta-zkbridge 전용 runner 등록하기 (1회성)

156번에는 이미 **`METADIUM/go-metadium` 전용 runner**가 `~/actions-runner/` 에 등록돼 있음. meta-zkbridge 는 **별도 인스턴스**를 나란히 실행해야 함.

### Step 1 — registration token 발급 (사용자 수동)

https://github.com/jsong1230/meta-zkbridge/settings/actions/runners/new 접속 →
**"Linux / x64"** 선택 → 표시되는 토큰을 복사 (`./config.sh --url … --token AXXXX…` 중 `AXXXX…` 부분)

### Step 2 — 156번에서 신규 runner 인스턴스 생성

```bash
ssh jsong@10.150.254.156

# 별도 디렉토리에 runner 복사 (go-metadium runner 와 분리)
mkdir -p ~/actions-runner-metazkbridge
cd ~/actions-runner-metazkbridge

# 버전은 go-metadium runner 와 동일하게 맞춤 (v2.323.0)
curl -O -L https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-linux-x64-2.323.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.323.0.tar.gz

# label에 'metazkbridge' 포함 — 워크플로가 이 label로 타겟팅
./config.sh \
  --url https://github.com/jsong1230/meta-zkbridge \
  --token <STEP1에서 받은 토큰> \
  --name jsong-cicd-01-metazkbridge \
  --labels metazkbridge \
  --work _work \
  --unattended

# systemd 서비스 등록 (재부팅 후 자동 실행)
sudo ./svc.sh install jsong
sudo ./svc.sh start
sudo ./svc.sh status
```

### Step 3 — 사전 설치 (빌드 속도 개선)

매 CI 실행마다 rustup / foundryup 재설치하면 느리므로 runner 호스트에 pre-install:

```bash
# 156번에서 jsong 계정으로
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Rust (prover 측 체크용)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
```

워크플로의 "Setup Foundry (idempotent)" 단계는 이미 설치돼 있으면 스킵하도록 작성돼 있음.

### Step 4 — 동작 확인

main 브랜치에 push → https://github.com/jsong1230/meta-zkbridge/actions 에서 `CI` 워크플로가 self-hosted runner에서 실행되는지 확인.

## 트러블슈팅

- runner가 pickup 안 됨 → `~/actions-runner-metazkbridge/_diag/*.log` 확인
- label mismatch → 워크플로 `runs-on` 과 runner config의 label 일치 확인 (`metazkbridge`)
- systemd 서비스 이름: `actions.runner.jsong1230-meta-zkbridge.jsong-cicd-01-metazkbridge.service`
