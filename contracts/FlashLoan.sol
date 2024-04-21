// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract FlashLoan {
    using SafeERC20 for IERC20;

    // Factory and Routing Addresses
    address private constant PANCAKE_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKE_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // Token Addresses
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    //This function is used to take a loan from liqudity provider and transfer to our contract
    function initialArbitrage(address _busdBorrow, uint amount) { // in this address,_busdBorrow is token which i am borrowing as a flashloan
        IERC20(BUSD).safeApprove(address(PANCAKE_ROUTER),MAX_INT); //here we give unlimited approve of the token to the router
        IERC20(CROX).safeApprove(address(PANCAKE_ROUTER),MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKE_ROUTER),MAX_INT);

        // pancakefactory help to work with liqudity pool
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(_busdBorrow,WBNB) ; //from this we will get the liquidity pool address which help to trade between these two token
        require(pair != address(0), "pool doesn't exist")

        address token0 = IUniswapV2Pair(pair).token0(); // address of WBNB
        address token1 = IUniswapV2Pair(pair).token1(); //it give address of BUSD

        uint amount0Out = _busdBorrow == token0?_amount:0;
        uint amount1Out = _busdBorrow == token1?_amount:0;
        
        bytes memory data = abi.encode(_busdBorrow, _amount, msg.sender); // it gives data which is calling the function and it is going to use for flash loan and many more
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this),data) // It will request the loan and transfer the borrowed token to the this address(contract address)
    }
}
