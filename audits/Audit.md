# Second Review

Commit: 0c56ab1fca04c82110292cbac168640191cde324

# Notes

- Ignoring risky refactoring
- Ignoring gas stuff
- Over 600 withdrawals before the gas reaches 3 Million (limit is 10 times this) - Safe -  Not necessary to do changes here

## M / QA - Incorrect `setDaysToWait` check could cap delay to `days` times more than intended

Due to incorrect validation
```solidity
if (_daysToWait > 30 days) {
```

You could end up queing a massive delay, defeating the purpose of the check

See: R - Rename to `secondsToWait` to keep same logic and clarify usage

# QA

## R - Rename to `secondsToWait` to keep same logic and clarify usage

https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L106-L112

```solidity
    function setDaysToWait(uint256 _daysToWait) external onlyOwner {
        if (_daysToWait > 30 days) {
            revert goldCOMPErrors.TooLong(_daysToWait);
        }
        daysToWait = _daysToWait * 1 days;
        emit DaysToWaitSet(_daysToWait * 1 days);
    }
```

Change this to be in seconds, to avoid needless complexity and incorrect logic

```solidity
    function setSecondsToWait(uint256 _secondsToWait) external onlyOwner {
        if (_secondsToWait > 30 days) {
            revert goldCOMPErrors.TooLong(_secondsToWait);
        }
        secondsToWait = _secondsToWait;
        emit SecondsToWaitSet(_secondsToWait);
    }
```

### Alternatively

Change it to compare in days

https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L107-L109

```solidity
        if (_daysToWait > 30) {
            revert goldCOMPErrors.TooLong(_daysToWait);
        }
```

## R - Could allow a separate withdrawal index to save gas

```solidity
    function withdrawOne(uint256 index) external {
        uint256 amountToWithdraw = 0;
        // Calculate cumulative amount to withdraw
        if (
            queuedWithdrawals[msg.sender][index].releaseTimestamp <= block.timestamp
                && !queuedWithdrawals[msg.sender][index].withdrawn
        ) {
            amountToWithdraw += queuedWithdrawals[msg.sender][index].amount;
            queuedWithdrawals[msg.sender][index].withdrawn = true;
        }

        // Transfer COMP to user
        COMP.safeTransfer(msg.sender, amountToWithdraw);
        emit Withdraw(msg.sender, amountToWithdraw);
    }
```

You may receive reports that this could cause issues, and technicaly it's true, but it would take thousands of queued withdrawals

You could also add a way to shorten the array via this

https://ethereum.stackexchange.com/questions/1527/how-to-delete-an-element-at-a-certain-index-in-an-array

```
uint[] internal array;

// Move the last element to the deleted spot.
// Remove the last element.
function _burn(uint index) internal {
  require(index < array.length);
  array[index] = array[array.length-1];
  array.pop();
}
```


## R - Could emit an event for the queued withdrawal

https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L85-L95

```solidity
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
```

So that you can track withdrawals, since the withdrawal creation has an event
A claim could also


## R - Could add a check for non-zero transfer

https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L99

```solidity
COMP.safeTransfer(msg.sender, amountToWithdraw);
```

Would avoid some events, I have checked delegation logic and this will not be griefable




# Mit Review

## Critical - Broken Composability - FIXED
https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L70-L82

```solidity
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
```

Burning the amount means
-> Holder must have the receipt token `goldCOMP``
-> Burning means they cannot "burn again"
-> Withdrawal is queued with `daysToWait` delay

## QA - Admin - Admin cannot delay by more than 30 days - NOT FIXED (See above)
https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L106-L112

```solidity
    function setDaysToWait(uint256 _daysToWait) external onlyOwner {
        if (_daysToWait > 30 days) {
            revert goldCOMPErrors.TooLong(_daysToWait);
        }
        daysToWait = _daysToWait * 1 days;
        emit DaysToWaitSet(_daysToWait * 1 days);
    }
```

## QA - R - Manual Re-delegate - FIXED
https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L64-L66

```solidity
    function manualDelegate() external onlyOwner {
        COMP.delegate(delegatee);
    }
```

## QA - R - Simplified Constructor - FIXED

https://github.com/HumpysGold/goldCOMP/blob/0c56ab1fca04c82110292cbac168640191cde324/src/goldCOMP.sol#L44-L45

```solidity
    constructor() ERC20("goldCOMP", "goldCOMP") Ownable(GOLD_MSIG) { }

```


# Last Mit Review

## M / QA - Incorrect `setDaysToWait` check could cap delay to `days` times more than intended - Fixed


Fixed by using integer that is later multiplied by days

https://github.com/HumpysGold/goldCOMP/blob/6678e6a317e29d1598233b656bab120be45268f4/src/goldCOMP.sol#L105-L112

```solidity

    function setDaysToWait(uint256 _daysToWait) external onlyOwner {
        if (_daysToWait > 30) {
            revert goldCOMPErrors.TooLong(_daysToWait);
        }
        daysToWait = _daysToWait * 1 days;
        emit DaysToWaitSet(_daysToWait * 1 days);
    }
```
