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
    address constant GOLD_MSIG = 0x941dcEA21101A385b979286CC6D6A9Bf435EB1C2;

    goldCOMP gComp;

    function setUp() public {
        // https://etherscan.io/block/18729433
        vm.createSelectFork("mainnet", 18_729_433);

        gComp = new goldCOMP();
    }

    ///////////////////////////// Invariants ///////////////////////////////

    function invariant_deposit(uint256 _amount) internal {
        // assert invariants (erc20 storage + internal)
        assertEq(gComp.totalSupply(), _amount);
        assertEq(gComp.totalAssetBalance(), _amount);
        assertEq(COMP.balanceOf(address(gComp)), _amount);
        assertEq(gComp.internalAssetBalances(COMP_DEPOSITOR_AGENT), _amount);
    }

    function invariant_queueWithdraw(
        uint256 _prevInternalBalance,
        uint256 _queueAmount,
        uint256 _queueIndex
    )
        internal
    {
        (uint256 queueAmount, uint256 timestamp, uint256 releaseTimestamp, bool withdrawn) =
            gComp.queuedWithdrawals(COMP_DEPOSITOR_AGENT, _queueIndex);

        // assert invariants (internal storage + mapping)
        assertEq(gComp.internalAssetBalances(COMP_DEPOSITOR_AGENT), _prevInternalBalance - _queueAmount);
        assertEq(queueAmount, _queueAmount);
        assertEq(timestamp, block.timestamp);
        assertEq(releaseTimestamp, block.timestamp + gComp.daysToWait());
        assertFalse(withdrawn);
    }

    function invariant_completeWithdraw(
        uint256 _index,
        uint256 _gCompSupplyBefore,
        uint256 _gCompBalanceBefore,
        uint256 _compBalanceBefore,
        uint256 _withdrawAmount
    )
        internal
    {
        (,,, bool withdrawn) = gComp.queuedWithdrawals(COMP_DEPOSITOR_AGENT, _index);

        // assert invariants
        assertEq(gComp.totalSupply(), _gCompSupplyBefore - _withdrawAmount);
        assertEq(gComp.balanceOf(COMP_DEPOSITOR_AGENT), _gCompBalanceBefore - _withdrawAmount);
        assertEq(COMP.balanceOf(COMP_DEPOSITOR_AGENT), _compBalanceBefore + _withdrawAmount);
        assertTrue(withdrawn);
    }

    ///////////////////////////// Helpers ///////////////////////////////

    function userDeposit(uint256 amount) internal {
        // positive amounts
        vm.assume(amount > 0);
        // currently 6.8m in circ
        vm.assume(amount < 6_000_000e18);

        deal(address(COMP), COMP_DEPOSITOR_AGENT, amount);

        // approve + deposit
        vm.prank(COMP_DEPOSITOR_AGENT);
        COMP.approve(address(gComp), amount);
        vm.prank(COMP_DEPOSITOR_AGENT);
        gComp.deposit(amount);
    }
}
