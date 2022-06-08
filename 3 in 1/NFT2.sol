// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7 .0 < 0.9 .0;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @notice interface for staking function
interface Interface {
    function viewAllocatedTokens(address _address) external view returns(uint);
    function viewsubtractedTokens(address _address) external view returns(uint);
    function viewActiveTokens(address _address) external view returns(uint);
    function subtractTokens(address _address, uint _tokens) external;
}

contract NFT2 is ERC721Enumerable, Ownable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    using Strings
    for uint256;

    /// @notice staking functions address
    address public parentContract;
    string public baseURI;
    string public notRevealedUri;
    string public baseExtension = ".json";
    /// @notice there is 3 discount levels. Set how many staked tokens each level will cost
    uint16 public tokensFor10 = 200;
    uint16 public tokensFor30 = 400;
    uint16 public tokensFor50 = 800;
    uint16 constant public maxSupply = 10;
    uint256 public cost = 1500 ether;
    /// @notice set prices for each level
    uint256 public costfor10 = 1350 ether;
    uint256 public costfor30 = 1050 ether;
    uint256 public costfor50 = 750 ether;

    /// @notice CHAINLINK VRF implementation
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    uint32 callbackGasLimit = 100000;
    uint32 numWords = 2;
    uint64 s_subscriptionId;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    /// @notice checks if contract is paused, if metadata is revealed and if uri is frozen
    bool public paused;
    bool public revealed;
    bool public frozenURI;


    /// @notice used to find unminted ID
    uint16[maxSupply] public mints;

    mapping(string => bool) public codeIsTaken;
    mapping(string => address) internal ownerOfCode;

    constructor(string memory _name, string memory _symbol, string memory _unrevealedURI, uint64 subscriptionId, address _parentContract) ERC721(_name, _symbol) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        parentContract = _parentContract;
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        setUnrevealedURI(_unrevealedURI);

        /// @notice an array of lets say 10,000 numbers would be too long to hardcode it. So we are using constructor to generate all numbers for us.
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

    /// @notice normal public mint    
    function mint(address _to, uint256 _mintAmount) public payable notPaused {
        require(totalSupply() + _mintAmount <= maxSupply);
        require(_mintAmount > 0);
        require(msg.value >= cost * _mintAmount, "Mint: Not enough ether");


        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(_to, findUnminted());
        }
    }

    /// @notice mint function for biggest discount
    /// @dev mint function interacts with with staking contract multiple times
    // Functions are seperated to make them lighter. 
    function mintFor50(address _to) public payable notPaused {
        require(viewMyTokens(_to) >= tokensFor50);
        require(msg.value >= costfor50, "Mint50%OFF: Not enough ether");
        Interface(parentContract).subtractTokens(_to, tokensFor50);
        _safeMint(_to, findUnminted());
    }

    /// @notice mint function for second biggest discount
    function mintFor30(address _to) public payable notPaused {
        require(viewMyTokens(_to) >= tokensFor30);
        require(msg.value >= costfor30, "Mint50%OFF: Not enough ether");
        Interface(parentContract).subtractTokens(_to, tokensFor30);
        _safeMint(_to, findUnminted());
    }

    /// @notice mint function for smallest discount
    function mintFor10(address _to) public payable notPaused {
        require(viewMyTokens(_to) >= tokensFor10);
        require(msg.value >= costfor10, "Mint50%OFF: Not enough ether");
        Interface(parentContract).subtractTokens(_to, tokensFor10);
        _safeMint(_to, findUnminted());
    }

    /// @notice checks for tokens earned by staking in other contract
    /// @dev calling single function that makes all the calculations inside other contract just returned active tokens.
    // So I made 3 view functions and made the calculation inside this function.
    function viewMyTokens(address _address) public view returns(uint) {
        uint _active = Interface(parentContract).viewActiveTokens(_address);
        uint _allocated = Interface(parentContract).viewAllocatedTokens(_address);
        uint _subtracted = Interface(parentContract).viewsubtractedTokens(_address);
        return (_active + _allocated - _subtracted);
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

    /// @notice only owner withdraw
    function withdraw() public onlyOwner {
        (bool oc, ) = payable(owner()).call {
            value: address(this).balance
        }("");
        require(oc);
    }
}
