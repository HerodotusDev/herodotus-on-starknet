// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FormatWords64} from "./lib/FormatWords64.sol";
import {IStarknetCore} from "./interfaces/IStarknetCore.sol";

import {IAggregatorsFactory} from "./interfaces/IAggregatorsFactory.sol";
import {IAggregator} from "./interfaces/IAggregator.sol";

contract L1MessagesSender {
    IStarknetCore public immutable starknetCore;

    uint256 public immutable l2RecipientAddr;

    IAggregatorsFactory public immutable aggregatorsFactoryAddr;

    /// @dev starknetSelector(receive_from_l1)
    uint256 constant SUBMIT_L1_BLOCKHASH_SELECTOR =
        598342674068027518481179578557554850038206119856216505601406522348670006916;

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
        aggregatorsFactoryAddr = IAggregatorsFactory(aggregatorsFactoryAddr_);
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

    /// @notice Send an exact L1 parent hash to L2
    /// @param blockNumber_ the child block of the requested parent hash
    /// @param slashingRewardL2Recipient_ L2 address of the reward recipient if slashing occurs
    function proveFraudulentRelay(
        uint256 blockNumber_,
        uint256 slashingRewardL2Recipient_
    ) external {
        bytes32 parentHash = blockhash(blockNumber_ - 1);
        require(parentHash != bytes32(0), "ERR_INVALID_BLOCK_NUMBER");
        _sendBlockHashToL2(
            parentHash,
            blockNumber_,
            slashingRewardL2Recipient_
        );
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
            SUBMIT_L1_BLOCKHASH_SELECTOR,
            message
        );
    }

    /// @param aggregatorId The id of a tree previously created by the aggregators factory
    function sendMMRTreesToL2(uint256 aggregatorId) external {
        address existingAggregatorAddr = aggregatorsFactoryAddr
            .getAggregatorById(aggregatorId);

        require(existingAggregatorAddr != address(0), "Unknown aggregator");

        IAggregator aggregator = IAggregator(existingAggregatorAddr);
        bytes32 poseidonMMRRoot = aggregator.getMMRPoseidonRoot();
        bytes32 keccakMMRRoot = aggregator.getMMRKeccakRoot();
        uint256 mmrSize = aggregator.getMMRSize();

        require(mmrSize >= 1, "Invalid tree size");
        require(poseidonMMRRoot != bytes32(0), "Invalid root (Poseidon)");
        require(keccakMMRRoot != bytes32(0), "Invalid root (Keccak)");

        _sendMMRTreesToL2(poseidonMMRRoot, keccakMMRRoot, mmrSize);
    }

    function _sendMMRTreesToL2(
        bytes32 poseidonMMRRoot,
        bytes32 keccakMMRRoot,
        uint256 mmrSize
    ) internal {
        uint256[] memory message = new uint256[](9);

        // Poseidon MMR root hash
        (
            bytes8 poseidonRootHashWord1,
            bytes8 poseidonRootHashWord2,
            bytes8 poseidonRootHashWord3,
            bytes8 poseidonRootHashWord4
        ) = FormatWords64.fromBytes32(poseidonMMRRoot);

        // Keccak MMR root hash
        (
            bytes8 keccakRootHashWord1,
            bytes8 keccakRootHashWord2,
            bytes8 keccakRootHashWord3,
            bytes8 keccakRootHashWord4
        ) = FormatWords64.fromBytes32(keccakMMRRoot);

        message[0] = uint256(uint64(poseidonRootHashWord1));
        message[1] = uint256(uint64(poseidonRootHashWord2));
        message[2] = uint256(uint64(poseidonRootHashWord3));
        message[3] = uint256(uint64(poseidonRootHashWord4));
        message[4] = uint256(uint64(keccakRootHashWord1));
        message[5] = uint256(uint64(keccakRootHashWord2));
        message[6] = uint256(uint64(keccakRootHashWord3));
        message[7] = uint256(uint64(keccakRootHashWord4));
        message[8] = mmrSize;

        starknetCore.sendMessageToL2(
            l2RecipientAddr,
            SUBMIT_L1_BLOCKHASH_SELECTOR,
            message
        );
    }
}
