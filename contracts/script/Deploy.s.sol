// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {SP1Helios, InitParams} from "../src/SP1Helios.sol";
import {SP1MockVerifier} from "@sp1-contracts/SP1MockVerifier.sol";

/// @title Deploy
/// @notice SP1Helios 를 Metadium testnet (chainId 12)에 배포
/// @dev
///  - genesis.json 은 prover/genesis.sh 실행 후 contracts/ 프로젝트 루트에 생성
///  - SP1VerifierGroth16 은 solc =0.8.20 고정이라 별도 스크립트(DeployVerifier.s.sol)에서 배포
///  - verifier 주소는 genesis.json의 .verifier 필드에 기입:
///      · 0x0 + MOCK=1           → 여기서 SP1MockVerifier 배포 (개발·통합 테스트)
///      · 0x0 + MOCK=0 (default) → revert. DeployVerifier 먼저 실행하고 주소 기입
///      · 실제 주소              → 그대로 재사용
contract Deploy is Script {
    uint256 constant METADIUM_TESTNET = 12;

    function run() public returns (address helios, address verifier) {
        require(
            block.chainid == METADIUM_TESTNET,
            "Deploy: target must be Metadium testnet (chainId 12)"
        );

        vm.startBroadcast();

        InitParams memory params = readGenesisConfig();

        if (params.verifier == address(0)) {
            bool mock = vm.envOr("MOCK", uint256(0)) == 1;
            require(
                mock,
                "Deploy: verifier is zero. Set MOCK=1 for SP1MockVerifier, or run DeployVerifier first and fill genesis.json .verifier"
            );
            params.verifier = address(new SP1MockVerifier());
            console.log("Deployed SP1MockVerifier at", params.verifier);
        } else {
            console.log("Reusing existing verifier at", params.verifier);
        }

        SP1Helios heliosContract = new SP1Helios(params);
        helios = address(heliosContract);
        verifier = params.verifier;

        console.log("SP1Helios deployed at", helios);
        console.log("Guardian:", params.guardian);
        console.log("Source chain id:", params.sourceChainId);
        console.log("Initial head slot:", params.head);
    }

    function readGenesisConfig() internal view returns (InitParams memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/genesis.json");
        string memory json = vm.readFile(path);

        return InitParams({
            executionStateRoot: vm.parseJsonBytes32(json, ".executionStateRoot"),
            executionBlockNumber: vm.parseJsonUint(json, ".executionBlockNumber"),
            genesisTime: vm.parseJsonUint(json, ".genesisTime"),
            genesisValidatorsRoot: vm.parseJsonBytes32(json, ".genesisValidatorsRoot"),
            guardian: vm.parseJsonAddress(json, ".guardian"),
            head: vm.parseJsonUint(json, ".head"),
            header: vm.parseJsonBytes32(json, ".header"),
            lightClientVkey: vm.parseJsonBytes32(json, ".lightClientVkey"),
            storageSlotVkey: vm.parseJsonBytes32(json, ".storageSlotVkey"),
            secondsPerSlot: vm.parseJsonUint(json, ".secondsPerSlot"),
            slotsPerEpoch: vm.parseJsonUint(json, ".slotsPerEpoch"),
            slotsPerPeriod: vm.parseJsonUint(json, ".slotsPerPeriod"),
            sourceChainId: vm.parseJsonUint(json, ".sourceChainId"),
            syncCommitteeHash: vm.parseJsonBytes32(json, ".syncCommitteeHash"),
            verifier: vm.parseJsonAddress(json, ".verifier")
        });
    }
}
