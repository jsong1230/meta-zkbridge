// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {StorageSlot} from "./SP1Helios.sol";

/// @notice SP1Helios(v2) 릴레이 인터페이스
interface ISP1Helios {
    function update(
        bytes calldata proof,
        uint256 newHead,
        bytes32 newHeader,
        bytes32 executionStateRoot,
        uint256 executionBlockNumber,
        bytes32 syncCommitteeHash,
        bytes32 nextSyncCommitteeHash,
        StorageSlot[] memory storageSlots
    ) external;

    function updateStorageSlot(bytes calldata proof, StorageSlot[] memory storageSlots, uint256 blockNumber)
        external;

    function head() external view returns (uint256);
}

/// @notice MetaStake OperatorRegistry의 operator 조회
interface IOperatorRegistry {
    function getOperator(uint256 serviceId, address operator)
        external
        view
        returns (uint256 stake, uint256 unstakeRequestTime, bool active);

    function operatorCount(uint256 serviceId) external view returns (uint256);
}

/// @title ZkBridgeRelayerAdapter — C2 통합 어댑터
/// @notice meta-zkbridge(SP1Helios)의 릴레이를 MetaStake OperatorRegistry의
///         staked operator(serviceId=0 "zkBridge Relayer")로 게이팅한다.
///
///         C1(dispute)과의 핵심 차이: zkBridge 릴레이는 ZK proof로 *객관적으로* 검증되므로
///         m-of-n majority 합의가 불필요하다. 따라서 이 어댑터는 active operator라면
///         누구나(1-of-n) 릴레이할 수 있게 허용하고, operator별 릴레이 통계/이벤트를 남겨
///         off-chain 라이브니스 모니터링과 슬래싱(OperatorRegistry.slash, admin 소관) 판단을 돕는다.
///
///         SP1Helios.setRelayerGate(이 어댑터)로 연결하면 SP1Helios.update/updateStorageSlot은
///         이 어댑터를 통해서만 호출된다.
contract ZkBridgeRelayerAdapter {
    ISP1Helios public immutable helios;
    IOperatorRegistry public immutable registry;
    uint256 public immutable serviceId;

    struct RelayStats {
        uint64 relayCount;
        uint64 lastRelayTime;
    }

    mapping(address => RelayStats) public relayStats;
    uint256 public totalRelays;
    uint256 public lastRelayHead;
    address public lastRelayer;

    event Relayed(address indexed operator, uint256 indexed newHead, uint64 operatorRelayCount);
    event StorageRelayed(address indexed operator, uint256 indexed blockNumber, uint64 operatorRelayCount);

    error NotActiveOperator(address caller);

    constructor(address _helios, address _registry, uint256 _serviceId) {
        require(_helios != address(0) && _registry != address(0), "zero addr");
        helios = ISP1Helios(_helios);
        registry = IOperatorRegistry(_registry);
        serviceId = _serviceId;
    }

    modifier onlyActiveOperator() {
        (, , bool active) = registry.getOperator(serviceId, msg.sender);
        if (!active) revert NotActiveOperator(msg.sender);
        _;
    }

    /// @notice 현재 active operator 수
    function operatorCount() external view returns (uint256) {
        return registry.operatorCount(serviceId);
    }

    /// @notice active operator가 light client head를 릴레이 (SP1Helios.update 포워딩)
    function relay(
        bytes calldata proof,
        uint256 newHead,
        bytes32 newHeader,
        bytes32 executionStateRoot,
        uint256 executionBlockNumber,
        bytes32 syncCommitteeHash,
        bytes32 nextSyncCommitteeHash,
        StorageSlot[] memory storageSlots
    ) external onlyActiveOperator {
        // 유효하지 않은 proof면 SP1Helios.update 내부에서 revert → 통계 미기록
        helios.update(
            proof,
            newHead,
            newHeader,
            executionStateRoot,
            executionBlockNumber,
            syncCommitteeHash,
            nextSyncCommitteeHash,
            storageSlots
        );

        uint64 c = _record(msg.sender);
        lastRelayHead = newHead;
        emit Relayed(msg.sender, newHead, c);
    }

    /// @notice active operator가 storage slot 증명을 릴레이 (SP1Helios.updateStorageSlot 포워딩)
    function relayStorageSlot(bytes calldata proof, StorageSlot[] memory storageSlots, uint256 blockNumber)
        external
        onlyActiveOperator
    {
        helios.updateStorageSlot(proof, storageSlots, blockNumber);

        uint64 c = _record(msg.sender);
        emit StorageRelayed(msg.sender, blockNumber, c);
    }

    function _record(address op) internal returns (uint64) {
        RelayStats storage s = relayStats[op];
        s.relayCount += 1;
        s.lastRelayTime = uint64(block.timestamp);
        totalRelays += 1;
        lastRelayer = op;
        return s.relayCount;
    }
}
