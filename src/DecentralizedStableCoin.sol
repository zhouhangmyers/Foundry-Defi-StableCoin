//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AddressZero();
    error DecentralizedStableCoin__AmountZero();
    error DecentralizedStableCoin__InsufficientBalance();

    constructor() ERC20("DSC", "DSC") Ownable(msg.sender) {}

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__AddressZero();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountZero();
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountZero();
        }

        if (_amount > balanceOf(msg.sender)) {
            revert DecentralizedStableCoin__InsufficientBalance();
        }
        super.burn(_amount);
    }
}
