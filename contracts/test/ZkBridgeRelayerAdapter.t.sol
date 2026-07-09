// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {SP1Helios, StorageSlot, InitParams} from "../src/SP1Helios.sol";
import {ZkBridgeRelayerAdapter} from "../src/ZkBridgeRelayerAdapter.sol";

// ── Mocks ────────────────────────────────────────────────────────────────

/// @notice ISP1Verifier no-op (proof 검증 통과/실패 토글)
contract MockVerifier {
    bool public shouldRevert;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function verifyProof(bytes32, bytes calldata, bytes calldata) external view {
        require(!shouldRevert, "mock verify fail");
    }
}

/// @notice OperatorRegistry mock (MetaStake getOperator/operatorCount 시그니처)
contract MockOperatorRegistry {
    mapping(uint256 => mapping(address => bool)) public isActive;
    mapping(uint256 => uint256) public operatorCount;

    function setOperator(uint256 sid, address op, bool active) external {
        bool was = isActive[sid][op];
        if (active && !was) operatorCount[sid] += 1;
        if (!active && was) operatorCount[sid] -= 1;
        isActive[sid][op] = active;
    }

    function getOperator(uint256 sid, address op)
        external
        view
        returns (uint256 stake, uint256 unstakeRequestTime, bool active)
    {
        active = isActive[sid][op];
        stake = active ? 1 ether : 0;
        unstakeRequestTime = 0;
    }
}

/// @notice SP1Helios 릴레이 포워딩 검증용 mock (호출 기록만)
contract MockHelios {
    uint256 public head;
    uint256 public updateCalls;
    uint256 public storageCalls;
    uint256 public lastNewHead;
    uint256 public lastBlockNumber;
    bytes public lastProof;

    function update(
        bytes calldata proof,
        uint256 newHead,
        bytes32,
        bytes32,
        uint256,
        bytes32,
        bytes32,
        StorageSlot[] memory
    ) external {
        lastProof = proof;
        lastNewHead = newHead;
        head = newHead;
        updateCalls += 1;
    }

    function updateStorageSlot(bytes calldata, StorageSlot[] memory, uint256 blockNumber) external {
        lastBlockNumber = blockNumber;
        storageCalls += 1;
    }
}

// ── 어댑터 테스트 (MockHelios + MockOperatorRegistry) ──────────────────────

contract ZkBridgeRelayerAdapterTest is Test {
    uint256 constant SERVICE_ID = 0; // zkBridge Relayer
    MockHelios helios;
    MockOperatorRegistry registry;
    ZkBridgeRelayerAdapter adapter;

    address op0 = address(0xA0);
    address op1 = address(0xA1);
    address stranger = address(0xBEEF);

    function setUp() public {
        helios = new MockHelios();
        registry = new MockOperatorRegistry();
        adapter = new ZkBridgeRelayerAdapter(address(helios), address(registry), SERVICE_ID);
    }

    function _relay(address caller, uint256 newHead) internal {
        StorageSlot[] memory slots = new StorageSlot[](0);
        vm.prank(caller);
        adapter.relay(hex"aabb", newHead, bytes32("h"), bytes32("s"), 100, bytes32(0), bytes32(0), slots);
    }

    function test_RevertWhen_NonOperatorRelays() public {
        StorageSlot[] memory slots = new StorageSlot[](0);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ZkBridgeRelayerAdapter.NotActiveOperator.selector, stranger));
        adapter.relay(hex"aabb", 32, bytes32("h"), bytes32("s"), 100, bytes32(0), bytes32(0), slots);
    }

    function test_ActiveOperatorRelays_ForwardsAndRecords() public {
        registry.setOperator(SERVICE_ID, op0, true);

        _relay(op0, 32);

        assertEq(helios.updateCalls(), 1, "forwarded to helios.update");
        assertEq(helios.lastNewHead(), 32);
        assertEq(helios.head(), 32);

        (uint64 count, uint64 lastTime) = adapter.relayStats(op0);
        assertEq(count, 1);
        assertGt(lastTime, 0);
        assertEq(adapter.totalRelays(), 1);
        assertEq(adapter.lastRelayer(), op0);
        assertEq(adapter.lastRelayHead(), 32);
    }

    function test_MultipleRelaysAccumulate() public {
        registry.setOperator(SERVICE_ID, op0, true);
        registry.setOperator(SERVICE_ID, op1, true);

        _relay(op0, 32);
        _relay(op1, 64);
        _relay(op0, 96);

        (uint64 c0,) = adapter.relayStats(op0);
        (uint64 c1,) = adapter.relayStats(op1);
        assertEq(c0, 2);
        assertEq(c1, 1);
        assertEq(adapter.totalRelays(), 3);
        assertEq(adapter.lastRelayer(), op0);
        assertEq(adapter.lastRelayHead(), 96);
    }

    function test_RelayStorageSlot() public {
        registry.setOperator(SERVICE_ID, op0, true);
        StorageSlot[] memory slots = new StorageSlot[](0);

        vm.prank(op0);
        adapter.relayStorageSlot(hex"ccdd", slots, 500);

        assertEq(helios.storageCalls(), 1);
        assertEq(helios.lastBlockNumber(), 500);
        (uint64 count,) = adapter.relayStats(op0);
        assertEq(count, 1);
    }

    function test_RevertWhen_NonOperatorRelaysStorageSlot() public {
        StorageSlot[] memory slots = new StorageSlot[](0);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ZkBridgeRelayerAdapter.NotActiveOperator.selector, stranger));
        adapter.relayStorageSlot(hex"ccdd", slots, 500);
    }

    function test_OperatorCountView() public {
        registry.setOperator(SERVICE_ID, op0, true);
        registry.setOperator(SERVICE_ID, op1, true);
        assertEq(adapter.operatorCount(), 2);
        registry.setOperator(SERVICE_ID, op0, false);
        assertEq(adapter.operatorCount(), 1);
    }

    function test_DeactivatedOperatorCannotRelay() public {
        registry.setOperator(SERVICE_ID, op0, true);
        _relay(op0, 32);
        registry.setOperator(SERVICE_ID, op0, false);

        StorageSlot[] memory slots = new StorageSlot[](0);
        vm.prank(op0);
        vm.expectRevert(abi.encodeWithSelector(ZkBridgeRelayerAdapter.NotActiveOperator.selector, op0));
        adapter.relay(hex"aabb", 64, bytes32("h"), bytes32("s"), 100, bytes32(0), bytes32(0), slots);
    }
}

