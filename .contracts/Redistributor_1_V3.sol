// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC777/ERC777.sol";
import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/utils/Strings.sol";
import "/.deps/github/dapphub/ds-math/src/math.sol";         

contract Redistributor_1_V3 is IERC777Recipient, DSMath, ReentrancyGuard {
    using Strings for uint256;

    address public owner;
    address public starter;
    ERC777 public immutable ETTO;
    uint256 public transfersCount;
    uint256 public cycleId;
    address private lastSender;
    uint256 private profit;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 private randomNumber1;
    uint256 private randomNumber2;
    uint256 private randomNumber3;
    uint256 public lastTradePrice;
    uint256 public cumulativePrice;
    uint256 public lastTradeTimestamp;
    uint256 public totalVolume;
    bool private starterSet = false;

    event Received(address from, address to, uint256 amount);
    event From_Starter(address indexed starter, address indexed to, uint256 amount);
    event RandomNumber1(uint256 randomNumber);
    event RandomNumber2(uint256 randomNumber);
    event RandomNumber3(uint256 randomNumber);
    event TransfersCount(string transfersCount);
    event CycleId(uint256 cycleId);
    event Redistributed(address indexed from, address indexed to, uint256 profit);
    event TransferredProfitCalculated(uint256 profit);
    event RedistributionAttempt(
    address indexed sender,
    uint256 random1,
    uint256 random2,
    uint256 random3,
    uint256 transferCount,
    uint256 price,
    bool triggered,
    uint256 profitTransferred
);

    event SellTransfer(address indexed from, address indexed to, uint256 amount);
    event AddLiquidityToken1(address indexed starter, address indexed to, uint256 amount, ERC777 token1);
    event AddLiquidityToken0(address indexed starter, uint256 amount);
    event Bought(address indexed from, uint256 ethIn, uint256 tokenOut, uint256 tokenPrice);
    event Sold(address seller, uint256 tokenIn, uint256 ethOut, uint256 price);
    event TradeRecorded(address trader, bool isBuy, uint256 tokenAmount, uint256 ethAmount, uint256 price);

    constructor(ERC777 _etto) {
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
            .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));

        cycleId = 1;
        owner = msg.sender;
        ETTO = _etto;
        reserve1 = tokenBalance();
        reserve0 = balanceOf();
        randomNumber1 = theRandomNumber1();
        randomNumber2 = theRandomNumber2();
        randomNumber3 = theRandomNumber3();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyValidToken() {
        require(msg.sender == address(ETTO), "Only valid tokens are accepted");
        _;
    }

    function setStarter(address _starter) external onlyOwner {
        require(_starter != address(0), "Invalid address");
        require(!starterSet, "Presale address has already been set.");
        starter = _starter;
        starterSet = true;
    }

    function tokenBalance() public view returns(uint256) {
        return ERC777(ETTO).balanceOf(address(this));
    }

    function balanceOf() public view returns(uint256) {
        return address(this).balance;
    }

    function getTransfersCount() public view returns (uint256) {
        return transfersCount;
    }

    function theRandomNumber1() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(transfersCount, owner, randomNumber5(), msg.sender, randomNumber4(), balanceOf(), blockhash(block.number-1), cycleId, address(this), lastSender, profit, randomNumber6()));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 99 + 2;
        return randomNumber;
    }

    function theRandomNumber2() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(profit, balanceOf(), randomNumber5(), owner, msg.sender, randomNumber6(), transfersCount,  blockhash(block.number-1), address(this), cycleId, lastSender, randomNumber4()));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 99 + 2;
        return randomNumber;
    }

    function theRandomNumber3() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(cycleId, transfersCount, address(this), randomNumber5(), profit, lastSender, msg.sender, owner, randomNumber4(), balanceOf(), randomNumber6(), blockhash(block.number-1)));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 99 + 2;
        return randomNumber;
    }

    function randomNumber4() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(transfersCount, owner, msg.sender, balanceOf(), blockhash(block.number-1), cycleId, address(this), lastSender, profit));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 3000 + 2;
        return randomNumber;
    }

    function randomNumber5() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(profit, balanceOf(), owner, msg.sender, transfersCount,  blockhash(block.number-1), address(this), cycleId, lastSender));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 6000 + 2;
        return randomNumber;
    }

    function randomNumber6() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(cycleId, transfersCount, address(this), profit, lastSender, msg.sender, owner, balanceOf(),  blockhash(block.number-1)));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 9000 + 2;
        return randomNumber;
    }

    function getRandomNumber1() public view returns (uint256) {
        return randomNumber1;
    }

    function getRandomNumber2() public view returns (uint256) {
        return randomNumber2;
    }

    function getRandomNumber3() public view returns (uint256) {
        return randomNumber3;
    }

    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external override onlyValidToken {
        require(operatorData.length >= 0, "OperatorData cannot be empty");
        require(userData.length >= 0, "UserData cannot be empty");
        require(to != address(0), "to cannot be the null address");
        require(operator != address(0), "Operator cannot be the null address");
        require(from != owner, "Token owner can't take part in redistribution");

        if (from != starter && amount != 7.5 * 10 ** 18) {
            sell(from, amount);
        } else if (from != starter && amount == 7.5 * 10 ** 18) {
            handleTransfer(from, amount);
        } else if (from == starter) {
            handleStarter(amount);
        }
    }

   
   function handleTransfer(address from, uint256 amount) internal {
    emit Received(msg.sender, address(this), amount);
    reserve1 += amount;
    transfersCount++;
    emit TransfersCount(transfersCount.toString());

    randomNumber1 = theRandomNumber1();
    emit RandomNumber1(randomNumber1);
    randomNumber2 = theRandomNumber2();
    emit RandomNumber2(randomNumber2);
    randomNumber3 = theRandomNumber3();
    emit RandomNumber3(randomNumber3);

    bool triggered = false;
    uint256 transferredProfit = 0;

    if (randomNumber1 < transfersCount && randomNumber2 < transfersCount && randomNumber3 < transfersCount) {
        getProfitAmount();
        transferredProfit = profit;
        redistribute(from);
        triggered = true;
    }

    emit RedistributionAttempt(
        from,
        randomNumber1,
        randomNumber2,
        randomNumber3,
        transfersCount,
        getTokenToEth(),
        triggered,
        transferredProfit
    );
}


    function getProfitAmount() internal {

        // Calculate profit percentage based on reserve1 ranges
        if (reserve1 >= 90 * 10 ** 18) {
            
            profit = DSMath.wdiv(DSMath.wmul(reserve1, 10), 100); // If reserve1 >= 90%, profit = 10%
        } else if (reserve1 >= 60 * 10 ** 18 && reserve1 < 90 * 10 ** 18) {
            
            profit = DSMath.wdiv(DSMath.wmul(reserve1, 30), 100); // If reserve1 >= 60% and < 90%, profit = 30%
        } else if (reserve1 >= 30 * 10 ** 18 && reserve1 < 60 * 10 ** 18) {
            
            profit = DSMath.wdiv(DSMath.wmul(reserve1, 60), 100); // If reserve1 >= 30% and < 60%, profit = 60%
        } else {
            
            profit = DSMath.wdiv(DSMath.wmul(reserve1, 90), 100); // If reserve1 < 30%, profit = 90%
        }
        emit TransferredProfitCalculated(profit);

    }

    function redistribute(address from) internal {
    lastSender = from;
    ERC777(ETTO).transfer(lastSender, profit);
    emit Redistributed(address(this), lastSender, profit);
    reserve1 -= profit;
    reset();
}

 function handleStarter(uint256 amount) internal {
        reserve1 += amount;
        emit AddLiquidityToken1(starter, address(this), amount, ETTO);
        transfersCount++;
        emit TransfersCount(transfersCount.toString());
    }

    function reset() internal {
        transfersCount = 0;
        cycleId++;
        emit CycleId(cycleId);
    }

    receive() external payable {
        if (msg.sender != starter) {
            address buyer = msg.sender;
            uint256 ethIn = msg.value;
            buy(buyer, ethIn);
        } else  if (msg.sender == starter) {
            reserve0 += msg.value;
            emit AddLiquidityToken0(starter, msg.value);
        }
    }

    // Trading

            function getEthToToken() public view returns (uint256) {
        require(reserve0 > 0 && reserve1 > 0, "AMM: INSUFFICIENT_LIQUIDITY");
            return DSMath.wdiv(reserve1, reserve0);

    }

        function getTokenToEth() public view returns (uint256) {
        require(reserve0 > 0 && reserve1 > 0, "AMM: INSUFFICIENT_LIQUIDITY");
            return DSMath.wdiv(reserve0, reserve1);

    }


         function buy(address buyer, uint256 ethIn) internal nonReentrant {
        uint256 tokenOut = getTokenOut(ethIn);
        uint256 maxTokenToBuy = maxBuyPerTxn();
        require(tokenOut <= maxTokenToBuy, "Exceeds max token to buy");
        deliverTokens(buyer, tokenOut);
        emit Bought(buyer, ethIn, tokenOut, getEthToToken());
        recordTrade(buyer, true, tokenOut, ethIn);
        reserve0 += ethIn;
        reserve1 -= tokenOut;
        transfersCount++;
    }

      function maxBuyPerTxn() public view returns (uint256) {
            uint256 maxDynamic = availableForBuy();
             uint256 MAX_BUY_PER_TXN = 9 * 10 ** 18;
            if (maxDynamic < MAX_BUY_PER_TXN) {
                return maxDynamic;
            }
            return MAX_BUY_PER_TXN;
        }


        function availableForBuy() public view returns (uint256) {
        uint256 threshold = 1 * 10 ** 18; // If lees than 1 token, it stops selling
        if (reserve1 > threshold) {
            
            return DSMath.sub(reserve1, threshold);
        }
        return 0;
    }

        
   function getTokenOut(uint256 ethIn) public view returns (uint256) {
        return DSMath.wmul(ethIn, getEthToToken());
    }



    function availableForSell() public view returns (uint256) {
        uint256 maxReserve = 60 * 10 ** 18;
        uint256 minEthReserve = 0.001 * 10 ** 18;
        if (reserve1 > maxReserve && reserve0 < minEthReserve) {
            return 0;
        }
      
              if (reserve1 < maxReserve && reserve0 > minEthReserve) {
           uint256 maxMaticToSpend = DSMath.sub(reserve0, minEthReserve);
            uint256 maxTokenToSell = DSMath.wmul(maxMaticToSpend, getEthToToken());
            return maxTokenToSell / 6;

        }
        return 0;
    }


     function sell(address from, uint256 amount) internal nonReentrant{
        address payable seller = payable(from);
        require(reserve0 > 0.001 * 10 ** 18, "Minimum reserve not met");
        require(reserve1 <= 60 * 10 ** 18, "Contract trades if fulfilled less than 60%");
        uint256 maxTokenToSell = availableForSell();
        uint256 ethOut = getEthOut(amount);
        require(amount <= maxTokenToSell, "Exceeds max token to sell");
        require(reserve0 - ethOut >= 0.001 * 10 ** 18, "Insufficient reserve after sell");

        seller.transfer(ethOut);
        emit Sold(payable(seller), amount, ethOut, getTokenToEth());
        recordTrade(seller, false, amount, ethOut);
        reserve1 += amount;
        reserve0 -= ethOut;
        transfersCount++;
    }
    
     function getEthOut(uint256 amount) public view returns (uint256) {
        return DSMath.wmul(amount, getTokenToEth());
    }

    function deliverTokens(address buyer, uint256 tokenOut) internal {
        require(buyer == msg.sender, "Buyer must be the transaction sender");
        ERC777(ETTO).transfer(buyer, tokenOut);
    }

    function recordTrade(address trader, bool isBuy, uint256 tokenAmount, uint256 ethAmount) internal {
    // Use tokenToEth to get price in AVAX per ETTO_V2
    uint256 price = getTokenToEth(); // this returns: 1 ETTO_V2 = X AVAX

    lastTradePrice = price;
    cumulativePrice += price;
    totalVolume += tokenAmount;
    lastTradeTimestamp = block.timestamp;

    emit TradeRecorded(trader, isBuy, tokenAmount, ethAmount, price);
}

}


