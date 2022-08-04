// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7 .0 < 0.9 .0;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract NFT is ERC721Enumerable, Ownable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    using Strings
    for uint256;

    address s_owner;
    string public baseURI;
    string public notRevealedUri;
    string public baseExtension = ".json";
    uint16 constant public maxSupply = 10050;

    /// @notice CHAINLINK VRF implementation
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    uint32 callbackGasLimit = 100000;
    uint32 numWords = 2;
    uint64 s_subscriptionId;
    uint256[] public s_randomWords;
    uint256 public s_requestId;

    /// @notice contract has public, whitelisted & premium whitelist
    uint256 public cost = 0.003 ether;
    uint256 public wCost = 0.002 ether;
    uint256 public pWCost = 0.001 ether;

    /// @notice checks if contract is paused, if metadata is revealed and if uri is frozen
    bool public paused;
    bool public revealed;
    bool public frozenURI;


    /// @notice used to find unminted ID
    uint16[maxSupply] public mints;

    /// @notice whitelisted addresses are added here
    mapping(address => bool) public isPremiumWhitelisted;
    mapping(address => bool) public isWhitelisted;

    constructor(string memory _name, string memory _symbol, string memory _unrevealedURI, uint64 subscriptionId) ERC721(_name, _symbol) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        setUnrevealedURI(_unrevealedURI);

        /// @notice an array of thousands of numbers would be too long to hardcode it. So we are using constructor to generate all numbers for us.
        /// @dev generates all possible IDs of NFTs that our findUnminted() function picks from
        for (uint16 i = 0; i < maxSupply; ++i) {
            mints[i] = i;
        }
    }

    /// @notice checks if contract is not paused
    modifier notPaused {
        require(!paused);
        _;
    }

    function _baseURI() internal view virtual override returns(string memory) {
        return baseURI;
    }

    /// @notice returns random number from Chainlink VRF
    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() public returns(uint) {
        // Will revert if subscription is not set and funded.
        uint _requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        return _requestId;
    }

    // Chainlink VRF function
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }

    /// @notice calls for random number and picks corresponding NFT
    /// @dev deletes used ID from array and moves the last uint to it's place. Also shortens arrays length, so it would be impossible to pick same number.
    function findUnminted() internal returns(uint) {
        uint supply = totalSupply();
        uint index = requestRandomWords() % (maxSupply - supply);
        uint chosenNft = mints[index];
        uint swapNft = mints[maxSupply - supply - 1];
        mints[index] = uint16(swapNft);
        return (chosenNft);
    }

    /// @notice mints NFT with corresponding price
    /// @dev checks if address has premium whitelist or whitelist. If not, uses public price.
    function mint(address _to, uint256 _mintAmount) public payable notPaused {
        uint256 supply = totalSupply();
        require(_mintAmount > 0);
        require(supply + _mintAmount <= maxSupply);
        if( msg.sender != owner()) {
        if (isPremiumWhitelisted[_to]) {
            require(_mintAmount == 1, "You can only have one whitelisted mint");
            require(msg.value >= pWCost * _mintAmount, "PremiumMint: Not enough ether");
            isPremiumWhitelisted[_to] = false;
        } else if (isWhitelisted[_to]) {
            require(_mintAmount == 1, "You can only have one whitelisted mint");
            require(msg.value >= wCost * _mintAmount, "WhitelistedMint: Not enough ether");
            isWhitelisted[_to] = false;
        } else {
            require(msg.value >= cost * _mintAmount, "Mint: Not enough ether");
        }
        }

        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(_to, findUnminted());
        }
    }

    function checkOwner() public view returns(address) {
        return (owner());
    }

    /// @notice returns all NFT IDs owned
    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);

        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokenIds;
    }

    /// @notice returns URI
    function tokenURI(uint256 tokenId) public view virtual override returns(string memory) {
        require(_exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)) : "";
    }

    //only owner

    /// @notice frozen URI will no longer be able to be changed
    function freezeURI() public onlyOwner {
        frozenURI = true;
    }

    /// @notice revealed URI
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        require(!frozenURI, "URI is frozen");
        baseURI = _newBaseURI;
    }

    /// @notice unrevealed URI
    function setUnrevealedURI(string memory _unrevealedURI) public onlyOwner {
        require(!frozenURI, "URI is frozen");
        notRevealedUri = _unrevealedURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    /// @notice reveals new metadata
    function reveal() public onlyOwner {
        revealed = true;
    }

    /// @notice emergency pause. If something goes wrong, we could pause the mint function
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    /// @notice whitelists array of addresses for premium price
    /// @dev argument should look like this: ["0x00", "0x00"]
    function setPremiumWhitelist(address[] memory _addresses, bool _bool) public onlyOwner {
        for (uint i; i < _addresses.length; i++) {
            isPremiumWhitelisted[_addresses[i]] = _bool;
        }
    }

    /// @notice whitelists array of addresses for whitelisted price
    /// @dev argument should look like this: ["0x00", "0x00"]
    function setWhitelist(address[] memory _addresses, bool _bool) public onlyOwner {
        for (uint i; i < _addresses.length; i++) {
            isWhitelisted[_addresses[i]] = _bool;
        }
    }

    /// @notice edits chainlink VRF ID
    function editSubscribtionId(uint64 _id) public onlyOwner {
        s_subscriptionId = _id;
    }

    /// @notice only owner withdraw
    function withdraw() public onlyOwner {
        (bool oc, ) = payable(owner()).call {
            value: address(this).balance
        }("");
        require(oc);
    }
}
