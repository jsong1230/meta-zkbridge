// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {SP1Helios} from "../src/SP1Helios.sol";
import {ZkBridgeRelayerAdapter} from "../src/ZkBridgeRelayerAdapter.sol";

/// @title DeployRelayerAdapter
/// @notice C2 어댑터(ZkBridgeRelayerAdapter)를 Metadium testnet(chainId 12)에 배포하고
///         SP1Helios.setRelayerGate 로 연결한다.
///
/// @dev 환경변수:
///   HELIOS_ADDRESS            — 배포된 SP1Helios(v2) 주소 (필수)
///   OPERATOR_REGISTRY_ADDRESS — MetaStake OperatorRegistry 주소 (필수)
///   RELAYER_SERVICE_ID        — zkBridge Relayer serviceId (기본 0)
///
/// @dev 실행 (브로드캐스터 = SP1Helios guardian 이어야 setRelayerGate 가능):
///   HELIOS_ADDRESS=0x... OPERATOR_REGISTRY_ADDRESS=0x19F4... RELAYER_SERVICE_ID=0 \
///   forge script script/DeployRelayerAdapter.s.sol --rpc-url metadium_testnet \
///     --broadcast --legacy --with-gas-price 80000000000
///
/// @dev 사전 조건: SP1Helios 는 v2(setRelayerGate/relayerGate 포함)여야 함. 구버전이면 재배포 필요.
contract DeployRelayerAdapter is Script {
    uint256 constant METADIUM_TESTNET = 12;

    function run() public returns (address adapter) {
        require(
            block.chainid == METADIUM_TESTNET,
            "Deploy: target must be Metadium testnet (chainId 12)"
        );

        address helios = vm.envAddress("HELIOS_ADDRESS");
        address registry = vm.envAddress("OPERATOR_REGISTRY_ADDRESS");
        uint256 serviceId = vm.envOr("RELAYER_SERVICE_ID", uint256(0));

        console.log("SP1Helios:        ", helios);
        console.log("OperatorRegistry: ", registry);
        console.log("serviceId:        ", serviceId);

        vm.startBroadcast();

        ZkBridgeRelayerAdapter a = new ZkBridgeRelayerAdapter(helios, registry, serviceId);
        adapter = address(a);
        console.log("ZkBridgeRelayerAdapter deployed at", adapter);

        // SP1Helios 에 relayer gate 연결 (브로드캐스터가 guardian 이어야 성공)
        SP1Helios h = SP1Helios(helios);
        address guardian = h.guardian();
        if (guardian == msg.sender) {
            h.setRelayerGate(adapter);
            console.log("setRelayerGate done. relayerGate =", h.relayerGate());
        } else {
            console.log("WARN: broadcaster is not guardian:", guardian);
            console.log("      guardian must call SP1Helios.setRelayerGate(", adapter, ")");
        }

        vm.stopBroadcast();
    }
}
