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

    /// @dev Case when user queues a lot of withdrawals and able to withdraw all of them at once
    function testDepositWithdrawMultipleWithdrawals(uint256 amount, uint256 numDeposits) public {
        vm.assume(numDeposits > 0 && numDeposits < 5);
        for (uint256 i = 0; i < numDeposits; i++) {
            userDeposit(amount);
        }
        // Queue all withdrawals
        for (uint256 i = 0; i < numDeposits; i++) {
            vm.prank(COMP_DEPOSITOR_AGENT);
            gComp.queueWithdraw(amount);
        }
        uint256 compBalancePrev = COMP.balanceOf(COMP_DEPOSITOR_AGENT);
        uint256 gCompSupplyPrev = gComp.totalSupply();
        uint256 gCompBalancePrev = gComp.balanceOf(COMP_DEPOSITOR_AGENT);
        skip(gComp.daysToWait());
        // Withdraw everything now
        for (uint256 i = 0; i < numDeposits; i++) {
            vm.prank(COMP_DEPOSITOR_AGENT);
            gComp.withdraw();
        }

        // Make sure everything is withdrawn
        invariant_completeWithdraw(0, gCompSupplyPrev, gCompBalancePrev, compBalancePrev, amount * numDeposits);
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
}
