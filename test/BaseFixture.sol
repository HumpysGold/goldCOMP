// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { goldCOMP } from "../src/goldCOMP.sol";

contract BaseFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/
    IERC20 constant COMP = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    address constant COMP_DEPOSITOR_AGENT = address(4_343_443);

    goldCOMP gComp;

    function setUp() public {
        // https://etherscan.io/block/18729433
        vm.createSelectFork("mainnet", 18_729_433);

        gComp = new goldCOMP();
    }
}
