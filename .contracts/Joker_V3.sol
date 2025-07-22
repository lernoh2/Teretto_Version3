// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC777/ERC777.sol";
import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/utils/Strings.sol";
import "/.deps/github/dapphub/ds-math/src/math.sol";         

contract Joker_V3 is IERC777Recipient, DSMath, ReentrancyGuard {
    using Strings for uint256;

    address public owner;
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
 
     event Received(address from, address to, uint256 amount);
    event RandomNumber1(uint256 randomNumber);
    event RandomNumber2(uint256 randomNumber);
    event RandomNumber3(uint256 randomNumber);
    event RandomNumbersSum(uint256 sum);
    event TransfersCount(string transfersCount);
    event CycleId(uint256 cycleId);
    event Redistributed(address indexed from, address indexed to, uint256 profit);
    event AddLiquidityToken1(address indexed starter, address to, uint256 amount, ERC777 token1);
    event RedistributionAttempt(
        address indexed sender,
        uint256 random1,
        uint256 random2,
        uint256 random3,
        uint256 transferCount,
        bool triggered,
        uint256 profitTransferred
    );

 
 

    constructor(ERC777 _etto) {
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
            .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));

        cycleId = 1;
        owner = msg.sender;
        ETTO = _etto;
        reserve1 = tokenBalance();
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

    function tokenBalance() public view returns(uint256) {
        return ERC777(ETTO).balanceOf(address(this));
    }


    function getTransfersCount() public view returns (uint256) {
        return transfersCount;
    }

    function theRandomNumber1() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(transfersCount, owner, randomNumber5(), msg.sender, randomNumber4(), blockhash(block.number-1), cycleId, address(this), lastSender, profit, randomNumber6()));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 10 + 2;
        return randomNumber;
    }

    function theRandomNumber2() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(profit,  randomNumber5(), owner, msg.sender, randomNumber6(), transfersCount,  blockhash(block.number-1), address(this), cycleId, lastSender, randomNumber4()));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 10 + 2;
        return randomNumber;
    }

    function theRandomNumber3() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(cycleId, transfersCount, address(this), randomNumber5(), profit, lastSender, msg.sender, owner, randomNumber4(), randomNumber6(), blockhash(block.number-1)));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 10 + 2;
        return randomNumber;
    }

    function randomNumber4() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(transfersCount, owner, msg.sender, blockhash(block.number-1), cycleId, address(this), lastSender, profit));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 3100 + 2;
        return randomNumber;
    }

    function randomNumber5() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(profit, owner, msg.sender, transfersCount,  blockhash(block.number-1), address(this), cycleId, lastSender));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 3200 + 2;
        return randomNumber;
    }

    function randomNumber6() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(cycleId, transfersCount, address(this), profit, lastSender, msg.sender, owner, blockhash(block.number-1)));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 3300 + 2;
        return randomNumber;
    }

 
    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external override onlyValidToken {
        require(operatorData.length >= 0, "OperatorData cannot be empty");
        require(userData.length >= 0, "UserData cannot be empty");
        require(to != address(0), "to cannot be the null address");
        require(operator != address(0), "Operator cannot be the null address");
        require(from != address(0), "From cannot be the null address");

        if (from != owner && amount == 7.5 * 10 ** 18) {
            handleTransfer(from, amount);
        } else if (from == owner) {
            handleOwner(amount);
        }
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


   function getRandomNumbersSum() public view returns (uint256) {
    return randomNumber1 + randomNumber2 + randomNumber3;
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

        uint256 sum = getRandomNumbersSum();
        emit RandomNumbersSum(sum);

        bool triggered = false;
        uint256 transferredProfit = 0;

        if (sum == 21) {
            profit = DSMath.wdiv(DSMath.wmul(reserve1, 30), 100);
            transferredProfit = profit;
            redistribute(from);
            triggered = true;
        }

        emit RedistributionAttempt(from, randomNumber1, randomNumber2, randomNumber3, transfersCount, triggered, transferredProfit);
    }

    function handleOwner(uint256 amount) internal {
        reserve1 += amount;
        emit AddLiquidityToken1(owner, address(this), amount, ETTO);
        transfersCount++;
        emit TransfersCount(transfersCount.toString());
    }

    function redistribute(address from) internal {
    lastSender = from;
     profit = DSMath.wdiv(DSMath.wmul(reserve1, 30), 100);
     ERC777(ETTO).transfer(lastSender, profit);
     emit Redistributed(address(this), lastSender, profit);
     reserve1 -= profit;
     reset();
}


    function reset() internal {
        transfersCount = 0;
        cycleId++;
        emit CycleId(cycleId);
    }

}


