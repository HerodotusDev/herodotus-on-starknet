// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FormatWords64} from "./lib/FormatWords64.sol";
import {IStarknetCore} from "./interfaces/IStarknetCore.sol";

import {IAggregatorsFactory} from "./interfaces/IAggregatorsFactory.sol";
import {IAggregator} from "./interfaces/IAggregator.sol";

contract L1MessagesSender {
    IStarknetCore public immutable starknetCore;

    uint256 public immutable l2RecipientAddr;

    IAggregatorsFactory public immutable aggregatorsFactory;

    /// @dev L2 "receive_commitment" L1 handler selector
    uint256 constant RECEIVE_COMMITMENT_L1_HANDLER_SELECTOR =
        0x3fa70707d0e831418fb142ca8fb7483611b84e89c0c42bf1fc2a7a5c40890ad;

    /// @dev L2 "receive_mmr" L1 handler selector
    uint256 constant RECEIVE_MMR_L1_HANDLER_SELECTOR =
        0x36c76e67f1d589956059cbd9e734d42182d1f8a57d5876390bb0fcfe1090bb4;

    /// @param starknetCore_ a StarknetCore address to send and consume messages on/from L2
    /// @param l2RecipientAddr_ a L2 recipient address that is the recipient contract on L2.
    /// @param aggregatorsFactoryAddr_ Herodotus aggregators factory address (where MMR trees are referenced)
    constructor(
        IStarknetCore starknetCore_,
        uint256 l2RecipientAddr_,
        address aggregatorsFactoryAddr_
    ) {
        starknetCore = starknetCore_;
        l2RecipientAddr = l2RecipientAddr_;
        aggregatorsFactory = IAggregatorsFactory(aggregatorsFactoryAddr_);
    }

    /// @notice Send an exact L1 parent hash to L2
    /// @param blockNumber_ the child block of the requested parent hash
    function sendExactParentHashToL2(uint256 blockNumber_) external {
        bytes32 parentHash = blockhash(blockNumber_ - 1);
        require(parentHash != bytes32(0), "ERR_INVALID_BLOCK_NUMBER");

        _sendBlockHashToL2(parentHash, blockNumber_, 0);
    }

    /// @notice Send the L1 latest parent hash to L2
    function sendLatestParentHashToL2() external {
        bytes32 parentHash = blockhash(block.number - 1);
        _sendBlockHashToL2(parentHash, block.number, 0);
    }

    function _sendBlockHashToL2(
        bytes32 parentHash_,
        uint256 blockNumber_,
        uint256 slashRewarderL2Addr_
    ) internal {
        uint256[] memory message = new uint256[](6);
        (
            bytes8 hashWord1,
            bytes8 hashWord2,
            bytes8 hashWord3,
            bytes8 hashWord4
        ) = FormatWords64.fromBytes32(parentHash_);

        message[0] = uint256(uint64(hashWord1));
        message[1] = uint256(uint64(hashWord2));
        message[2] = uint256(uint64(hashWord3));
        message[3] = uint256(uint64(hashWord4));
        message[4] = blockNumber_;
        message[5] = slashRewarderL2Addr_;

        starknetCore.sendMessageToL2(
            l2RecipientAddr,
            RECEIVE_COMMITMENT_L1_HANDLER_SELECTOR,
            message
        );
    }

    /// @param aggregatorId The id of a tree previously created by the aggregators factory
    function sendPoseidonMMRTreeToL2(uint256 aggregatorId) external {
        address existingAggregatorAddr = aggregatorsFactory.getAggregatorById(
            aggregatorId
        );

        require(existingAggregatorAddr != address(0), "Unknown aggregator");

        IAggregator aggregator = IAggregator(existingAggregatorAddr);
        bytes32 poseidonMMRRoot = aggregator.getMMRPoseidonRoot();
        uint256 mmrSize = aggregator.getMMRSize();

        require(mmrSize >= 1, "Invalid tree size");
        require(poseidonMMRRoot != bytes32(0), "Invalid root (Poseidon)");

        _sendPoseidonMMRTreeToL2(poseidonMMRRoot, mmrSize);
    }

    function _sendPoseidonMMRTreeToL2(
        bytes32 poseidonMMRRoot,
        uint256 mmrSize
    ) internal {
        uint256[] memory message = new uint256[](2);

        message[0] = uint256(poseidonMMRRoot);
        message[1] = mmrSize;

        starknetCore.sendMessageToL2(
            l2RecipientAddr,
            RECEIVE_MMR_L1_HANDLER_SELECTOR,
            message
        );
    }
}
