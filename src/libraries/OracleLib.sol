//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePriceFeed();

    uint256 private constant STALE_THRESHOLD = 3 hours; // 3*60*60 10800

    function getCheckStaleLatestPrice(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        //updatedAt is the timestamp that every update the price;  // every update the price period is 1 hour 60*60 3600
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        if ((block.timestamp - updatedAt) > STALE_THRESHOLD) {
            revert OracleLib__StalePriceFeed();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
