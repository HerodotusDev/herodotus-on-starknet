// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IAggregator} from "./IAggregator.sol";

interface IAggregatorsFactory {
    function aggregatorsById(uint256 id) external view returns (address);
}
