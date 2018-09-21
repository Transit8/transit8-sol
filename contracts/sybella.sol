pragma solidity ^0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (_a == 0) {
      return 0;
    }

    uint256 c = _a * _b;
    require(c / _a == _b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
    require(_b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = _a / _b;
    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
    require(_b <= _a);
    uint256 c = _a - _b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
    uint256 c = _a + _b;
    require(c >= _a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}


contract ArtMarket {
  address public owner;

  struct Item {
    string title;
    string blockstackUrl;
    bytes32 hash;   //can also be used as a pointer to the item in IPFS storage
    uint ownerIndex;
    mapping (uint => address) owners;
    uint price;
    bool inAuction;
  }
  mapping (uint => Item) public items;
  int public itemIndex = -1;

  mapping(bytes32 => bool) public itemExists;

  struct Auction {
      uint itemID;
      uint created;
      uint duration;
      uint reserve;
      uint increment;
      address curator;
      uint highestBid;
      address highestBidder;
      mapping(address => uint) bids;
      bool closed;
  }
  mapping (uint => Auction) public auctions;
  int public auctionIndex = -1;

  mapping (address => string) public profiles;



  constructor() public {
    owner = msg.sender;
  }


  function registerProfile(string url) public {
      profiles[msg.sender] = url;
  }

  //blockstackUrl is empty if the item is stored on IPFS
  function addItem(string title, bytes32 hash, string blockstackUrl) public {
    require(!itemExists[hash]);
    itemIndex++;
    items[uint(itemIndex)].title = title;
    items[uint(itemIndex)].hash = hash;
    items[uint(itemIndex)].blockstackUrl = blockstackUrl;
    items[uint(itemIndex)].ownerIndex = 0;
    items[uint(itemIndex)].owners[0] = msg.sender;
    itemExists[hash] = true;
  }

  /* set price to 0 to cancel sale */
  function sell(uint itemID, uint price) public {
      require(items[itemID].owners[items[itemID].ownerIndex] == msg.sender && !items[itemID].inAuction);
      items[itemID].price = price;
  }

  function buy(uint itemID, string blockstackUrl) payable public {
    if(items[itemID].price > 0 && msg.value == items[itemID].price) {
      items[itemID].owners[items[itemID].ownerIndex].transfer(msg.value);
      items[itemID].ownerIndex++;
      items[itemID].owners[items[itemID].ownerIndex] = msg.sender;
      items[itemID].blockstackUrl = blockstackUrl;
      items[itemID].price = 0;
    }
  }

  function startAuction(uint itemID, uint duration, uint reserve, uint increment) public {
    require(msg.sender == items[itemID].owners[items[itemID].ownerIndex] && items[itemID].price == 0);  //only possible to auction items that you own and cannot be listed for direct sale
    auctionIndex++;
    auctions[uint(auctionIndex)].itemID = itemID;
    auctions[uint(auctionIndex)].duration = duration;
    auctions[uint(auctionIndex)].reserve = reserve;
    auctions[uint(auctionIndex)].increment = increment;
    auctions[uint(auctionIndex)].curator = msg.sender;
    auctions[uint(auctionIndex)].created = now;
    items[itemID].inAuction = true;
  }

  function closeAuction(uint auctionID) public {
    require(!auctions[auctionID].closed && auctions[auctionID].created > 0);
    if(now - auctions[auctionID].created > auctions[auctionID].duration) {
      if(auctions[auctionID].highestBid > 0) {
        items[auctions[auctionID].itemID].owners[items[auctions[auctionID].itemID].ownerIndex].transfer(auctions[auctionID].highestBid);
        items[auctions[auctionID].itemID].ownerIndex++;
        items[auctions[auctionID].itemID].owners[items[auctions[auctionID].itemID].ownerIndex]= auctions[auctionID].highestBidder;
      }
      auctions[auctionID].closed = true;
      items[auctions[auctionID].itemID].inAuction = false;
    }
  }

  function reclaimEscrow(uint auctionID) public {
    require(auctions[auctionID].closed && auctions[auctionID].highestBidder != msg.sender);
    msg.sender.transfer(auctions[auctionID].bids[msg.sender]);
    auctions[auctionID].bids[msg.sender] = 0;
  }

  function placeBid(uint auctionID) payable public {
     require(!auctions[auctionID].closed && auctions[auctionID].created > 0 && msg.value + auctions[auctionID].bids[msg.sender] > auctions[auctionID].reserve && msg.value + auctions[auctionID].bids[msg.sender] > SafeMath.add(auctions[auctionID].highestBid, auctions[auctionID].increment));
     auctions[auctionID].highestBidder = msg.sender;
     auctions[auctionID].highestBid = auctions[auctionID].bids[msg.sender] + msg.value;
     auctions[auctionID].bids[msg.sender] = auctions[auctionID].bids[msg.sender] + msg.value;
  }


  function getItemOwner(uint itemID, uint ownerIndex) public constant returns(address) {
      return items[itemID].owners[ownerIndex];
  }

  function getMyBid(uint auctionID) public constant returns(uint) {
      return auctions[auctionID].bids[msg.sender];
  }

}
