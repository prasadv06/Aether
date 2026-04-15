// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/ZKKYCRegistry.sol";

contract DeployZKKYCRegistry is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner {
        ZKKYCRegistry registry = new ZKKYCRegistry(deployer);
        console.log("ZKKYCRegistry deployed at:", address(registry));
        deployments.push(Deployment("ZKKYCRegistry", address(registry)));
    }
}
