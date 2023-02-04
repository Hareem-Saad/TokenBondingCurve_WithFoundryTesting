// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

error LowOnTokens(uint amount, uint balance);
error LowOnEther(uint amount, uint balance);

contract TokenBondingCurve_Linear is ERC20, Ownable {
    uint256 private _tax;

    uint256 private immutable _slope;

    // The percentage of loss when selling tokens (using two decimals)
    uint256 private constant _LOSS_FEE_PERCENTAGE = 1000;

    /**
     * @dev Constructor to initialize the contract.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param slope_ The slope of the bonding curve.
     * this contract works for all linear curves
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint slope_
    ) ERC20(name_, symbol_) {
        _slope = slope_;
    }

    /**
     * @dev Allows a user to buy tokens.
     * @param _amount The number of tokens to buy.
     */
    function buy(uint256 _amount) external payable {
        uint price = _calculatePriceForBuy(_amount);
        if(msg.value < price) {
            revert LowOnEther(msg.value, address(msg.sender).balance);
        }
        _mint(msg.sender, _amount);
        payable(msg.sender).transfer(msg.value - price);
    }

    /**
     * @dev Allows a user to sell tokens at a 10% loss.
     * @param _amount The number of tokens to sell.
     */
    function sell(uint256 _amount) external {
        if(balanceOf(msg.sender) < _amount) {
            revert LowOnTokens(_amount, balanceOf(msg.sender));
        }
        uint256 _price = _calculatePriceForSell(_amount);
        uint tax = _calculateLoss(_price);
        _burn(msg.sender, _amount);
        // console.log(tax, _price - tax);
        _tax += tax;

        payable(msg.sender).transfer(_price - tax);
    }

    /**
     * @dev Allows the owner to withdraw the tax in ETH.
     */
    function withdraw() external onlyOwner {
        if(_tax <= 0) {
            revert LowOnEther(_tax, _tax);
        }
        uint amount = _tax;
        _tax = 0;
        payable(owner()).transfer(amount);
    }

    /**
     * @dev Returns the current price of the token based on the bonding curve formula.
     * @return The current price of the token in wei.
     */
    function getCurrentPrice() external view returns (uint) {
        return _slope * totalSupply();
    }

    /**
     * @dev Returns the price for buying a specified number of tokens.
     * @param _tokensToBuy The number of tokens to buy.
     * @return The price in wei.
     */
    function calculatePriceForBuy(
        uint256 _tokensToBuy
    ) external view returns (uint256) {
        return _calculatePriceForBuy(_tokensToBuy);
    }

    /**
     * @dev Returns the price for selling a specified number of tokens.
     * @param _tokensToSell The number of tokens to sell.
     * @return The price in wei.
     */
    function calculatePriceForSell(
        uint256 _tokensToSell
    ) external view returns (uint256) {
        return _calculatePriceForSell(_tokensToSell);
    }

    /**
     * @dev Calculates the price for buying tokens based on the bonding curve.
     * @param _tokensToBuy The number of tokens to buy.
     * @return The price in wei for the specified number of tokens.
     */
    function _calculatePriceForBuy(
        uint256 _tokensToBuy
    ) private view returns (uint256) {
        uint price = 0;
        uint totalSupply = totalSupply();
        // console.log(totalSupply + 1, totalSupply + _tokensToBuy);
        for (uint i = totalSupply + 1; i < totalSupply + _tokensToBuy + 1; i++) {
            price += (i * _slope);
        }
        return price;
    }

    /**
     * @dev Calculates the price for selling tokens based on the bonding curve.
     * @param _tokensToSell The number of tokens to sell.
     * @return The price in wei for the specified number of tokens
     */
    function _calculatePriceForSell(
        uint256 _tokensToSell
    ) private view returns (uint256) {
        uint totalSupply = totalSupply();
        if (_tokensToSell > totalSupply) {
            revert();
        }
        uint price = 0;
        for (uint i = totalSupply; i > totalSupply - _tokensToSell; i--) {
            price += (i * _slope);
        }
        return price;
    }

    /**
     * @dev Calculates the loss for selling a certain number of tokens.
     * @param amount The price of the tokens being sold.
     * @return The loss in wei.
     */
    function _calculateLoss(uint256 amount) private pure returns (uint256) {
        return (amount * _LOSS_FEE_PERCENTAGE) / (1E4);
    }
}