// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {AbstractCommitmentsSender} from "./AbstractCommitmentsSender.sol";

import {IStarknetCore} from "./interfaces/IStarknetCore.sol";
import {IParentHashFetcher} from "./interfaces/IParentHashFetcher.sol";
import {IAggregator} from "./interfaces/IAggregator.sol";

contract L1CommitmentsSender is AbstractCommitmentsSender {
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
        address existingAggregatorAddr = aggregatorsFactory.aggregatorsById(
            aggregatorId
        );

        require(existingAggregatorAddr != address(0), "Unknown aggregator");

        IAggregator aggregator = IAggregator(existingAggregatorAddr);
        bytes32 poseidonMMRRoot = aggregator.getMMRPoseidonRoot();
        uint256 mmrSize = aggregator.getMMRSize();

        require(mmrSize >= 1, "Invalid tree size");
        require(poseidonMMRRoot != bytes32(0), "Invalid root (Poseidon)");

        _sendPoseidonMMRTreeToL2(poseidonMMRRoot, mmrSize, aggregatorId);
    }
}
