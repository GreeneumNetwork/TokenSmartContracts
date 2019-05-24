 pragma solidity ^0.4.16;

import "./Destructible.sol";
import "./GreenToken.sol";

contract GreenCrowdsale is Destructible {
    GreenToken public tokenReward;
    mapping(address => uint256) public balanceOf;
    
    uint256 public salePeriod = 14 days;
    
    uint256 public totalAmountRaised = 0;
    uint256 public fundingGoal = 58490.75 * 1 ether;

    event FundTransfer (address _backer, uint256 _amount, bool _isContribution);

// StateMachine <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    enum Stages {
        NotStarted,
        InProgress,
        Finished
    }

    uint256 startTime = 0;                   // public for dev
    Stages stage = Stages.NotStarted;     // public for dev

    modifier atStage (Stages _stage) {
        require(stage == _stage);
        _;
    }
    
    modifier transitionNext () {
        _;
        stage = Stages(uint256(stage) + 1);
    }
    
    modifier timedTransitions () {
        require(stage > Stages.NotStarted);
        uint256 diff = now - startTime;
        if (diff >= salePeriod && stage != Stages.Finished) {
            stage = Stages.Finished;
        }
        _;
    }
// StateMachine >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 

    function GreenCrowdsale (address _addressOfTokenUsedAsReward) public
    {
        require(_addressOfTokenUsedAsReward != address(0));
        tokenReward = GreenToken(_addressOfTokenUsedAsReward);
    }

    function () public payable 
    timedTransitions 
    atStage(Stages.InProgress) 
    {
        uint256 amount = msg.value;
        
        require(amount >= 0.1 ether);

        totalAmountRaised += amount;
        balanceOf[msg.sender] += amount;
        tokenReward.transfer(msg.sender, amount / calculatePrice());
        
        FundTransfer(msg.sender, amount, true);
    }
    
    function calculatePrice () internal constant returns (uint256 price) 
    {
        if (totalAmountRaised <= 26400.00) {
            return 0.002933333333 * 1 ether;
        } else if (totalAmountRaised > 26400.00 * 1 ether && totalAmountRaised <= 41066.67 * 1 ether) {
            return 0.003666666667 * 1 ether;
        } else if (totalAmountRaised > 41066.67 * 1 ether && totalAmountRaised <= 48400.00 * 1 ether) {
            return 0.004888888889 * 1 ether;
        } else if (totalAmountRaised > 48400.00 * 1 ether && totalAmountRaised <= 58490.75 * 1 ether) {
            return 0.007333333333 * 1 ether;
        } else {
            return 0.008 * 1 ether; // ?????????????
        }
    }
    
    function startPresale () public
    onlyOwner
    atStage(Stages.NotStarted)
    transitionNext 
    {
        startTime = now;
    }
    
    function minutesToEnd () view public returns (uint256 _time) {
        require(stage > Stages.NotStarted && stage < Stages.Finished);
        uint256 endTime = startTime + salePeriod;
        uint256 toEndTime = endTime - now;
        return toEndTime <= salePeriod ? toEndTime / 1 minutes : 0;
    }
    
    function currentBalance () view public returns (uint256 _balance) {
        return this.balance;
    }
    
    function isGoalReached() view public returns (bool _isReached) {
        return totalAmountRaised >= fundingGoal;
    }
    
    function safeWithdrawal () public
    timedTransitions
    atStage(Stages.Finished)
    {
        if (isGoalReached() && owner == msg.sender) {
            uint256 amountRaised = this.balance;
            owner.transfer(amountRaised);
            tokenReward.transfer(owner, tokenReward.balanceOf(this));
            
            FundTransfer(owner, amountRaised, false);
        }
        
        if( ! isGoalReached()) {
            uint256 amount = balanceOf[msg.sender];
            require(amount > 0);
            msg.sender.transfer(amount);
            balanceOf[msg.sender] = 0;
            
            FundTransfer(msg.sender, amount, false);
        }
    }
}
