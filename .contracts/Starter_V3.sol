// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC777/ERC777.sol";
import "/.deps/github/dapphub/ds-math/src/math.sol";         

contract Starter_V3 is IERC777Recipient, DSMath, ReentrancyGuard {
    
    address public owner;
    ERC777 public immutable ETTO;
    address public immutable joker;
    uint256 public immutable jokerPercentage = 9;
    bool private jokerSet = false;

    event AddLiquidityToken1(address from, address indexed to, uint256 amount, ERC777 token1, uint256 jokerAmount);
    event AddLiquidityToken0(address from, address indexed to, uint256 amount);
 

    constructor(ERC777 _etto, address _joker) {
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
            .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));

       
        owner = msg.sender;
        ETTO = _etto;
        joker = _joker;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyValidToken() {
        require(msg.sender == address(ETTO), "Only valid tokens are accepted");
        _;
    }

     function setJoker(address _joker) external onlyOwner {
        require(_joker != address(0), "Invalid address");
        require(!jokerSet, "Presale address has already been set.");
        jokerSet = true;
    }

    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external override onlyValidToken {
        require(operatorData.length >= 0, "OperatorData cannot be empty");
        require(userData.length >= 0, "UserData cannot be empty");
        require(to != address(0), "to cannot be the null address");
        require(operator != address(0), "Operator cannot be the null address");
        require(from == owner, "Only the owner can send tokens to this contract");
         forwardTokens(amount);    
        
    }

   
  receive() external payable {
    forwardMatic(msg.value);
}

           struct Destination 
    {
        address payable redistributor;
        string name;    
    }
    
    Destination[11] public destinations;
    uint256 private destinationCount;

    function addDestination(address payable redistributor, string memory name) 
        public onlyOwner 
    {
        require(destinationCount < 11, "Maximum number of destinations reached.");
        require(msg.sender == owner, "Only the owner can set this struct");
        destinations[destinationCount] = Destination(redistributor, name);
        destinationCount++;
    }
    

   function forwardTokens(uint256 tokenAmount) internal {
        require(destinationCount > 0, "No redistributors set");
        require(tokenAmount > 0, "Token amount must be > 0");

        uint256 jokerAmount = (tokenAmount * jokerPercentage) / 100;
        uint256 remaining = tokenAmount - jokerAmount;
        uint256 perRedistributor = remaining / destinationCount;

        if (jokerAmount > 0 && joker != address(0)) {
            ETTO.transfer(joker, jokerAmount);
            
        }

        for (uint256 i = 0; i < destinationCount; i++) {
            ETTO.transfer(destinations[i].redistributor, perRedistributor);
        }

        emit AddLiquidityToken1(address(this), destinations[0].redistributor, tokenAmount, ETTO, jokerAmount);
    }


     function forwardMatic(uint256 maticIn) internal {
            uint256 maticPerRedistributor = (maticIn / destinationCount);
            for (uint256 i = 0; i < destinationCount; i++) {
                (bool success, ) = destinations[i].redistributor.call{value: maticPerRedistributor}("");
                require(success, "Failed to send Matic to redistributor");
            }
            
            emit AddLiquidityToken0(address(this), destinations[0].redistributor, maticIn);
        }


}
