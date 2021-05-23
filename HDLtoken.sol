// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.12;
 
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IDetailedERC20} from "./interfaces/IDetailedERC20.sol";

import "hardhat/console.sol";
 
contract HDLtoken is ReentrancyGuard, AccessControl, ERC20("HDL Token", "HDL") {

  event NftMinted(
    address indexed account,
    uint256 id
    );

  event NftVoted(
    uint256 indexed id,
    uint256 sum
    );

  event NftPriceUpdated(
    uint256 indexed id,
    uint256 price
    );  

  event NftTransferred(
    uint256 indexed id,
    address  oldOwner,
    address  newOwner
    );

  /// @dev The identifier of the role which maintains other roles.
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

  /// @dev The identifier of the role which allows accounts to mint tokens.
  bytes32 public constant MINTER_ROLE = keccak256("MINTER");

  uint constant MAX_SUPPLY = 130000000 * 10 ** 18;
  uint constant INIT_SUPPLY =  8000000 * 10 ** 18;

  constructor() public {
    _setupRole(ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
    _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);

    _mint(msg.sender, INIT_SUPPLY);
  }

  /// @dev A modifier which checks that the caller has the minter role.
  modifier onlyMinter() {
    require(hasRole(MINTER_ROLE, msg.sender), " only minter");
    _;
  }

  /// @dev Mints tokens to a recipient.
  ///
  /// This function reverts if the caller does not have the minter role.
  ///
  /// @param _recipient the account to mint tokens to.
  /// @param _amount    the amount of tokens to mint.
  function mint(address _recipient, uint256 _amount) external onlyMinter {
    if (totalSupply() < MAX_SUPPLY) {
      _mint(_recipient, _amount);
    }
  }

 
  struct NFT { 
     uint256 tokenId;   
     uint256 price;    
     uint256 voteSum;   
     bool tradable;   // vote > 51%
     string name;
     address owner; 
     string url;   
     mapping(address => uint256) voted;  
 }

 uint256 private nftId ;
 mapping(address => uint256[]) public userNft;
 mapping(uint256 => NFT) public nfts;
 
 
 function createNft(string memory _name, string memory _url, uint256 _price)  external nonReentrant returns (uint) {
   //uint256 nftId = uint256(keccak256(abi.encodePacked(_name, _url, now)));
   nftId = nftId + 1;
   NFT storage nft = nfts[nftId];
   nft.tokenId = nftId;
   nft.name = _name;
   nft.owner = msg.sender;
   nft.url = _url;
   nft.price = _price;

   uint256[] storage user = userNft[msg.sender];
   user.push(nftId);

   emit NftMinted(nft.owner, nft.tokenId );

   return nftId;
 }
 
 function ownerOf(uint256 _tokenId) public view returns (address) {
   return nfts[_tokenId].owner;
 }

 
  function numberOf(address _address) public view returns (uint256) {
    return userNft[_address].length;
  }

 
 function vote(uint256 _tokenId) public returns (uint256) {
   NFT storage nft = nfts[_tokenId];

   nft.voteSum = nft.voteSum.sub(nft.voted[msg.sender]).add(balanceOf(msg.sender));
   nft.voted[msg.sender] = balanceOf(msg.sender);

   uint256 pct = totalSupply() * 51 / 100;
   if (nft.voteSum > pct) {
     nft.tradable = true;
   }
    
   emit NftVoted(nft.tokenId, nft.voteSum ); 

   return nft.voteSum;
 }

 
 function buyNft(uint256 _tokenId)   external nonReentrant returns (bool) {
   NFT storage nft = nfts[_tokenId];
   require(nft.tradable , "not tradable");
   require(nft.price > 0 , "price error");

   uint256[] storage usrOld = userNft[nft.owner];
   uint256[] storage usrNew = userNft[msg.sender];
   for (uint256 index = 0; index < usrOld.length; index++) {
     if (usrOld[index] == _tokenId) {
        usrOld[index] = usrOld[usrOld.length - 1];
        usrOld.pop();
     }
   }
   usrNew.push(_tokenId);
   
   transfer(nft.owner , nft.price);
   
   emit NftTransferred(_tokenId, nft.owner, msg.sender);
   nft.owner = msg.sender;

   return true;
 }

 
  function transferNft(uint256 _tokenId, address _to)   external nonReentrant returns (bool) {
   NFT storage nft = nfts[_tokenId];
   require(nft.owner == msg.sender , "not owner");

   uint256[] storage usrOld = userNft[nft.owner];
   uint256[] storage usrNew = userNft[_to];
   for (uint256 index = 0; index < usrOld.length; index++) {
     if (usrOld[index] == _tokenId) {
        usrOld[index] = usrOld[usrOld.length - 1];
        usrOld.pop();
     }
   }
   usrNew.push(_tokenId);
   
   transfer(nft.owner , nft.price);

   emit NftTransferred(_tokenId, nft.owner,_to);
   nft.owner = _to;

   return true;
 }

 
 function tradable( uint256 _tokenId)  public view returns (bool) {
   return nfts[_tokenId].tradable;
 }

 
 function setPrice( uint256 _tokenId, uint256 _price)  public {
   NFT storage nft = nfts[_tokenId];
   require(nft.owner == msg.sender , "not owner");

   nft.price = _price;
   
   emit NftPriceUpdated(_tokenId, nft.price );
 }



}