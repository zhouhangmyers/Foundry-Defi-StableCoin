//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract Handler is Test {
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint256 public constant MAX_VALUE = type(uint96).max;
    address[] public user;
    address public sender;

    constructor(DecentralizedStableCoin _dsc, DSCEngine _dscEngine) {
        dsc = _dsc;
        dscEngine = _dscEngine;
        address[] memory tokenAddresses = dscEngine.getCollateralAddresses();
        weth = ERC20Mock(tokenAddresses[0]);
        wbtc = ERC20Mock(tokenAddresses[1]);
    }

    modifier onlyDepositedUser() {
        for (uint256 i = 0; i < user.length; i++) {
            if (user[i] == msg.sender) {
                sender = msg.sender;
                break;
            }
        }
        _;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amount) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amount = bound(amount, 0, MAX_VALUE);
        if (amount <= 0) {
            return;
        }

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amount);
        collateral.approve(address(dscEngine), amount);
        dscEngine.depositCollateral(address(collateral), amount);
        for (uint256 i = 0; i < user.length; i++) {
            if (user[i] == msg.sender) {
                return;
            }
        }
        user.push(msg.sender);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amount) public onlyDepositedUser {
        if (sender == address(0)) {
            return;
        }
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        vm.startPrank(sender);
        uint256 balance = dscEngine.getUserCollateralAmount(sender, address(collateral));
        if (balance <= 0) {
            sender = address(0);
            return;
        }
        amount = bound(amount, 0, balance);
        if (amount <= 0) {
            sender = address(0);
            return;
        }
        dscEngine.redeemCollateral(address(collateral), amount);

        vm.stopPrank();
        sender = address(0);
    }

    function mintDsc(uint256 amount) public onlyDepositedUser {
        if (sender == address(0)) {
            return;
        }
        vm.startPrank(sender);
        (uint256 totalMintedDsc, uint256 collateralInUsd) = dscEngine.getAccountInformationInUsd(sender);
        int256 enableMintAmount = (int256(collateralInUsd) * 50 / 100) - int256(totalMintedDsc);
        if (enableMintAmount <= 0) {
            sender = address(0);
            return;
        }
        amount = bound(amount, 0, uint256(enableMintAmount));

        if (amount <= 0) {
            sender = address(0);
            return;
        }
        dscEngine.mintDsc(amount);

        vm.stopPrank();
        sender = address(0);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
