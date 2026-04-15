//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import {DeployAetherToken} from "./DeployAetherToken.s.sol";
import {DeployAetherAuction} from "./DeployAetherAuction.s.sol";
import {DeployZKKYCRegistry} from "./DeployZKKYCRegistry.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        DeployAetherToken deployToken = new DeployAetherToken();
        deployToken.run();

        DeployZKKYCRegistry deployRegistry = new DeployZKKYCRegistry();
        deployRegistry.run();

        DeployAetherAuction deployAuction = new DeployAetherAuction();
        deployAuction.run();
    }
}
