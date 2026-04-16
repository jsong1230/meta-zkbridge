// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {SP1Verifier as SP1VerifierGroth16} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";

/// @title DeployVerifier
/// @notice SP1VerifierGroth16 을 Metadium testnet에 배포 (1회성)
/// @dev Groth16Verifier.sol 은 solc =0.8.20 고정이라 이 스크립트는 별도 pragma 사용
///      배포 후 주소를 prover/genesis.sh 실행 결과 genesis.json 의 .verifier 에 기입
contract DeployVerifier is Script {
    uint256 constant METADIUM_TESTNET = 12;

    function run() public returns (address verifier) {
        require(
            block.chainid == METADIUM_TESTNET,
            "DeployVerifier: target must be Metadium testnet (chainId 12)"
        );

        vm.startBroadcast();
        SP1VerifierGroth16 v = new SP1VerifierGroth16();
        verifier = address(v);
        vm.stopBroadcast();

        console.log("SP1VerifierGroth16 deployed at", verifier);
        console.log("Next: edit genesis.json .verifier to this address, then run Deploy");
    }
}
