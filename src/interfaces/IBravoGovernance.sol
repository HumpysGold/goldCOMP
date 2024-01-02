// SPDX-License-Identifier: AGPLv3

pragma solidity 0.8.20;

interface IBravoGovernance {
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    function castVote(uint256 proposalId, uint8 support) external;

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    )
        external
        returns (uint256);

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);
}
