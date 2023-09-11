// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IAggregator} from "./IAggregator.sol";

interface IAggregatorsFactory {
    function aggregatorsById(uint256 id) external view returns (address);
}
