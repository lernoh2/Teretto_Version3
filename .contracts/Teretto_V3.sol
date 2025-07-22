// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC777/ERC777.sol";
import "/.deps/github/OpenZeppelin/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Teretto_V3 is ERC777 {
    using SafeMath for uint256;

    address public owner;
    address public starter;

    bool private starterSet = false;

    uint256 public constant COMMUNITY_SHARE = 90;
    uint256 public constant FIXED_TRANSFER_AMOUNT = 100 ether;
    uint256 public constant BLOCKED_AMOUNT = 7.5 ether;

    event TransferSentToL(address from, address redistributor, uint256 redAmount);
    event TransferSent(address from, address recipient, uint256 amount);
    event TransferForTrade(address from, address recipient, uint256 amount);

    constructor() ERC777("Teretto", "ETTO_V3", new address[](0)) {
        _mint(msg.sender, 220000 * 10 ** 18, "", "");
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    struct Destination {
        address payable redistributor;
        string name;
    }

    Destination[12] public destinations;
    uint256 private destinationCount;

    function addDestination(address payable redistributor, string memory name) public onlyOwner {
        require(destinationCount < 12, "Maximum number of destinations reached.");
        require(msg.sender == owner, "Only the owner can set this struct");
        destinations[destinationCount] = Destination(redistributor, name);
        destinationCount++;
    }

    function setStarter(address _starter) external onlyOwner {
        require(_starter != address(0), "Invalid address");
        require(!starterSet, "Presale address has already been set.");
        starter = _starter;
        starterSet = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        address sender = _msgSender();

        // Redistributor or owner move — full transfer
        for (uint i = 0; i < destinationCount; i++) {
            if (recipient == destinations[i].redistributor || sender == destinations[i].redistributor || sender == owner) {
                require(amount != BLOCKED_AMOUNT, "You can't send exactly 0.3 tokens");
                _send(sender, recipient, amount, "", "", false);
                emit TransferForTrade(sender, recipient, amount);
                emit Transfer(sender, recipient, amount); // Standard event
                return true;
            }
        }

        // Starter address can transfer freely
        if (sender == starter) {
            _send(sender, recipient, amount, "", "", true);
            emit Transfer(sender, recipient, amount);
            return true;
        }

        // Enforce exact transfer amount
        require(amount == FIXED_TRANSFER_AMOUNT, "Only fixed amount transfers allowed");

        uint256 communityFee = amount * COMMUNITY_SHARE / 100;
        uint256 splitFee = communityFee / destinationCount;
        uint256 remainder = amount.sub(communityFee);

        for (uint i = 0; i < destinationCount; i++) {
            _send(sender, destinations[i].redistributor, splitFee, "", "", true);
            emit TransferSentToL(sender, destinations[i].redistributor, splitFee);
            emit Transfer(sender, destinations[i].redistributor, splitFee);
        }

        _send(sender, recipient, remainder, "", "", true);
        emit TransferSent(sender, recipient, amount);
        emit Transfer(sender, recipient, remainder);
        return true;
    }
}
