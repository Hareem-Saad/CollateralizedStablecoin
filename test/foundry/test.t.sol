// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../contracts/CollateralizedStablecoin.sol";

contract StableCoinTest is Test {

    CollateralizedStablecoin public addr;
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);

    function setUp() public {
        vm.deal(owner, 2 ether);
        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);
        vm.prank(owner);
        addr = new CollateralizedStablecoin();
    }

    function testDepositCollateral(uint256 amount) public {
        vm.assume(amount > 0 && amount < 500);
        // uint256 amount = 100;
        vm.startPrank(user1);
        uint256 price = addr.getExchangeRate(amount);
        addr.depositCollateral{value: price}(amount);
        vm.stopPrank();

        assertEq (addr.balanceOf(user1), amount * 10 ** 18);
        assertEq (address(addr).balance, price);
    }

    function testWithdrawCollateral() public {

        testDepositCollateral(100);

        uint256 prevBalance = addr.balanceOf(user1);
        uint256 prevContractBalance = address(addr).balance;
        uint256 amount = 50;
        vm.startPrank(user1);
        (uint256 redeemed, ) = addr.calculatePriceForSale(amount);
        addr.withdrawCollateral(amount);
        vm.stopPrank();

        assertEq (addr.balanceOf(user1), prevBalance - (amount * 10 ** 18));
        assertEq (address(addr).balance, prevContractBalance - redeemed);
    }
}