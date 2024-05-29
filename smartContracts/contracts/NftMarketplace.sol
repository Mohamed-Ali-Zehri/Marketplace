//SPDX-License-Identifier: UNLICENSED

pragma solidity^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract SubscriptionModel {
    mapping(uint256 => uint64) internal _expirations;

    /// @notice Emitted when a subscription expiration changes
    /// @dev When a subscription is canceled, the expiration value should also be 0.
    event SubscriptionUpdate(uint256 indexed tokenId, uint64 expiration);

    /// @notice Renews the subscription to an NFT
    /// Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to renew the subscription for
    /// @param duration The number of seconds to extend a subscription for
    function renewSubscription(
        uint256 _tokenId,
        uint64 duration
    ) external payable {
        uint64 currentExpiration = _expirations[_tokenId];
        uint64 newExpiration;
        if (currentExpiration == 0) {
            //block.timestamp -> Current block timestamp as seconds since unix epoch
            newExpiration = uint64(block.timestamp) + duration;
        } else {
            require(isRenewable(_tokenId), "Subscription Not Renewable");
            newExpiration = currentExpiration + duration;
        }
        _expirations[_tokenId] = newExpiration;
        emit SubscriptionUpdate(_tokenId, newExpiration);
    }

    /// @notice Cancels the subscription of an NFT
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to cancel the subscription for
    function cancelSubscription(uint256 _tokenId) external payable {
        delete _expirations[_tokenId];
        emit SubscriptionUpdate(_tokenId, 0);
    }

    /// @notice Gets the expiration date of a subscription
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to get the expiration date of
    /// @return The expiration date of the subscription
    function expiresAt(uint256 _tokenId) external view returns (uint64) {
        return _expirations[_tokenId];
    }

    /// @notice Determines whether a subscription can be renewed
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to get the expiration date of
    /// @return The renewability of a the subscription - true or false
    function isRenewable(uint256 tokenId) public pure returns (bool) {
        return true;
    }
}


