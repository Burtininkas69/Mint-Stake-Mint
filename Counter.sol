// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7 .0 < 0.9 .0;

contract Counter {

    mapping(address => uint) public StakeTimerStart;
    mapping(address => uint) public NFTsMinted;
    mapping(address => uint) public AlocatedTokens;

    function stake() public {
        if (StakeTimerStart[msg.sender] == 0) {
            StakeTimerStart[msg.sender] = block.timestamp;
            NFTsMinted[msg.sender]++;
        } else {
            uint _tempNumber = StakeTimerStart[msg.sender];
            StakeTimerStart[msg.sender] = block.timestamp;
            AlocatedTokens[msg.sender] = AlocatedTokens[msg.sender] + ((block.timestamp - _tempNumber) / 60 * NFTsMinted[msg.sender]);
            NFTsMinted[msg.sender]++;
        }
    }

}