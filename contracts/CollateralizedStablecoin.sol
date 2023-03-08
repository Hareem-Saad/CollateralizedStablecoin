// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CollateralizedStablecoin is ERC20, Ownable {

    uint8 public ratio;
    uint8 public tax;
    uint256 public priceFeed = 1000; //so i can run it on localhost
    uint256 private taxAmount;
    uint256 public supplyCap;
    
    constructor () ERC20 ("Neon", "NEO") {
        ratio = 1;
        tax = 1;
        supplyCap = 1000000 * 10 ** 18;
    }

    event newDeposit (address indexed from, uint256 amount, uint256 exchange);
    event newRedeem (address indexed from, uint256 amount, uint256 exchange);
    event withdrawn(address from, address to, uint amount, uint time);

    /**
     * @notice gives stable coin in return for ETH
     * @param _amount of dollars (USD) you want to stake
     */
    function depositCollateral(uint256 _amount) public payable {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 tokensToMint = _amount * 10 ** 18 * ratio;
        require(_amount > 0 && tokensToMint <= supplyCap, "Amount must be greater than 0 and lower and equal to supplyCap");
        uint256 price = getExchangeRate(_amount);
        require(price <= msg.value, "Value not enough");
        _mint(msg.sender, tokensToMint);

        emit newDeposit(msg.sender, _amount, priceFeed);

        //transfer leftover
        (bool sent,) = payable(msg.sender).call{value: msg.value - price}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @notice gives the latest exchange rate for 1 ETH to USD
     * @param _amount of dollars (USD) you want to stake
     */
    function getExchangeRate(uint256 _amount) public view returns (uint256) {
        return _amount * (10 ** 18) / priceFeed;
    }

    /**
     * @notice gives taxed ether in return for withdrawn collateral
     * @param _amount of tokens you want to redeem
     */
    function withdrawCollateral(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= _amount * 10 ** 18, "Amount must be lesser than your current balance");

        (uint256 RedeemedAmount, uint256 Tax) = calculatePriceForSale(_amount);

        taxAmount += Tax;

        // _burn(msg.sender, _amount * 10 ** 18 / ratio);
        _burn(msg.sender, _amount * 10 ** 18);

        emit newRedeem(msg.sender, _amount * 10 ** 18, priceFeed);

        (bool sent,) = payable(msg.sender).call{value: RedeemedAmount}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @notice gives amount of ether to redeem and tax value
     * @param _amount of tokens you want to redeem
     */
    function calculatePriceForSale(uint256 _amount) public view returns (uint256 RedeemedAmount, uint256 Tax) {
        uint256 dollars = _amount * 10 ** 18 / ratio;
        uint256 price = dollars / priceFeed;

        uint256 _tax = tax * price / 100;
        return (price - _tax, _tax);
    }

    /**
     * @notice allows owner to withdraw tax
     */
    function withdrawTax() public onlyOwner {
        require(taxAmount > 0, "tax must be greater than 0");

        uint256 _tax = taxAmount;

        taxAmount = 0;

        (bool sent,) = payable(msg.sender).call{value: _tax}("");
        require(sent, "Failed to send Ether");

        emit withdrawn (address(this), msg.sender, _tax, block.timestamp);
    }
}