// SPDX-License-Identifier: GPL-3.0
pragma solidity ^ 0.8 .4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @notice creates an interface for SafeTransfer function used to transfer NFTs.
interface Interface {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract Coin is IERC721Receiver {

    address public parentNFT;
    address public owner;

    struct NFTInfo {
        uint ID;
        uint timer;
        address owner;
        bool staked;
    }

    NFTInfo[] public NFTInformation;

    mapping(address => uint) public tokensOwned;
    mapping(address => uint[]) public ownerOfPositions;
    mapping(address => bool) public whitelisted;
    mapping(uint => uint) public NFTsPosition;
    mapping(uint => bool) public NFTStaked;

    constructor(address _parentNFTAddress) {
        parentNFT = _parentNFTAddress;
        owner = msg.sender;
    }

    function updateInformation() public {
        for (uint i; i < NFTInformation.length; i++) {
            if ((block.timestamp - NFTInformation[i].timer ) >= 30 && NFTInformation[i].staked) {
                tokensOwned[NFTInformation[i].owner] = tokensOwned[NFTInformation[i].owner] + ((block.timestamp - NFTInformation[i].timer) / 30 * 25);
                NFTInformation[i].timer = NFTInformation[i].timer + (block.timestamp - NFTInformation[i].timer);
            }
        }
    }

    function stake(uint[] memory _id) public {
        for (uint i; i < _id.length; i++) {

            Interface(parentNFT).safeTransferFrom(msg.sender, address(this), _id[i]);

            if (!NFTStaked[_id[i]]) {
                NFTInfo memory newNFT = NFTInfo(_id[i], block.timestamp, msg.sender, true);
                NFTInformation.push(newNFT);
                NFTsPosition[_id[i]] = NFTInformation.length - 1;
            } else {
                NFTInformation[NFTsPosition[_id[i]]].timer = block.timestamp;
                NFTInformation[NFTsPosition[_id[i]]].owner = msg.sender;
                NFTInformation[NFTsPosition[_id[i]]].staked = true;
            }
            ownerOfPositions[msg.sender].push(NFTsPosition[_id[i]]);
            NFTStaked[_id[i]] = true;
        }
    }

    function unstake(uint[] memory _id) public {
        for (uint i; i < _id.length; i++) {
            require(NFTStaked[_id[i]], "NFT is not in the contract");
            require(NFTInformation[NFTsPosition[_id[i]]].owner == msg.sender, "You are not the owner of this NFT");
            Interface(parentNFT).safeTransferFrom(address(this), msg.sender, _id[i]);

            NFTInformation[NFTsPosition[_id[i]]].staked = false;
            delete ownerOfPositions[msg.sender][NFTsPosition[_id[i]]];Q
            NFTStaked[_id[i]] = false;
        }
    }

    function timeNow() public view returns(uint) {
        return (block.timestamp);
    }

    function timeDivision() public view returns(uint) {
        uint temp;
        for (uint i; i < ownerOfPositions[msg.sender].length; i++) {
            temp = temp + NFTInformation[ownerOfPositions[msg.sender][i]].timer;
        }
        return (temp);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public override returns(bytes4) {
        return this.onERC721Received.selector;
    }

    function whitelistContract(address _address, bool _bool) public {
        whitelisted[_address] = _bool;
    }

    function subtractTokens(address _address, uint _tokens) public {
        require(msg.sender == owner || whitelisted[msg.sender]);
        require(_tokens <= tokensOwned[_address]);
        tokensOwned[_address] = tokensOwned[_address] - _tokens;
    }
}