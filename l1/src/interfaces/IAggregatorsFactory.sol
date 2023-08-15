// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IAggregator} from "./IAggregator.sol";

interface IAggregatorsFactory {
    function getAggregatorById(uint256 aggregatorId) external returns (address);
}
