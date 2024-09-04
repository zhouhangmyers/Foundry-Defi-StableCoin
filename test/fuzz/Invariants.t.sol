//SPDX-License-Identifier:

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSCEngine} from "script/DeployDSCEngine.t.sol";
import {HelperConfig} from "script/HelperConfig.t.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {Handler} from "./Handler.t.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract Invariants is StdInvariant, Test {
    DeployDSCEngine public deployDSCEngine;
    HelperConfig public helperConfig;
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    address public weth;
    address public wbtc;
    address public ethPriceFeed;
    address public btcPriceFeed;
    Handler handler;

    function setUp() external {
        deployDSCEngine = new DeployDSCEngine();
        (dsc, dscEngine, helperConfig) = deployDSCEngine.run();
        (weth, wbtc, ethPriceFeed, btcPriceFeed,) = helperConfig.netWorkConfig();
        handler = new Handler(dsc, dscEngine);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSuply = dsc.totalSupply();
        uint256 totalWethDepositedAmount = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDepositedAmount = ERC20Mock(wbtc).balanceOf(address(dscEngine));

        uint256 totalWethValue = dscEngine.getCollateralValueInUsd(weth, totalWethDepositedAmount);
        uint256 totalWbtcValue = dscEngine.getCollateralValueInUsd(wbtc, totalWbtcDepositedAmount);

        console.log("weth value: %s", totalWethValue);
        console.log("wbtc value: %s", totalWbtcValue);
        console.log("total supply: %s", totalSuply);

        assert(totalWethValue + totalWbtcValue >= totalSuply);
    }
}
