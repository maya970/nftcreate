// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTMinter is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    
    // NFT metadata
    struct NFTInfo {
        string imageURI;
        bool gasSponsored;
        uint256 maxSupply;
        uint256 currentSupply;
    }
    
    // Whitelist mapping
    mapping(address => uint256[]) public whitelist;
    // NFT collection mapping
    mapping(uint256 => NFTInfo) public nftCollections;
    // Collection counter
    Counters.Counter private _collectionIdCounter;
    // Creator's collections
    mapping(address => uint256[]) public creatorCollections;
    
    // Events
    event CollectionCreated(uint256 indexed collectionId, string imageURI, bool gasSponsored, uint256 maxSupply);
    event WhitelistAdded(uint256 indexed collectionId, address[] users);
    event MaxSupplyUpdated(uint256 indexed collectionId, uint256 newMaxSupply);
    
    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {}
    
    // Creator creates a new NFT collection
    function createCollection(string memory imageURI, bool gasSponsored, uint256 maxSupply) 
        external onlyOwner returns (uint256) 
    {
        require(maxSupply > 0, "Max supply must be greater than 0");
        uint256 collectionId = _collectionIdCounter.current();
        nftCollections[collectionId] = NFTInfo({
            imageURI: imageURI,
            gasSponsored: gasSponsored,
            maxSupply: maxSupply,
            currentSupply: 0
        });
        creatorCollections[msg.sender].push(collectionId);
        _collectionIdCounter.increment();
        emit CollectionCreated(collectionId, imageURI, gasSponsored, maxSupply);
        return collectionId;
    }
    
    // Creator adds users to whitelist
    function addToWhitelist(address[] memory users, uint256 collectionId) 
        external onlyOwner 
    {
        require(nftCollections[collectionId].maxSupply > 0, "Invalid collection");
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid address");
            whitelist[users[i]].push(collectionId);
        }
        emit WhitelistAdded(collectionId, users);
    }
    
    // Creator updates max supply
    function updateMaxSupply(uint256 collectionId, uint256 newMaxSupply) 
        external onlyOwner 
    {
        require(nftCollections[collectionId].maxSupply > 0, "Invalid collection");
        require(newMaxSupply >= nftCollections[collectionId].currentSupply, "New supply less than minted");
        nftCollections[collectionId].maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(collectionId, newMaxSupply);
    }
    
    // Recipient mints an NFT
    function mintNFT(uint256 collectionId) external payable {
        NFTInfo storage collection = nftCollections[collectionId];
        require(collection.maxSupply > 0, "Invalid collection");
        require(collection.currentSupply < collection.maxSupply, "Max supply reached");
        
        // Check whitelist
        bool isWhitelisted = false;
        for (uint256 i = 0; i < whitelist[msg.sender].length; i++) {
            if (whitelist[msg.sender][i] == collectionId) {
                isWhitelisted = true;
                break;
            }
        }
        require(isWhitelisted, "Not whitelisted");
        
        // Handle gas fee
        if (!collection.gasSponsored) {
            require(msg.value >= 0.001 ether, "Insufficient gas fee");
        }
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        collection.currentSupply++;
        _safeMint(msg.sender, tokenId);
    }
    
    // Get user's whitelisted collections
    function getUserCollections(address user) external view returns (uint256[] memory) {
        return whitelist[user];
    }
    
    // Get creator's collections
    function getCreatorCollections(address creator) external view returns (uint256[] memory) {
        return creatorCollections[creator];
    }
    
    // Get NFT metadata
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return nftCollections[tokenId % 1000].imageURI;
    }
    
    // Withdraw contract balance (only owner)
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
