// SPDX-License-Identifier: GPL-3.0
pragma solidity ^ 0.8 .4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

/// @notice creates an interface for SafeTransfer function used to transfer NFTs.
interface Interface {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}


contract Staker is IERC721Receiver, KeeperCompatibleInterface {


    address public parentNFT;
    address public owner;

    uint public immutable interval;
    uint public lastTimeStamp;

    uint[] public stakedNFTs;

    mapping(uint => bool) public isStaked;
    mapping(uint => uint) public lastSnap;
    mapping(uint => uint) public arrayPosition;
    mapping(uint => uint) public stakedPosition;
    mapping(uint => address) public ownerOf;
    mapping(address => uint) public tokensCollected;
    mapping(address => uint[]) public tokensOwned;
    mapping(address => bool) public whitelisted;


    mapping(uint => uint) public test;

    constructor(address _parentNFTAddress, uint updateInterval) {
        parentNFT = _parentNFTAddress;
        owner = msg.sender;
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
    }

    function checkUpkeep(bytes calldata /* checkData */ ) external view override returns(bool upkeepNeeded, bytes memory /* performData */ ) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */ ) external override {
        updateAll();
    }

    function stake(uint[] memory _IDs) public {
        for (uint i; i < _IDs.length; i++) {
            require(!isStaked[_IDs[i]]);
            Interface(parentNFT).safeTransferFrom(msg.sender, address(this), _IDs[i]);
            uint _tempID = _IDs[i];
            isStaked[_tempID] = true;
            lastSnap[_tempID] = block.timestamp;
            ownerOf[_tempID] = msg.sender;
            arrayPosition[_tempID] = tokensOwned[msg.sender].length;
            stakedPosition[_tempID] = stakedNFTs.length;
            tokensOwned[msg.sender].push(_tempID);
            stakedNFTs.push(_tempID);
        }
    }

    function unstake(uint[] memory _IDs) public {
        for (uint i; i < _IDs.length; i++) {
            require(isStaked[_IDs[i]]);
            uint _tempID = _IDs[i];
            uint tempPosition = stakedPosition[_tempID];
            uint tempLastPosition = stakedNFTs.length - 1;
            isStaked[_tempID] = false;
            delete tokensOwned[msg.sender][arrayPosition[_tempID]];
            stakedPosition[tempLastPosition] = stakedNFTs[tempPosition];
            stakedNFTs[tempPosition] = stakedNFTs[tempLastPosition];
            delete stakedNFTs[tempLastPosition];
            Interface(parentNFT).safeTransferFrom(address(this), msg.sender, _IDs[i]);
        }
    }

    function updateAll() public {
        for (uint i; i < stakedNFTs.length; i++) {
            tokensCollected[ownerOf[stakedNFTs[i]]]++;
        }
    }

    function ownerOfToknes(address _address) public view returns(uint[] memory) {
        uint[] memory _tokens;
        for (uint i; i < tokensOwned[_address].length; i++) {
            _tokens[i] = tokensOwned[_address][i];
        }
        return (_tokens);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public override returns(bytes4) {
        return this.onERC721Received.selector;
    }

    function whitelistContract(address _address, bool _bool) public {
        whitelisted[_address] = _bool;
    }

    function subtractTokens(address _address, uint _tokens) public {
        require(msg.sender == owner || whitelisted[msg.sender]);
        require(_tokens <= tokensCollected[_address]);
        tokensCollected[_address] = tokensCollected[_address] - _tokens;
    }
}