// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {L1CommitmentsSender} from "../src/L1CommitmensSender.sol";
import {IStarknetCore} from "../src/interfaces/IStarknetCore.sol";
import {IParentHashFetcher} from "../src/interfaces/IParentHashFetcher.sol";

contract MockParentHashFetcher {
    function fetchParentHash(
        bytes memory ctx
    ) external pure returns (uint256, bytes32) {
        return (0, bytes32(0));
    }

    function chainId() external pure returns (uint256) {
        return 0;
    }
}

contract L1MessagesSenderTest is Test {
    L1CommitmentsSender public sender;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("goerli"));

        MockParentHashFetcher parentHashFetcher = new MockParentHashFetcher();

        sender = new L1CommitmentsSender(
            IStarknetCore(0xde29d060D45901Fb19ED6C6e959EB22d8626708e),
            0x07bf6b32382276bFF5341f810A6811233A9591228642F60160129629448a21b6,
            0xB8Cb7707b5160eaE8931e0cf02B563a5CeA75F09,
            IParentHashFetcher(address(parentHashFetcher))
        );
    }

    function testSendExactParentHashToL2() public {
        uint256 prevBlock = block.number - 1;

        // Value must be greater than 0
        sender.sendExactParentHashToL2{value: 1}(prevBlock);
    }

    function testSendLatestParentHashToL2() public {
        // Value must be greater than 0
        sender.sendLatestParentHashToL2{value: 1}();
    }

    function testSendPoseidonMMRTreeToL2() public {
        // This aggregator id must exist in the factory
        uint256 aggregatorId = 1;

        // Value must be greater than 0
        sender.sendPoseidonMMRTreeToL2{value: 1}(aggregatorId);
    }
}
