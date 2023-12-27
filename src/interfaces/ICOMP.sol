// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICOMP is IERC20 {
    function delegate(address delegatee) external;
}
