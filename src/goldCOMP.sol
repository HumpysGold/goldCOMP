// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import { ICOMP } from "./interfaces/ICOMP.sol";

library goldCOMPErrors {
    error InvalidAmount(uint256 amount);
    error TooLong(uint256 daysToWait);
}

contract goldCOMP is ERC20, Ownable {
    using SafeERC20 for ERC20;
    using SafeERC20 for ICOMP;

    struct Withdrawal {
        uint256 amount;
        uint256 timestamp;
        uint256 releaseTimestamp;
        bool withdrawn;
    }

    ///////////////////////////// Constants ///////////////////////////////
    ICOMP public constant COMP = ICOMP(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    address public constant GOLD_MSIG = 0x941dcEA21101A385b979286CC6D6A9Bf435EB1C2;

    /////////////////////////////// Storage ///////////////////////////////
    mapping(address => Withdrawal[]) public queuedWithdrawals;
    uint256 public daysToWait = 7 days;
    address public delegatee = 0x90Bd4645882E865A1d94ab643017bd5EC2AE73be;

    /////////////////////////////// Events ////////////////////////////////
    event Deposit(address indexed user, uint256 amount);
    event WithrawalQueued(address indexed user, uint256 amount, uint256 timestamp, uint256 releaseTimestamp);
    event Withdraw(address indexed user, uint256 amount);
    event DaysToWaitSet(uint256 daysToWait);
    event DelegateeSet(address indexed delegatee);

    // Setup token and transfer ownership to multi immediately
    constructor() ERC20("goldCOMP", "goldCOMP") Ownable(GOLD_MSIG) { }

    /// @notice User deposits COMP and gets goldCOMP in exchange
    /// @param _amount Amount of COMP to deposit
    function deposit(uint256 _amount) external {
        if (_amount == 0) {
            revert goldCOMPErrors.InvalidAmount(_amount);
        }

        // Mint goldCOMP to user
        _mint(msg.sender, _amount);

        // Transfer COMP from user to contract
        COMP.safeTransferFrom(msg.sender, address(this), _amount);
        // Delegate COMP voting power to delegatee
        COMP.delegate(delegatee);
        emit Deposit(msg.sender, _amount);
    }

    /// @notice Delegate COMP voting power to delegatee
    function manualDelegate() external onlyOwner {
        COMP.delegate(delegatee);
    }

    /// @notice When withdrawing, user has to wait daysToWait days and then can withdraw
    /// @param _amount Amount of COMP to withdraw
    function queueWithdraw(uint256 _amount) external {
        if (_amount == 0 || _amount > balanceOf(msg.sender)) {
            revert goldCOMPErrors.InvalidAmount(_amount);
        }

        // Burn goldCOMP from user, which ensures they have sufficient balance
        _burn(msg.sender, _amount);

        // Queue withdrawal for user
        queuedWithdrawals[msg.sender].push(Withdrawal(_amount, block.timestamp, block.timestamp + daysToWait, false));

        emit WithrawalQueued(msg.sender, _amount, block.timestamp, block.timestamp + daysToWait);
    }

    /// @notice User can withdraw after daysToWait days have passed. Withdraw all available withdrawals
    function withdraw() external {
        uint256 amountToWithdraw = 0;
        // Calculate cumulative amount to withdraw
        for (uint256 i; i < queuedWithdrawals[msg.sender].length; i++) {
            if (
                queuedWithdrawals[msg.sender][i].releaseTimestamp <= block.timestamp
                    && !queuedWithdrawals[msg.sender][i].withdrawn
            ) {
                amountToWithdraw += queuedWithdrawals[msg.sender][i].amount;
                queuedWithdrawals[msg.sender][i].withdrawn = true;
            }
        }

        // Transfer COMP to user
        COMP.safeTransfer(msg.sender, amountToWithdraw);
        emit Withdraw(msg.sender, amountToWithdraw);
    }

    /////////////////////////////// Admin functions ////////////////////////////////
    /// @notice Change days to wait before user can withdraw
    /// @param _daysToWait New days to wait
    function setDaysToWait(uint256 _daysToWait) external onlyOwner {
        if (_daysToWait > 30) {
            revert goldCOMPErrors.TooLong(_daysToWait);
        }
        daysToWait = _daysToWait * 1 days;
        emit DaysToWaitSet(_daysToWait * 1 days);
    }

    /// @notice Change delegatee
    /// @param _delegatee New delegatee
    function setDelegatee(address _delegatee) external onlyOwner {
        delegatee = _delegatee;
        emit DelegateeSet(_delegatee);
    }
}
