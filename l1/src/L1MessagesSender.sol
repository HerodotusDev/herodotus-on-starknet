// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin/access/Ownable.sol";

import {FormatWords64} from "./lib/FormatWords64.sol";
import {IStarknetCore} from "./interfaces/IStarknetCore.sol";
import {IOptimismL2OutputOracle} from "./interfaces/IOptimismL2OutputOracle.sol";

import {IAggregatorsFactory} from "./interfaces/IAggregatorsFactory.sol";
import {IAggregator} from "./interfaces/IAggregator.sol";

import {Uint256Splitter} from "./lib/Uint256Splitter.sol";

contract L1MessagesSender is Ownable {
    using Uint256Splitter for uint256;

    IStarknetCore public immutable starknetCore;
    IOptimismL2OutputOracle public immutable optimismOutputOracle;

    uint256 public optimismCommitmentsInboxAddr;

    IAggregatorsFactory public aggregatorsFactory;

    /// @dev L2 "receive_commitment" L1 handler selector
    uint256 constant RECEIVE_COMMITMENT_L1_HANDLER_SELECTOR =
        0x3fa70707d0e831418fb142ca8fb7483611b84e89c0c42bf1fc2a7a5c40890ad;

    /// @dev L2 "receive_mmr" L1 handler selector
    uint256 constant RECEIVE_MMR_L1_HANDLER_SELECTOR =
        0x36c76e67f1d589956059cbd9e734d42182d1f8a57d5876390bb0fcfe1090bb4;

    /// @param starknetCore_ a StarknetCore address to send and consume messages on/from L2
    /// @param optimismOutputOracle_ address of the optimism rollup output contract
    /// @param optimismCommitmentsInboxAddr_ a L2 recipient address that is the recipient contract on L2.
    /// @param aggregatorsFactoryAddr_ Herodotus aggregators factory address (where MMR trees are referenced)
    constructor(
        IStarknetCore starknetCore_,
        IOptimismL2OutputOracle optimismOutputOracle_,
        uint256 optimismCommitmentsInboxAddr_,
        address aggregatorsFactoryAddr_
    ) {
        starknetCore = starknetCore_;
        optimismOutputOracle = optimismOutputOracle_;
        optimismCommitmentsInboxAddr = optimismCommitmentsInboxAddr_;
        aggregatorsFactory = IAggregatorsFactory(aggregatorsFactoryAddr_);
    }

    /// @notice Send an exact L1 parent hash to L2
    /// @param blockNumber_ the child block of the requested parent hash
    function sendExactParentHashToL2(uint256 blockNumber_) external payable {
        bytes32 parentHash = blockhash(blockNumber_ - 1);
        require(parentHash != bytes32(0), "ERR_INVALID_BLOCK_NUMBER");

        _sendBlockHashToL2(parentHash, blockNumber_);
    }

    // See  https://github.com/ethereum-optimism/optimism/blob/0086b6dd4eaa579227607216a83ca0d6a652b264/packages/contracts-bedrock/src/libraries/Hashing.sol#L114
    function sendOptimismBlockhashToL2(
        uint256 outputIndex_,
        IOptimismL2OutputOracle.OutputRootProof calldata outputRootPreimage_
    ) external payable {
        IOptimismL2OutputOracle.OutputProposal
            memory outputProposal = optimismOutputOracle.getL2Output(
                outputIndex_
            );
        bytes32 actualOutputRoot = keccak256(
            abi.encode(
                outputRootPreimage_.version,
                outputRootPreimage_.stateRoot,
                outputRootPreimage_.messagePasserStorageRoot,
                outputRootPreimage_.latestBlockhash
            )
        );

        require(
            actualOutputRoot == outputProposal.outputRoot,
            "ERR_OUTPUT_ROOT_PROOF_INVALID"
        );
        _sendBlockHashToL2(
            outputRootPreimage_.latestBlockhash,
            outputProposal.l2BlockNumber
        );
    }

    /// @notice Send the L1 latest parent hash to L2
    function sendLatestParentHashToL2() external payable {
        bytes32 parentHash = blockhash(block.number - 1);
        _sendBlockHashToL2(parentHash, block.number);
    }

    /// @param aggregatorId The id of a tree previously created by the aggregators factory
    function sendPoseidonMMRTreeToL2(uint256 aggregatorId) external payable {
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

    function _sendBlockHashToL2(
        bytes32 parentHash_,
        uint256 blockNumber_
    ) internal {
        uint256[] memory message = new uint256[](4);
        (uint256 parentHashLow, uint256 parentHashHigh) = uint256(parentHash_)
            .split128();
        (uint256 blockNumberLow, uint256 blockNumberHigh) = blockNumber_
            .split128();
        message[0] = parentHashLow;
        message[1] = parentHashHigh;
        message[2] = blockNumberLow;
        message[3] = blockNumberHigh;

        starknetCore.sendMessageToL2{value: msg.value}(
            optimismCommitmentsInboxAddr,
            RECEIVE_COMMITMENT_L1_HANDLER_SELECTOR,
            message
        );
    }

    function _sendPoseidonMMRTreeToL2(
        bytes32 poseidonMMRRoot,
        uint256 mmrSize,
        uint256 aggregatorId
    ) internal {
        uint256[] memory message = new uint256[](3);

        message[0] = uint256(poseidonMMRRoot);
        message[1] = mmrSize;
        message[2] = aggregatorId;

        // Pass along msg.value
        starknetCore.sendMessageToL2{value: msg.value}(
            optimismCommitmentsInboxAddr,
            RECEIVE_MMR_L1_HANDLER_SELECTOR,
            message
        );
    }

    /// @notice Set the L2 recipient address
    /// @param newoptimismCommitmentsInboxAddr_ The new L2 recipient address
    function setoptimismCommitmentsInboxAddr(
        uint256 newoptimismCommitmentsInboxAddr_
    ) external onlyOwner {
        optimismCommitmentsInboxAddr = newoptimismCommitmentsInboxAddr_;
    }

    /// @notice Set the aggregators factory address
    /// @param newAggregatorsFactoryAddr_ The new aggregators factory address
    function setAggregatorsFactoryAddr(
        address newAggregatorsFactoryAddr_
    ) external onlyOwner {
        aggregatorsFactory = IAggregatorsFactory(newAggregatorsFactoryAddr_);
    }
}
