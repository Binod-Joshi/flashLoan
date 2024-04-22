// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";
import "hardhat/console.sol";

contract FlashLoan {
    using SafeERC20 for IERC20;

    // Factory and Routing Addresses
    address private constant PANCAKE_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // Used to find the address of a specific liquidity pool for a pair of tokens using the getPair function. //Acts as a registry for liquidity pools on PancakeSwap.
    address private constant PANCAKE_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E; // Executes token swaps between different tokens on PancakeSwap.

    // Token Addresses
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function checkResult(uint _repayAmount,uint _acquiredCoin) private pure returns(bool) {
        return _acquiredCoin>_repayAmount;
    }

    // to view balance of contract
    function getBalanceOfToken(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    function placeTrade(address _fromToken, address _toToken, uint _amountIn) private returns(uint){
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(_fromToken, _toToken); // again getting the liquidity pool address of this trade pair
        require(pair != address(0), "Pool doesn't exist");

        address[] memory path = new address[](2); //length of the array
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRequired = IUniswapV2Router01(PANCAKE_ROUTER).getAmountsOut(_amountIn,path)[1]; //expected token/amount or miminum expected amount

        uint256 amountReceived = IUniswapV2Router01(PANCAKE_ROUTER).swapExactTokensForTokens(_amountIn,amountRequired,path,address(this),deadline)[1]; //amount received in actual

        require(amountReceived > 0,"received amount 0, So transcation abort.");
        return amountReceived;

    }

    //This function is used to take a loan from liqudity provider and transfer to our contract
    function initialArbitrage(address _busdBorrow, uint _amount) external { // in this address,_busdBorrow is token which i am borrowing as a flashloan
        IERC20(BUSD).safeApprove(address(PANCAKE_ROUTER),MAX_INT); //here we give unlimited approve of the token to the router
        IERC20(CROX).safeApprove(address(PANCAKE_ROUTER),MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKE_ROUTER),MAX_INT);

        // pancakefactory help to work with liqudity pool
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(_busdBorrow,WBNB) ; //from this we will get the liquidity pool address which help to trade between these two token
        require(pair != address(0), "pool doesn't exist");

        address token0 = IUniswapV2Pair(pair).token0(); // address of WBNB
        address token1 = IUniswapV2Pair(pair).token1(); //it give address of BUSD

        uint amount0Out = _busdBorrow == token0?_amount:0;
        uint amount1Out = _busdBorrow == token1?_amount:0;
        
        bytes memory data = abi.encode(_busdBorrow, _amount, msg.sender); // it gives data which is calling the function and it is going to use for flash loan and many more
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this),data); // It will request the loan and transfer the borrowed token to the this address(contract address) and it call pancakeCall function
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // msg.sender have address of pair
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(token0, token1);
        require(msg.sender == pair);
        require(_sender == address(this),"sender doesn't match"); //here _sender is contract address because pancakeCall function is called called by this contract  internally from initialArbitrage
        (address busdBorrow, uint256 amount, address myAccount) = abi.decode( // we are decoding data here
            _data,
            (address,uint256,address)
        );

        // fee calculation
        uint fee = ((amount*3)/997)+1;
        uint repayAmount = amount+fee;
        uint loanAmount = _amount0>0?_amount0:_amount1;

        //Triangular Arbitrage
        uint trade1Coin = placeTrade(BUSD,CROX,loanAmount);
        uint trade2Coin = placeTrade(CROX,CAKE,trade1Coin);
        uint trade3Coin = placeTrade(CAKE,BUSD,trade2Coin);

        bool result = checkResult(repayAmount,trade3Coin);
        require(result,"This arbitrage is not profitable");

        IERC20(BUSD).transfer(myAccount,trade3Coin-repayAmount); //transfer into my address
        IERC20(busdBorrow).transfer(pair,repayAmount); //transfer into liquidity pool
    }
}

