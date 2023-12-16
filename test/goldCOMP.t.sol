// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

import "./BaseFixture.sol";

import { goldCOMPErrors } from "../src/goldCOMP.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract goldCOMPTest is BaseFixture {
    function testDeposit(uint256 amount) public {
        userDeposit(amount);

        invariant_deposit(amount);
    }

    function testDeposit_revert() public {
        // zero amount should revert
        vm.prank(address(45));
        vm.expectRevert(abi.encodeWithSelector(goldCOMPErrors.InvalidAmount.selector, 0));
        gComp.deposit(0);

        deal(address(COMP), COMP_DEPOSITOR_AGENT, 50e18);

        // missed approval should revert
        vm.prank(COMP_DEPOSITOR_AGENT);
        vm.expectRevert("Comp::transferFrom: transfer amount exceeds spender allowance");
        gComp.deposit(50e18);
    }

    function testWithdrawQueue(uint256 amount) public {
        userDeposit(amount);
        invariant_deposit(amount);

        // record internal storage
        uint256 internalBalance = gComp.internalAssetBalances(COMP_DEPOSITOR_AGENT);
        assertEq(internalBalance, amount);

        vm.prank(COMP_DEPOSITOR_AGENT);
        gComp.queueWithdraw(amount);

        invariant_queueWithdraw(internalBalance, amount, 0);
    }

    function testWithdrawQueue_revert() public {
        // zero amount should revert
        vm.prank(address(45));
        vm.expectRevert(abi.encodeWithSelector(goldCOMPErrors.InvalidAmount.selector, 0));
        gComp.queueWithdraw(0);

        // queue more than internal balance should revert
        userDeposit(50e18);
        vm.prank(COMP_DEPOSITOR_AGENT);
        vm.expectRevert(abi.encodeWithSelector(goldCOMPErrors.InvalidAmount.selector, 70e18));
        gComp.queueWithdraw(70e18);
    }

    function testWithdrawComplete(uint256 amount) public {
        userDeposit(amount);
        invariant_deposit(amount);

        // record internal storage
        uint256 internalBalance = gComp.internalAssetBalances(COMP_DEPOSITOR_AGENT);
        assertEq(internalBalance, amount);

        vm.prank(COMP_DEPOSITOR_AGENT);
        gComp.queueWithdraw(amount);

        invariant_queueWithdraw(internalBalance, amount, 0);

        skip(gComp.daysToWait());

        // snapshots before full wd
        uint256 compBalancePrev = COMP.balanceOf(COMP_DEPOSITOR_AGENT);
        uint256 gCompSupplyPrev = gComp.totalSupply();
        uint256 gCompBalancePrev = gComp.balanceOf(COMP_DEPOSITOR_AGENT);

        vm.prank(COMP_DEPOSITOR_AGENT);
        gComp.withdraw();

        invariant_completeWithdraw(0, gCompSupplyPrev, gCompBalancePrev, compBalancePrev, amount);
    }

    function testSetDaysWaitsHappy() public {
        uint256 daysToWaitNewVal = 20 days;

        vm.prank(GOLD_MSIG);
        gComp.setDaysToWait(daysToWaitNewVal);

        assertEq(gComp.daysToWait(), daysToWaitNewVal);
    }

    function testSetDaysWaits_revert() public {
        uint256 daysToWaitNewVal = 20 days;

        vm.prank(address(4_343_435_545));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(4_343_435_545)));
        gComp.setDaysToWait(daysToWaitNewVal);
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
