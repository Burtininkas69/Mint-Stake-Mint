// SPDX-License-Identifier: GPL-3.0
pragma solidity ^ 0.8 .4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

/// @notice creates an interface for SafeTransfer function used to transfer NFTs.
interface Interface {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract Staker is IERC721Receiver {

    address public parentNFT;
    address public owner;
    uint LastStruct;
    uint public StakingTime;
    uint public Multiplyer;

    struct Stake {
        uint ID;
        uint stakingStart;
        uint stakingEnding;
        address owner;
        bool staked;
    }

    Stake[] public StakedStruct;

    mapping(uint => uint) public stakedRoom;
    mapping(address => uint) public subtractedTokens;
    mapping(address => uint[]) public ownerOfTokens;
    mapping(address => uint) public unstakedTokenEarnings;
    mapping(address => bool) public whitelisted;

    constructor(address _parentAddress, uint _stakingTime, uint _multiplyer) {
        parentNFT = _parentAddress;
        StakingTime = _stakingTime;
        owner = msg.sender;
        Multiplyer = _multiplyer;
    }

    modifier isOwner() {
        require(msg.sender == owner || whitelisted[msg.sender]);
        _;
    }

    function stake(uint[] memory _id) public {
        for (uint i; i < _id.length; i++) {
            uint _tempID = _id[i];
            Interface(parentNFT).safeTransferFrom(msg.sender, address(this), _tempID);
            Stake memory newStake = Stake(_tempID, block.timestamp, 0, msg.sender, true);
            StakedStruct.push(newStake);
            stakedRoom[_tempID] = LastStruct;
            ownerOfTokens[msg.sender].push(_tempID);
            LastStruct++;
        }
    }

    function unstake(uint[] memory _id) public {
        for (uint i; i < _id.length; i++) {
            uint _tempID = _id[i];
            uint _tempRoom = stakedRoom[_tempID];
            uint _timeDifference = block.timestamp - StakedStruct[_tempRoom].stakingStart;
            StakedStruct[_tempRoom].stakingEnding = block.timestamp;
            StakedStruct[_tempRoom].staked = false;

            if (_timeDifference > StakingTime) {
                unstakedTokenEarnings[msg.sender] = unstakedTokenEarnings[msg.sender] + (_timeDifference / StakingTime * Multiplyer);
            }

            Interface(parentNFT).safeTransferFrom(address(this), msg.sender, _tempID);
        }
    }


    function viewTokens(address _address) public view returns(uint) {
        uint _tempTokens;

        for (uint i; i < ownerOfTokens[_address].length; i++) {
            uint _tempRoom = stakedRoom[ownerOfTokens[_address][i]];

            if (block.timestamp - StakedStruct[_tempRoom].stakingStart > StakingTime && StakedStruct[_tempRoom].staked) {
                _tempTokens = _tempTokens + (((block.timestamp - StakedStruct[_tempRoom].stakingStart) / StakingTime) * Multiplyer);
            }
        }

        return (unstakedTokenEarnings[msg.sender] + _tempTokens - subtractedTokens[_address]);
    }

    function viewAllocatedTokens(address _address) public view returns(uint) {
        return unstakedTokenEarnings[_address];
    }

    function viewsubtractedTokens(address _address) public view returns(uint) {
        return subtractedTokens[_address];
    }

    function viewActiveTokens(address _address) public view returns(uint) {
        uint _tempTokens;

        for (uint i; i < ownerOfTokens[_address].length; i++) {
            uint _tempRoom = stakedRoom[ownerOfTokens[_address][i]];

            if (block.timestamp - StakedStruct[_tempRoom].stakingStart > StakingTime && StakedStruct[_tempRoom].staked) {
                _tempTokens = _tempTokens + (((block.timestamp - StakedStruct[_tempRoom].stakingStart) / StakingTime) * Multiplyer);
            }
        }
        return _tempTokens;
    }

    function editStakingTime(uint _timeInSeconds) public isOwner {
        StakingTime = _timeInSeconds;
    }

    function subtractTokens(address _address, uint _tokens) public isOwner {
        subtractedTokens[_address] = subtractedTokens[_address] + _tokens;
    }

    function transferOwnership(address _address) public isOwner {
        owner = _address;
    }

    function whitelist(address _address, bool _bool) public isOwner {
        whitelisted[_address] = _bool;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public override returns(bytes4) {
        return this.onERC721Received.selector;
    }


}