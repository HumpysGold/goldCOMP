// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

import "./BaseFixture.sol";

contract goldCOMPTest is BaseFixture {
    function testDeposit(uint256 amount) public {
        userDeposit(amount);

        invariant_deposit(amount);
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

    function invariant_deposit(uint256 _amount) internal {
        // assert invariants (erc20 storage + internal)
        assertEq(gComp.totalSupply(), _amount);
        assertEq(gComp.totalAssetBalance(), _amount); // TODO: why this variable is it not the same as total supply?
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