contract NftMarketplace is ERC721URIStorage{
    constructor () ERC721 ("NftMarketplace" , "nft"){
    }
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    Counters.Counter private nftAvailableForSale;
    Counters.Counter private userIds;

    struct nftStruct{
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 price;
        address [] subscribers;
        uint256 likes;
        string title;
        string description;
    }


    struct profileStruct{
        address self;
        address [] followers;
        address [] followers;
    }
    mapping (uint256 => nftStruct) private nfts;

    mapping (uint256 => profileStruct) private profiles;
    event NftStructCreated(
        uint256 tokenId,
        address payable seller,
        address payable buyer,
        uint256 price,
        address [] subscribers,
        uint256 likes,
        string title,
        string description
    );

        function setNft(
            uint256 _tokenId,
            string memory _title,
            string memory _description
            ) private{
        nfts[_tokenId].tokenId = _tokenId;
        nfts[_tokenId].seller =payable (msg.sender);
        nfts[_tokenId].buyer = payable (msg.sender);
        nfts[_tokenId].price = 0;
        nfts[_tokenId].subscribers = [msg.sender];
        nfts[_tokenId].likes = 0;
        nfts[_title].title = _title;
        nfts[_description].description = _description;
        emit NftStructCreated(
            _tokenId,
            payable (msg.sender),
            payable (msg.receiver),
            0,
            nfts[_tokenId].subscribers,
            nfts[_tokenId].likes ,
            _title,
            _description);
    }
        /// @dev this function mints received nfts
        /// @param _tokenURI the new token URI for the market
        /// @param _title the title for the market
        /// @param _description the description for the market
        /// @return tokenId of the created Nft
    function createNft(
        string memory _tokenURI,
        string memory _title,
        string memory _description
        ) public returns(uint256 ) {
        tokenIds.increment();
        uint256 newTokenId = tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        setNft(newTokenId, _title, _description);
        return newTokenId;
    }
        ///@dev sell a magazine suscription to the public so that is visible to the nft market place
        /// @param _tokenId the token id to the nft magazine
        ///@param _price the price for the magazine subscription
        ///@return total number of the available nft subscriptions
        function sellSubscription(uint256 _tokenId, uint256 _price) public returns(uint256 ) {
            require(_isApprovedOrOwner(msg.sender, _tokenId), "only the owner of the nft can perform this");
            _transfer(msg.sender,address(this),tokenId);
            nfts[_tokenId].price = _price;
            nfts[_tokenId].owner = payable(address(this));
            nftAvailableForSale.increment;
            return nftAvailableForSale;
        }

        ///@dev buy magazine subscription from the marketplace
        ///@param _tokenId the token ID of the nft marketplace
        ///@return true
        function buySubscription(uint256 _tokenId) public payable returns(bool){
            uint256 price = nft[_tokenId].price;
            require(msg.value == price, "Not enough coins for the subscription ");
            
            payable(nfts[_tokenId].seller).transfer(msg.value);
            nfts[_tokenId].subscribers.push(msg.sender);
            return true;
        }

        ///@dev fetch available NFTs for sale that will be displayed on the market
        ///@return nftStruct[] list of the nfts with their metadata
        function getSubscriptions() public view returns(nftStruct[] memory){
            uint256 subscriptions = nftAvailableForSale.current();
            uint256 nftCount = tokenIds.current();
            nftStruct[] memory nftSubscriptions = new nftStruct[];
            for (uint256 i = 0; i < nftCount; i++){
                if(nfts[i].owner == address(this)){
                    nftSubscriptions[i] = nfts[i];
                }
            }
            return nftSubscriptions;
        }
        ///@dev fetches Nft market that a user is already subscribed to
        ///@return nftStruct[] list of nfts collected by a user with their metadata
        function getCollectables ()public returns(nftStruct memory){
            uint256 nftCount = tokenIds.current();
            nftStruct [] memory nftSubscriptions;
            for(uint256 i = 1 ; i < nftCount ; i++){
                uint256 subscribers = nfts[i].subscribers.length;
                for(uint256 j=0; j < subscribers ; j++){
                    if(nfts[i].subscribers[j] == msg.sender){
                        nftSubscriptions[i] = nfts[i];
                    }
                }
            }
            return nftSubscriptions;
        }

        ///@dev fetches Nft market that specefic user has created
        ///@return nftStruct[] list of nft created by user with their metadata
        function getNfts() public returns (nftStruct [] memory){
            uint256 nftCount = tokenIds.current();
            nftStruct [] memory nftSubscriptions;
            for (uint256 i = 1; i < nftCount; i++){
                if(nfts[i].seller == msg.sender){
                    nftSubscriptions[i] = nfts[i];
                }
            }

            return nftSubscriptions;
        }
        ///@dev fetches details of a particular Nft margazine subscriptions
        ///@param _toekenId the token ID of the nft marketplace
        ///@return nftStruct[] data of the specific token ID
        function getIndividualNFT(uint256 _tokenId) public returns(nftStruct memory){
            return nfts[_tokenId];
        }
        ///@dev add msg.sender as the  profile
        ///@return userId and balance of the msg.sender
        function addProfile() public returns(uint256 userId, uint256 balance){
            userIds.increment();
            uint256 newUserId = userIds.current();
            profiles[newUserId].self = msg.sender;
            userId = newUserId;
            balance = msg.sender.balance;
        }

        ///@dev increment the following tag of the profile performing the action, and the follower tag of the profile that user wants to
        ///@param _account the account user want to follow
        function followProfile(address _account)public{
            uint256 totalCount = userId.current();
            for(uint256 i = 1 ; i < totalCount; i++){
                if(profiles[i].self == payable (msg.sender)){
                    profiles[i].following.push(_account);
                }
                if(profiles[i].self == _account){
                    profiles[i].followers.push(payable (msg.sender));
                }
            }
        }
        ///@dev increment the following tag of the profile performing the action, and the follower tag of the profile that user wants to
        ///@param _account the account user want to follow
        function unfollowProfile(address _account)public view{
            uint256 totalCount = userId.current();
            for(uint256 i = 1 ; i < totalCount; i++){
                removeFollowing(profiles[i].self, profiles[i].followers, _account);
                removeFollower(profiles[i].self, profiles[i].following, payable(msg.sender));
            }
        }
    function removeFollowing(address _owner, address[] memory _followers, address _account) private view{
        if(_owner == _account){
            address [] memory currentFollowing = _followers;
            for (uint256 j = 0; j < currentFollowing.length; j++) {
                if(currentFollowing[j] == payable(msg.sender)){
                    delete currentFollowing[j];
                }
            }
        }
    }
    function removeFollower(address _owner, address[] memory _following, address _account) private pure{
        if(_owner == _account){
            address [] memory currentFollowers = _following;
            for (uint256 j = 0; j < currentFollowing.length; j++) {
                if(currentFollowers[j] == _account){
                    delete currentFollowers[j];
                }
            }
        }
    }
    ///@dev increments number of likes for the nft market place by 1
    ///@param _tokenId the token ID of the NFT magazine
    function likeSubscription(uint256 _tokenId) public {
        nfts[_tokenId].likes += 1;
    }
    ///@dev decrements number of likes for the nft market place by 1
    ///@param _tokenId the token ID of the NFT magazine
    function unlikeSubscription(uint256 _tokenId) public {
        nfts[_tokenId].likes -= 1;
    }

}