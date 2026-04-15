// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AetherToken.sol";

contract DeployAetherToken is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner {
        AetherToken token = new AetherToken(deployer);
        console.log("AetherToken deployed at:", address(token));
        deployments.push(Deployment("AetherToken", address(token)));
    }
}
