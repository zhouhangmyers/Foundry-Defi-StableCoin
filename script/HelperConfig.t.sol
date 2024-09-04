//SPDX-Licnese-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetWorkConfig public netWorkConfig;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetWorkConfig {
        address weth;
        address wbtc;
        address ethPriceFeed;
        address btcPriceFeed;
        uint256 privateKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            netWorkConfig = getEthNetWorkConfig();
        } else {
            netWorkConfig = getOrCreateAnvilConfig();
        }
    }

    function getEthNetWorkConfig() public view returns (NetWorkConfig memory) {
        return NetWorkConfig({
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            ethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            btcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            privateKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetWorkConfig memory) {
        if (netWorkConfig.weth != address(0)) {
            return netWorkConfig;
        }
        vm.startBroadcast();
        ERC20Mock wethToken = new ERC20Mock("weth", "weth", msg.sender, 1000e18);
        ERC20Mock wbtcToken = new ERC20Mock("wbtc", "wbtc", msg.sender, 1000e8);
        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(8, 2000e8);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(8, 1000e8);
        vm.stopBroadcast();

        netWorkConfig = NetWorkConfig({
            weth: address(wethToken),
            wbtc: address(wbtcToken),
            ethPriceFeed: address(ethPriceFeed),
            btcPriceFeed: address(btcPriceFeed),
            privateKey: DEFAULT_ANVIL_PRIVATE_KEY
        });

        return netWorkConfig;
    }
}
