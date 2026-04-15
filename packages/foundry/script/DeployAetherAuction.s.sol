// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AetherAuction.sol";
import "../contracts/MockHonkVerifier.sol";

contract DeployAetherAuction is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner {
        // Deploy the MockHonkVerifier (lightweight ZK proof verifier for testnet)
        // Note: Full HonkVerifier (33KB) exceeds EIP-170 limit (24KB).
        // MockHonkVerifier implements same IVerifier interface with basic validation.
        MockHonkVerifier verifierContract = new MockHonkVerifier();
        console.log("MockHonkVerifier deployed at:", address(verifierContract));
        deployments.push(Deployment("MockHonkVerifier", address(verifierContract)));

        // Deploy AetherAuction with verifier address
        AetherAuction auction = new AetherAuction(deployer, address(verifierContract));
        console.log("AetherAuction deployed at:", address(auction));
        deployments.push(Deployment("AetherAuction", address(auction)));
    }
}
