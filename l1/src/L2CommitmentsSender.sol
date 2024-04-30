// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {AbstractCommitmentsSender} from "./AbstractCommitmentsSender.sol";

import {IStarknetCore} from "./interfaces/IStarknetCore.sol";
import {IParentHashFetcher} from "./interfaces/IParentHashFetcher.sol";

contract L2CommitmentsSender is AbstractCommitmentsSender {
    constructor(
        IStarknetCore starknetCore_,
        uint256 l2RecipientAddr_,
        address aggregatorsFactoryAddr_,
        IParentHashFetcher _parentHashFetcher
    )
        AbstractCommitmentsSender(
            starknetCore_,
            l2RecipientAddr_,
            aggregatorsFactoryAddr_,
            _parentHashFetcher
        )
    {}

    /// @param aggregatorId The id of a tree previously created by the aggregators factory
    function sendPoseidonMMRTreeToL2(
        uint256 aggregatorId
    ) external payable override {
        revert("Not implemented");
    }
}
