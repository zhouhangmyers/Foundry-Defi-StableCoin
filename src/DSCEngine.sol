//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

contract DSCEngine {
    error DSCEngine__AmountZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error DSCEngine__AddressZero();
    error DSCEngine__IsNotAllowedCollateralAddress();
    error DSCEngine__InsufficientHealthRate();
    error DSCEngine__MintFaild();
    error DSCEngine__redeemCollateralFaild();
    error DSCEngine__depositCollateralFaild();
    error DSCEngine__HealthFactorIsOk();
    error DSCEngine__BurnDscFaild();
    error DSCEngine__HealthFactorNotImproved();

    using OracleLib for AggregatorV3Interface;

    DecentralizedStableCoin public s_dsc;

    uint256 private constant MIN_HEALTH_RATE = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant PRICEFEED_PRECISION = 1e10;
    uint256 private constant COLLATERAL_RATE = 50;
    uint256 private constant MAX_RATE = type(uint96).max;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_PRECISION = 100;

    address[] private collateralAddresses;
    mapping(address user => uint256 mintedDsc) private mintedDsc;
    mapping(address tokenAddresses => address priceFeedAddresses) private tokenPriceFeedMapping;
    mapping(address user => mapping(address collateralAddress => uint256 amountCollateral)) private userCollateralAmount;

    event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 amountCollateral);
    event CollateralRedeem(
        address indexed user, address indexed to, address indexed collateralAddress, uint256 amountCollateral
    );

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dsc) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        if (tokenAddresses.length == 0) {
            revert DSCEngine__AddressZero();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            tokenPriceFeedMapping[tokenAddresses[i]] = priceFeedAddresses[i];
            collateralAddresses.push(tokenAddresses[i]);
        }
        s_dsc = DecentralizedStableCoin(dsc);
    }

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__AmountZero();
        }
        _;
    }

    modifier isAllowed(address collateralAddress) {
        if (tokenPriceFeedMapping[collateralAddress] == address(0)) {
            revert DSCEngine__IsNotAllowedCollateralAddress();
        }
        _;
    }

    function depositAndMintDsc(address collateralAddress, uint256 amountCollateral) public {
        depositCollateral(collateralAddress, amountCollateral);
        mintDsc(amountCollateral);
    }

    function depositCollateral(address collateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowed(collateralAddress)
    {
        userCollateralAmount[msg.sender][collateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, collateralAddress, amountCollateral);
        bool success = ERC20(collateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__depositCollateralFaild();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintDsc(uint256 amountDsc) public moreThanZero(amountDsc) {
        bool success = s_dsc.mint(msg.sender, amountDsc);
        mintedDsc[msg.sender] += amountDsc;
        if (!success) {
            revert DSCEngine__MintFaild();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralAndBurnDsc(address collateralAddress, uint256 amountCollateral, uint256 amountDsc)
        public
    {
        burnDsc(amountDsc);
        redeemCollateral(collateralAddress, amountCollateral);
    }

    function burnDsc(uint256 amountDsc) public moreThanZero(amountDsc) {
        _burnDsc(msg.sender, msg.sender, amountDsc);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(address collateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowed(collateralAddress)
    {
        _redeemCollateral(msg.sender, msg.sender, collateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _redeemCollateral(address user, address to, address collateral, uint256 amountCollateral) private {
        userCollateralAmount[user][collateral] -= amountCollateral;
        emit CollateralRedeem(user, to, collateral, amountCollateral);
        bool success = ERC20(collateral).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__redeemCollateralFaild();
        }
    }

    function _burnDsc(address user, address to, uint256 amountInWei) public {
        mintedDsc[user] -= amountInWei;
        bool success = s_dsc.transferFrom(to, address(this), amountInWei);
        if (!success) {
            revert DSCEngine__BurnDscFaild();
        }
        s_dsc.burn(amountInWei);
    }

    function liquidate(address collateral, address user, uint256 amountInWei) public moreThanZero(amountInWei) {
        uint256 startingHealthRate = getHealthRate(user);
        if (startingHealthRate > MIN_HEALTH_RATE) {
            revert DSCEngine__HealthFactorIsOk();
        }
        uint256 tokenAmountFromAmountInWei = getTokenAmountFromUsd(collateral, amountInWei);
        uint256 collateralBonus = tokenAmountFromAmountInWei * LIQUIDATION_BONUS / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromAmountInWei + collateralBonus;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnDsc(user, msg.sender, amountInWei);

        uint256 endingHealthRate = getHealthRate(user);
        if (endingHealthRate <= startingHealthRate) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getCollateralValueInUsd(address collateralAddress, uint256 amountCollateral)
        public
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenPriceFeedMapping[collateralAddress]);
        (, int256 price,,,) = priceFeed.getCheckStaleLatestPrice();
        return uint256(price) * PRICEFEED_PRECISION / PRECISION * amountCollateral;
    }

    function getAccountInformationInUsd(address user)
        public
        view
        returns (uint256 mintedDscValue, uint256 collateralInUsd)
    {
        mintedDscValue = mintedDsc[user];
        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            address collateralAddress = collateralAddresses[i];
            uint256 amountCollateral = userCollateralAmount[user][collateralAddress];
            collateralInUsd += getCollateralValueInUsd(collateralAddress, amountCollateral);
        }

        return (mintedDscValue, collateralInUsd);
    }

    function getHealthRate(address user) public view returns (uint256) {
        (uint256 mintedDscValue, uint256 collateralInUsd) = getAccountInformationInUsd(user);
        if (mintedDscValue == 0) {
            return MAX_RATE;
        }
        collateralInUsd = collateralInUsd * COLLATERAL_RATE / 100 * PRECISION;
        return collateralInUsd * PRECISION / mintedDscValue;
    }

    function _revertIfHealthFactorIsBroken(address user) private view {
        uint256 healthRate = getHealthRate(user);
        if (healthRate < MIN_HEALTH_RATE) {
            revert DSCEngine__InsufficientHealthRate();
        }
    }

    function getTokenAmountFromUsd(address ethAddress, uint256 collateralValueInUsd) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenPriceFeedMapping[ethAddress]);
        (, int256 price,,,) = priceFeed.getCheckStaleLatestPrice();
        return collateralValueInUsd * PRECISION / (uint256(price) * PRICEFEED_PRECISION);
    }

    function getUserCollateralAmount(address user, address collateralAddress) public view returns (uint256) {
        return userCollateralAmount[user][collateralAddress];
    }

    function getCollateralAddresses() public view returns (address[] memory) {
        return collateralAddresses;
    }
}
