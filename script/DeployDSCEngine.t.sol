//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.t.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

contract DeployDSCEngine is Script {
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    DecentralizedStableCoin public dsc;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        helperConfig = new HelperConfig();
        (address weth, address wbtc, address ethPriceFeed, address btcPriceFeed, uint256 privateKey) =
            helperConfig.netWorkConfig();

        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeedAddresses.push(ethPriceFeed);
        priceFeedAddresses.push(btcPriceFeed);
        vm.startBroadcast(privateKey);
        dsc = new DecentralizedStableCoin();
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dsc, dscEngine, helperConfig);
    }
}
