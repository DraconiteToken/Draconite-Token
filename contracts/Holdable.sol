//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "SafeMath.sol";

contract Holdable {
    using SafeMath for uint256;
    
    constructor() {
        holdholders.push();
    }
    
    struct Hold{
        address user;
        uint256 amount;
        uint256 startDate;
        uint256 endDate;
    }
    struct Holdholder{
        address user;
        Hold[] holds;
    }
    struct HoldSummary{
        uint256 totalRewardAmount;
        Hold[] holds;
    }

    Holdholder[] internal holdholders;
    mapping(address => uint256) internal holdsIndex;
    
    event Holded(address indexed user, uint256 amount, uint256 startDate, uint256 endDate, uint256 index);

    function addHoldholder(address account) internal returns (uint256){
        holdholders.push();
        uint256 userIndex = holdholders.length - 1;
        
        holdholders[userIndex].user = account;
        holdsIndex[account] = userIndex;
        
        return userIndex;
    }

    function hold(address account, uint256 amount) internal{
        require(amount > 0, "Cannot stake nothing");
        
        uint256 index = holdsIndex[account];
        uint256 timestamp = block.timestamp;
        
        if(index == 0){
            index = addHoldholder(account);
        }

        holdholders[index].holds.push(Hold(account, amount, timestamp,  0));

        emit Holded(account, amount, timestamp, 0, index);
    }

    function withdrawHold(address account, uint256 amount) internal{
        uint256 txAmount = amount;
        Hold[] memory accountHolds = holdholders[holdsIndex[account]].holds;

        for (uint256 s = accountHolds.length; s > 0; s--){
            if (accountHolds[s - 1].endDate == 0 && txAmount > 0){
                if (accountHolds[s - 1].amount > txAmount){
                    //Add new hold
                    holdholders[holdsIndex[account]].holds.push(Hold(account, txAmount, 
                        accountHolds[s - 1].startDate, block.timestamp));
                        
                    emit Holded(account, txAmount, accountHolds[s - 1].startDate, 
                        block.timestamp, holdsIndex[account]);
                    
                    holdholders[holdsIndex[account]].holds[s - 1].amount = holdholders[holdsIndex[account]].holds[s - 1].amount - txAmount;

                    txAmount = 0;
                    break;
                } else {
                    holdholders[holdsIndex[account]].holds[s - 1].endDate = block.timestamp;
                    
                    txAmount = txAmount - holdholders[holdsIndex[account]].holds[s - 1].amount;
                }
            } else {
                break;
            }
        }
    }
    
    function calculateReward(address account, uint256 totalSupply, uint256 bnbPool, uint256 rewardCycleBlock) internal view returns(uint256){
        HoldSummary memory holdSummary = HoldSummary(0, getHoldsForAddress(account));
        
        for(uint256 s = 0; s < holdSummary.holds.length; s++){
            uint256 multiplier = 100;
            uint256 date = 0;
            uint256 rewardPerCycle = bnbPool.mul(multiplier).mul(holdSummary.holds[s].amount).div(100).div(totalSupply);

            if (holdSummary.holds[s].endDate == 0){
                date = block.timestamp.sub(holdSummary.holds[s].startDate);
            } else {
                date = holdSummary.holds[s].endDate.sub(holdSummary.holds[s].startDate);
            }

            uint256 rewardForAllCycles = rewardPerCycle.mul(multiplier).mul(date).div(100).div(rewardCycleBlock);
            
            holdSummary.totalRewardAmount = holdSummary.totalRewardAmount + rewardForAllCycles;
        }
        
        return holdSummary.totalRewardAmount;
    }
    
    function getHoldsForAddress(address account) internal view returns(Hold[] memory){
        return holdholders[holdsIndex[account]].holds;
    }
    
    function deleteHoldsForAddress(address account) internal{
        delete holdholders[holdsIndex[account]].holds;
        
    }
}