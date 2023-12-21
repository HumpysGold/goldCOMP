// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

interface IBravoGovernance {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);

    function castVote(uint256 proposalId, uint8 support) external;
}
