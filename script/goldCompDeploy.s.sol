// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";

import { goldCOMP } from "../src/goldCOMP.sol";

/// @notice Deploys immutable `goldCOMP` contract
contract goldCompDeploy is Script {
    // goldCOMP
    goldCOMP public goldComp;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        goldComp = new goldCOMP();

        vm.stopBroadcast();
    }
}
