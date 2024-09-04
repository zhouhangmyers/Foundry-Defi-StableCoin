//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployDSCEngine} from "script/DeployDSCEngine.t.sol";
import {HelperConfig} from "script/HelperConfig.t.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    DecentralizedStableCoin public dsc;
    address public weth;
    address public wbtc;
    address public ethPriceFeed;
    address public btcPriceFeed;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    address USER = makeAddr("user");
    uint256 public constant STARTING_ERC20_BALANCE = 100;

    function setUp() external {
        DeployDSCEngine deployDSCEngine = new DeployDSCEngine();
        (dsc, dscEngine, helperConfig) = deployDSCEngine.run();
        (weth, wbtc, ethPriceFeed, btcPriceFeed,) = helperConfig.netWorkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    function testTokenAddressesAndTokenPriceFeedAddressesNotMatchLength() external {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethPriceFeed);
        priceFeedAddresses.push(btcPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch.selector);
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testIftokenAddressesIsZero() external {
        vm.expectRevert(DSCEngine.DSCEngine__AddressZero.selector);
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testCollateralValueInUsd() external view {
        uint256 ethAmount = 10;
        uint256 expectedUsd = 20000;
        uint256 actualUsd = dscEngine.getCollateralValueInUsd(weth, ethAmount);
        console.log("expectedUsd: ", expectedUsd);
        console.log("actualUsd: ", actualUsd);
        assertEq(actualUsd, expectedUsd);
    }

    function testAccountInformationInUsd() external view {
        uint256 expectedMinted = 0;
        uint256 expectedCollateralValue = 0;
        (uint256 actualMinted, uint256 actualCollateralValue) = dscEngine.getAccountInformationInUsd(USER);
        console.log("expectedMinted: ", expectedMinted);
        console.log("actualMinted: ", actualMinted);
        console.log("expectedCollateralValue: ", expectedCollateralValue);
        console.log("actualCollateralValue: ", actualCollateralValue);
        assertEq(actualMinted, expectedMinted);
        assertEq(actualCollateralValue, expectedCollateralValue);
    }

    function testMoreThanZero() external {
        vm.expectRevert(DSCEngine.DSCEngine__AmountZero.selector);
        dscEngine.depositCollateral(weth, 0);
    }

    function testMustBeAllowedCollteral() external {
        ERC20Mock test = new ERC20Mock("test", "test", msg.sender, 18);
        vm.expectRevert(DSCEngine.DSCEngine__IsNotAllowedCollateralAddress.selector);
        dscEngine.depositCollateral(address(test), 10);
    }

    function testDepositCollateral() external {
        vm.startPrank(USER);
        uint256 amount = 10;
        ERC20Mock(weth).approve(address(dscEngine), amount);
        uint256 allowance = ERC20Mock(weth).allowance(USER, address(dscEngine));
        console.log("allowance: ", allowance);
        dscEngine.depositCollateral(weth, amount);

        uint256 dscEngineBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        uint256 expectedDscEngineBalance = amount;
        uint256 expectedUserBalance = STARTING_ERC20_BALANCE - amount;
        console.log("dscEngineBalance: ", dscEngineBalance);
        console.log("userBalance: ", userBalance);
        assertEq(dscEngineBalance, expectedDscEngineBalance);
        assertEq(userBalance, expectedUserBalance);

        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dscEngine), 10);
        uint256 allowance = ERC20Mock(weth).allowance(USER, address(dscEngine));
        console.log("Allowance: ", allowance);
        vm.prank(USER);
        dscEngine.depositCollateral(weth, 10);
        _;
    }

    function testAfterDepositCollateralCanCheckAmountInformation() public depositedCollateral {
        (uint256 totoalDscMinted, uint256 collateralValue) = dscEngine.getAccountInformationInUsd(USER);
        console.log("collateralValue: ", collateralValue); //20000
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValue); //10
        assertEq(totoalDscMinted, expectedTotalDscMinted);
        assertEq(10, expectedCollateralAmount);
    }
}
