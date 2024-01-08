// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { console2 } from "../lib/forge-std/src/console2.sol";
import { ICOMP } from "../src/interfaces/ICOMP.sol";
import { IBravoGovernance } from "../src/interfaces/IBravoGovernance.sol";

import { goldCOMP } from "../src/goldCOMP.sol";

contract BaseFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/
    ICOMP constant COMP = ICOMP(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    IBravoGovernance public constant COMPOUND_GOVERNANCE = IBravoGovernance(0xc0Da02939E1441F497fd74F78cE7Decb17B66529);

    address constant COMP_DEPOSITOR_AGENT = address(4_343_443);
    address constant GOLD_MSIG = 0x941dcEA21101A385b979286CC6D6A9Bf435EB1C2;
    address constant PROPOSER_GOVERNANCE = 0x9c9dC2110240391d4BEe41203bDFbD19c279B429;

    goldCOMP gComp;

    function setUp() public {
        // https://etherscan.io/block/18716686
        vm.createSelectFork("mainnet", 18_716_686);

        gComp = new goldCOMP();
    }

    ///////////////////////////// Invariants ///////////////////////////////

    function invariant_deposit(uint256 _amount) internal {
        // assert invariants (erc20 storage + internal)
        assertEq(gComp.totalSupply(), _amount);
        assertEq(COMP.balanceOf(address(gComp)), _amount);
    }

    function invariant_queueWithdraw(
        uint256 _gCompSupplyBefore,
        uint256 _gCompBalanceBefore,
        uint256 _queueAmount,
        uint256 _queueIndex
    )
        internal
    {
        (uint256 queueAmount, uint256 timestamp, uint256 releaseTimestamp, bool withdrawn) =
            gComp.queuedWithdrawals(COMP_DEPOSITOR_AGENT, _queueIndex);
        assertEq(gComp.totalSupply(), _gCompSupplyBefore - _queueAmount);
        assertEq(gComp.balanceOf(COMP_DEPOSITOR_AGENT), _gCompBalanceBefore - _queueAmount);
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

    function randomGovernanceProposalGenerator(address _target) internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        targets[0] = _target;
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] =
            hex"27efe3cb0000000000000000000000009c9dc2110240391d4bee41203bdfbd19c279b429000000000000000000000000000000000000000000000061171e32e0149c0000";
        string memory description = "random proposal for test";
        vm.prank(PROPOSER_GOVERNANCE);
        proposalId = COMPOUND_GOVERNANCE.propose(targets, values, signatures, calldatas, description);
    }
}
