//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ILTSToken is ERC20, Ownable {
    string private TOKEN_NAME = "ILTS token";
    string private TOKEN_SYMBOL = "ILTS";
    uint8 private AMOUNT_OF_DECIMALS = 2;

    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        _mint(msg.sender, 100000 * (10 ** uint256(decimals())));
    }

    function decimals() public view virtual override returns (uint8) {
        return AMOUNT_OF_DECIMALS;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}