// ── SP1Helios v2 게이트 테스트 (실제 SP1Helios + MockVerifier) ──────────────

contract SP1HeliosGateTest is Test {
    SP1Helios helios;
    MockVerifier verifier;

    address guardian = address(this);
    address gate = address(0x6A7E);
    address stranger = address(0xBEEF);

    function setUp() public {
        verifier = new MockVerifier();
        InitParams memory p = InitParams({
            executionStateRoot: bytes32("esr"),
            executionBlockNumber: 100,
            genesisTime: 1,
            genesisValidatorsRoot: bytes32("gvr"),
            guardian: guardian,
            head: 0,
            header: bytes32("hdr"),
            lightClientVkey: bytes32("lck"),
            storageSlotVkey: bytes32("ssk"),
            secondsPerSlot: 12,
            slotsPerEpoch: 32,
            slotsPerPeriod: 8192,
            sourceChainId: 1,
            syncCommitteeHash: bytes32("sch"),
            verifier: address(verifier)
        });
        helios = new SP1Helios(p);
    }

    function _update(address caller, uint256 newHead) internal {
        StorageSlot[] memory slots = new StorageSlot[](0);
        vm.prank(caller);
        helios.update(hex"aabb", newHead, bytes32("nh"), bytes32("nsr"), 200, bytes32("sch"), bytes32(0), slots);
    }

    function test_PermissionlessWhenGateUnset() public {
        assertEq(helios.relayerGate(), address(0));
        _update(stranger, 32); // 누구나 가능
        assertEq(helios.head(), 32);
    }

    function test_SetRelayerGate_OnlyGuardian() public {
        vm.prank(stranger);
        vm.expectRevert("Caller is not the guardian");
        helios.setRelayerGate(gate);
    }

    function test_SetRelayerGate_EmitsAndStores() public {
        vm.expectEmit(true, false, false, false);
        emit SP1Helios.RelayerGateUpdate(gate);
        helios.setRelayerGate(gate);
        assertEq(helios.relayerGate(), gate);
    }

    function test_RevertWhen_GateSet_NonGateCaller() public {
        helios.setRelayerGate(gate);
        StorageSlot[] memory slots = new StorageSlot[](0);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(SP1Helios.NotAuthorizedRelayer.selector, stranger));
        helios.update(hex"aabb", 32, bytes32("nh"), bytes32("nsr"), 200, bytes32("sch"), bytes32(0), slots);
    }

    function test_GateCallerCanUpdate() public {
        helios.setRelayerGate(gate);
        _update(gate, 32);
        assertEq(helios.head(), 32);
    }

    function test_UnsetGateRestoresPermissionless() public {
        helios.setRelayerGate(gate);
        helios.setRelayerGate(address(0));
        _update(stranger, 32);
        assertEq(helios.head(), 32);
    }
}
