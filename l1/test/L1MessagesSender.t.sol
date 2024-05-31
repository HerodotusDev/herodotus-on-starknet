// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {L1MessagesSender} from "../src/L1MessagesSender.sol";
import {IStarknetCore} from "../src/interfaces/IStarknetCore.sol";

contract L1MessagesSenderTest is Test {
    L1MessagesSender public sender;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("sepolia"));

        sender = new L1MessagesSender(
            IStarknetCore(0xE2Bb56ee936fd6433DC0F6e7e3b8365C906AA057),
            0x02d939c63f39760E6bC9120B2FA5b0E14e16a8f8FF22E1D8f0F088b2808F6637,
            0x70C61dd17b7207B450Cb7DeDC92C1707A07a1213
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

        uint256 mmrId = 4;

        // Value must be greater than 0
        sender.sendPoseidonMMRTreeToL2{value: 1}(aggregatorId, mmrId);
    }
}
