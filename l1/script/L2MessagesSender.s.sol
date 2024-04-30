// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {L2MessagesSender} from "../src/L2MessagesSender.sol";
import {IStarknetCore} from "../src/interfaces/IStarknetCore.sol";
import {IParentHashFetcher} from "../src/interfaces/IParentHashFetcher.sol";

contract L2MessagesSenderDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        L2MessagesSender l2MessagesSender = new L2MessagesSender(
            IStarknetCore(vm.envAddress("STARKNET_CORE_ADDRESS")),
            vm.envUint("L2_RECIPIENT_ADDRESS"),
            vm.envAddress("AGGREGATORS_FACTORY_ADDRESS"),
            IParentHashFetcher(vm.envAddress("PARENT_HASH_FETCHER"))
        );

        console.log("L1MessagesSender address: %s", address(l2MessagesSender));

        vm.stopBroadcast();
    }
}
