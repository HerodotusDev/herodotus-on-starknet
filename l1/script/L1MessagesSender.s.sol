// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {L1CommitmentsSender} from "../src/L1CommitmensSender.sol";
import {IStarknetCore} from "../src/interfaces/IStarknetCore.sol";
import {IParentHashFetcher} from "../src/interfaces/IParentHashFetcher.sol";

contract L1CommitmentsSenderDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        L1CommitmentsSender l1MessagesSender = new L1CommitmentsSender(
            IStarknetCore(vm.envAddress("STARKNET_CORE_ADDRESS")),
            vm.envUint("L2_RECIPIENT_ADDRESS"),
            vm.envAddress("AGGREGATORS_FACTORY_ADDRESS"),
            IParentHashFetcher(vm.envAddress("PARENT_HASH_FETCHER"))
        );

        console.log("L1MessagesSender address: %s", address(l1MessagesSender));

        vm.stopBroadcast();
    }
}
