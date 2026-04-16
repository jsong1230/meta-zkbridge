// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {SP1Verifier as SP1VerifierPlonk} from "@sp1-contracts/v5.0.0/SP1VerifierPlonk.sol";

/// @title DeployVerifier
/// @notice SP1VerifierPlonk v5.0.0 을 Metadium testnet에 배포 (1회성)
/// @dev sp1-sdk v5.2.4 는 PLONK proof를 생성 (Groth16 아님). v5.0.0 PLONK selector = 0xd4e8ecd2.
///      배포 후 주소를 genesis.json .verifier 에 기입
contract DeployVerifier is Script {
    uint256 constant METADIUM_TESTNET = 12;

    function run() public returns (address verifier) {
        require(
            block.chainid == METADIUM_TESTNET,
            "DeployVerifier: target must be Metadium testnet (chainId 12)"
        );

        vm.startBroadcast();
        SP1VerifierPlonk v = new SP1VerifierPlonk();
        verifier = address(v);
        vm.stopBroadcast();

        console.log("SP1VerifierPlonk v5.0.0 deployed at", verifier);
        console.log("Next: edit genesis.json .verifier to this address, then run Deploy");
    }
}
