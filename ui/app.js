import { JsonRpcProvider, Contract, formatUnits } from "https://esm.sh/ethers@6.13.4";

const CONFIG = {
  metadiumRpc: "https://api.metadium.com/dev",
  sepoliaBeacon: "https://ethereum-sepolia-beacon-api.publicnode.com",
  helios: "0x0CADa87D92C9067c824f65b41589F1Ec7a9c5A35",
  verifier: "0x57e492c55b6a57e61ad3c71a0e3b94ed4819905f",
  // Metadium testnet explorer가 확정되면 아래에 채우기 (예: "https://testnetexplorer.metadium.com")
  // 빈 문자열이면 링크 대신 raw hash만 표시
  explorer: "",
  pollMs: 15_000,
  eventLookbackBlocks: 20_000, // Metadium block time ≈1s → 약 5.5시간 범위
};

const ABI = [
  "function head() view returns (uint256)",
  "function executionBlockNumber() view returns (uint256)",
  "function GENESIS_TIME() view returns (uint256)",
  "function SECONDS_PER_SLOT() view returns (uint256)",
  "function headers(uint256) view returns (bytes32)",
  "event HeadUpdate(uint256 indexed slot, bytes32 indexed root)",
];

const el = (id) => document.getElementById(id);
const fmt = (n) => Number(n).toLocaleString("en-US");
const short = (s, n = 8) => (s.length > 2 * n + 2 ? `${s.slice(0, n + 2)}…${s.slice(-n)}` : s);

function explorerLink(kind, value, label) {
  if (!CONFIG.explorer) return `<code>${label || short(value)}</code>`;
  const path = kind === "tx" ? "tx" : kind === "block" ? "block" : "address";
  return `<a href="${CONFIG.explorer}/${path}/${value}" target="_blank" rel="noreferrer"><code>${label || short(value)}</code></a>`;
}

function setNet(state, label) {
  const dot = el("net-dot");
  dot.className = `dot ${state}`;
  el("net-label").textContent = label;
}

function fmtSlotTime(slot, genesisTime, secondsPerSlot) {
  if (!slot || !genesisTime || !secondsPerSlot) return "—";
  const ts = Number(genesisTime) + Number(slot) * Number(secondsPerSlot);
  const d = new Date(ts * 1000);
  const diff = Math.max(0, Math.floor(Date.now() / 1000) - ts);
  const ago = diff < 60 ? `${diff}초 전`
    : diff < 3600 ? `${Math.floor(diff / 60)}분 전`
    : `${Math.floor(diff / 3600)}시간 전`;
  return `${d.toISOString().replace("T", " ").slice(0, 19)} UTC · ${ago}`;
}

async function fetchSepoliaFinalized() {
  const res = await fetch(`${CONFIG.sepoliaBeacon}/eth/v1/beacon/headers/finalized`);
  if (!res.ok) throw new Error(`beacon ${res.status}`);
  const json = await res.json();
  return BigInt(json.data.header.message.slot);
}

async function loadEvents(provider, contract) {
  const current = await provider.getBlockNumber();
  const from = Math.max(0, current - CONFIG.eventLookbackBlocks);
  const filter = contract.filters.HeadUpdate();
  const logs = await contract.queryFilter(filter, from, current);
  return logs.slice(-15).reverse();
}

function renderEvents(logs) {
  const tbody = el("events-body");
  if (!logs.length) {
    tbody.innerHTML = `<tr><td colspan="4" class="muted">최근 ${CONFIG.eventLookbackBlocks.toLocaleString()} 블록 내 업데이트 없음</td></tr>`;
    return;
  }
  tbody.innerHTML = logs.map((log) => {
    const slot = log.args[0].toString();
    const root = log.args[1];
    const tx = log.transactionHash;
    const block = log.blockNumber;
    return `<tr>
      <td>${fmt(slot)}</td>
      <td><span class="truncate">${explorerLink("", root, short(root, 10))}</span></td>
      <td>${explorerLink("tx", tx)}</td>
      <td>${explorerLink("block", block, fmt(block))}</td>
    </tr>`;
  }).join("");
}

async function refresh(state) {
  const { provider, contract } = state;
  try {
    const [head, execBlock, genesisTime, secondsPerSlot, srcSlot] = await Promise.all([
      contract.head(),
      contract.executionBlockNumber(),
      state.genesisTime ?? contract.GENESIS_TIME(),
      state.secondsPerSlot ?? contract.SECONDS_PER_SLOT(),
      fetchSepoliaFinalized().catch(() => null),
    ]);
    state.genesisTime = genesisTime;
    state.secondsPerSlot = secondsPerSlot;

    el("head-slot").textContent = fmt(head);
    el("head-time").textContent = fmtSlotTime(head, genesisTime, secondsPerSlot);
    el("exec-block").textContent = fmt(execBlock);

    if (srcSlot !== null) {
      el("src-slot").textContent = fmt(srcSlot);
      el("src-time").textContent = fmtSlotTime(srcSlot, genesisTime, secondsPerSlot);
      const lag = Number(srcSlot) - Number(head);
      const lagSec = lag * Number(secondsPerSlot);
      el("lag").textContent = `${fmt(lag)} · ${fmt(lagSec)}s`;
      const lagLabel = lag <= 32 ? ["ok", "최신 (1 epoch 이내)"]
        : lag <= 128 ? ["warn", "동기화 진행 중"]
        : ["err", "지연 — operator 확인 필요"];
      el("lag-status").textContent = lagLabel[1];
      el("lag-status").className = "card-foot";
      el("lag-status").style.color = `var(--${lagLabel[0] === "ok" ? "ok" : lagLabel[0] === "warn" ? "warn" : "err"})`;
    } else {
      el("src-slot").textContent = "—";
      el("src-time").textContent = "Sepolia beacon 조회 실패";
      el("lag").textContent = "—";
    }

    const logs = await loadEvents(provider, contract).catch((e) => {
      console.warn("events:", e);
      return [];
    });
    renderEvents(logs);

    setNet("ok", `Metadium testnet · chainId 12`);
    el("refresh-stamp").textContent = `업데이트 ${new Date().toLocaleTimeString()}`;
  } catch (err) {
    console.error(err);
    setNet("err", `연결 실패: ${err.message?.slice(0, 80) || err}`);
  }
}

async function main() {
  const provider = new JsonRpcProvider(CONFIG.metadiumRpc, { chainId: 12, name: "metadium-testnet" });
  const contract = new Contract(CONFIG.helios, ABI, provider);
  const state = { provider, contract };

  // 컨트랙트 링크 세팅
  if (CONFIG.explorer) {
    el("link-helios").href = `${CONFIG.explorer}/address/${CONFIG.helios}`;
    el("link-verifier").href = `${CONFIG.explorer}/address/${CONFIG.verifier}`;
  } else {
    el("link-helios").removeAttribute("href");
    el("link-verifier").removeAttribute("href");
  }

  await refresh(state);
  setInterval(() => refresh(state), CONFIG.pollMs);
}

main().catch((e) => {
  console.error(e);
  setNet("err", `초기화 실패: ${e.message || e}`);
});
