// SPDX-License-Identifier: GPL-3.0
pragma solidity ^ 0.8 .4;

contract Coin {

    struct NFTInfo {
        uint ID;
        uint timer;
        address owner;
        bool staked;
    }

    NFTInfo[] public NFTInformation;

    mapping(address => uint) public tokensOwned;
    mapping(address => uint[]) public ownerOfPositions;
    mapping(uint => uint) public NFTsPosition;
    mapping(uint => bool) public NFTStaked;

    function updateInformation() public {
        for (uint i; i < NFTInformation.length; i++) {
            if ((block.timestamp - NFTInformation[i].timer) >= 30) {
                NFTInformation[i].timer = NFTInformation[i].timer + 10;
                tokensOwned[NFTInformation[i].owner] = tokensOwned[NFTInformation[i].owner] + ((block.timestamp - NFTInformation[i].timer) / 604800 * 25);
            }
        }
    }

    function stake(uint[] memory _id) public {
        for(uint i; i < _id.length; i++) {
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

    function unstake(uint _id) public {
        NFTInformation[NFTsPosition[_id]].staked = false;
        delete ownerOfPositions[msg.sender][NFTsPosition[_id]];
        NFTStaked[_id] = false;
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

    function takeArray(uint[] memory _address) public {

    }
}