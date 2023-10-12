// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {L1MessagesSender} from "../src/L1MessagesSender.sol";
import {IStarknetCore} from "../src/interfaces/IStarknetCore.sol";
import {IOptimismL2OutputOracle} from "../src/interfaces/IOptimismL2OutputOracle.sol";

contract L1MessagesSenderDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        L1MessagesSender l1MessagesSender = new L1MessagesSender(
            IStarknetCore(vm.envAddress("STARKNET_CORE_ADDRESS")),
            IOptimismL2OutputOracle(
                vm.envAddress("OPTIMISM_L2_OUTPUT_ORACLE_ADDRESS")
            ),
            vm.envUint("L2_RECIPIENT_ADDRESS_FROM_ETHEREUM"),
            vm.envUint("L2_RECIPIENT_ADDRESS_FROM_OPTIMISM"),
            vm.envAddress("AGGREGATORS_FACTORY_ADDRESS")
        );

        console.log("L1MessagesSender address: %s", address(l1MessagesSender));

        vm.stopBroadcast();
    }
}
