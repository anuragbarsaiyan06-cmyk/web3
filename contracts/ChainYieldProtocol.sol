// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ChainYield Protocol
 * @dev A decentralized yield optimization protocol that maximizes returns on deposited assets
 * @notice This contract allows users to deposit tokens and earn optimized yields through automated strategies
 */
contract Project {
    
    // State Variables
    address public owner;
    uint256 public totalDeposits;
    uint256 public totalYieldGenerated;
    uint256 public constant MINIMUM_DEPOSIT = 0.01 ether;
    uint256 public constant PERFORMANCE_FEE = 100; // 1% in basis points (100/10000)
    uint256 public constant BASIS_POINTS = 10000;
    
    // Structs
    struct Deposit {
        uint256 amount;
        uint256 depositTime;
        uint256 lastClaimTime;
        uint256 accumulatedYield;
        bool isActive;
    }
    
    struct YieldStrategy {
        string name;
        uint256 apy; // Annual Percentage Yield in basis points
        bool isActive;
        uint256 totalAllocated;
    }
    
    // Mappings
    mapping(address => Deposit) public userDeposits;
    mapping(uint256 => YieldStrategy) public yieldStrategies;
    mapping(address => bool) public whitelistedStrategies;
    
    uint256 public strategyCount;
    address[] public depositors;
    
    // Events
    event DepositMade(address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawalMade(address indexed user, uint256 amount, uint256 yield);
    event YieldClaimed(address indexed user, uint256 yieldAmount);
    event StrategyAdded(uint256 indexed strategyId, string name, uint256 apy);
    event StrategyUpdated(uint256 indexed strategyId, uint256 newApy);
    event FeesCollected(address indexed owner, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier hasDeposit() {
        require(userDeposits[msg.sender].isActive, "No active deposit found");
        _;
    }
    
    modifier validAmount(uint256 _amount) {
        require(_amount >= MINIMUM_DEPOSIT, "Amount below minimum deposit");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        
        // Initialize default strategies
        _addStrategy("Conservative Pool", 500); // 5% APY
        _addStrategy("Balanced Pool", 1200); // 12% APY
        _addStrategy("Aggressive Pool", 2500); // 25% APY
    }
    
    /**
     * @dev Allows users to deposit ETH into the protocol
     */
    function deposit() external payable validAmount(msg.value) {
        require(!userDeposits[msg.sender].isActive, "Already has active deposit");
        
        userDeposits[msg.sender] = Deposit({
            amount: msg.value,
            depositTime: block.timestamp,
            lastClaimTime: block.timestamp,
            accumulatedYield: 0,
            isActive: true
        });
        
        depositors.push(msg.sender);
        totalDeposits += msg.value;
        
        emit DepositMade(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Calculate pending yield for a user based on time elapsed
     */
    function calculateYield(address _user) public view returns (uint256) {
        Deposit memory userDeposit = userDeposits[_user];
        
        if (!userDeposit.isActive) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - userDeposit.lastClaimTime;
        uint256 annualYield = (userDeposit.amount * 1200) / BASIS_POINTS; // Using 12% default APY
        uint256 yieldAmount = (annualYield * timeElapsed) / 365 days;
        
        return yieldAmount + userDeposit.accumulatedYield;
    }
    
    /**
     * @dev Allows users to claim their accumulated yield
     */
    function claimYield() external hasDeposit {
        uint256 yieldAmount = calculateYield(msg.sender);
        require(yieldAmount > 0, "No yield to claim");
        
        // Calculate performance fee
        uint256 fee = (yieldAmount * PERFORMANCE_FEE) / BASIS_POINTS;
        uint256 netYield = yieldAmount - fee;
        
        userDeposits[msg.sender].lastClaimTime = block.timestamp;
        userDeposits[msg.sender].accumulatedYield = 0;
        totalYieldGenerated += yieldAmount;
        
        // Transfer yield to user
        payable(msg.sender).transfer(netYield);
        
        // Transfer fee to owner
        payable(owner).transfer(fee);
        
        emit YieldClaimed(msg.sender, netYield);
        emit FeesCollected(owner, fee);
    }
    
    /**
     * @dev Allows users to withdraw their principal and accumulated yield
     */
    function withdraw() external hasDeposit {
        Deposit memory userDeposit = userDeposits[msg.sender];
        uint256 yieldAmount = calculateYield(msg.sender);
        
        // Calculate performance fee on yield
        uint256 fee = (yieldAmount * PERFORMANCE_FEE) / BASIS_POINTS;
        uint256 netYield = yieldAmount - fee;
        uint256 totalAmount = userDeposit.amount + netYield;
        
        // Update state
        totalDeposits -= userDeposit.amount;
        totalYieldGenerated += yieldAmount;
        delete userDeposits[msg.sender];
        
        // Transfer funds
        payable(msg.sender).transfer(totalAmount);
        payable(owner).transfer(fee);
        
        emit WithdrawalMade(msg.sender, userDeposit.amount, netYield);
        emit FeesCollected(owner, fee);
    }
    
    /**
     * @dev Internal function to add a new yield strategy
     */
    function _addStrategy(string memory _name, uint256 _apy) internal {
        yieldStrategies[strategyCount] = YieldStrategy({
            name: _name,
            apy: _apy,
            isActive: true,
            totalAllocated: 0
        });
        
        emit StrategyAdded(strategyCount, _name, _apy);
        strategyCount++;
    }
    
    /**
     * @dev Allows owner to add new yield strategies
     */
    function addStrategy(string memory _name, uint256 _apy) external onlyOwner {
        require(_apy > 0 && _apy <= 10000, "Invalid APY"); // Max 100% APY
        _addStrategy(_name, _apy);
    }
    
    /**
     * @dev Allows owner to update strategy APY
     */
    function updateStrategyAPY(uint256 _strategyId, uint256 _newApy) external onlyOwner {
        require(_strategyId < strategyCount, "Invalid strategy ID");
        require(_newApy > 0 && _newApy <= 10000, "Invalid APY");
        
        yieldStrategies[_strategyId].apy = _newApy;
        
        emit StrategyUpdated(_strategyId, _newApy);
    }
    
    /**
     * @dev Toggle strategy active status
     */
    function toggleStrategy(uint256 _strategyId) external onlyOwner {
        require(_strategyId < strategyCount, "Invalid strategy ID");
        yieldStrategies[_strategyId].isActive = !yieldStrategies[_strategyId].isActive;
    }
    
    /**
     * @dev Get user deposit details
     */
    function getUserDeposit(address _user) external view returns (
        uint256 amount,
        uint256 depositTime,
        uint256 lastClaimTime,
        uint256 accumulatedYield,
        uint256 pendingYield,
        bool isActive
    ) {
        Deposit memory userDeposit = userDeposits[_user];
        return (
            userDeposit.amount,
            userDeposit.depositTime,
            userDeposit.lastClaimTime,
            userDeposit.accumulatedYield,
            calculateYield(_user),
            userDeposit.isActive
        );
    }
    
    /**
     * @dev Get strategy details
     */
    function getStrategy(uint256 _strategyId) external view returns (
        string memory name,
        uint256 apy,
        bool isActive,
        uint256 totalAllocated
    ) {
        require(_strategyId < strategyCount, "Invalid strategy ID");
        YieldStrategy memory strategy = yieldStrategies[_strategyId];
        return (strategy.name, strategy.apy, strategy.isActive, strategy.totalAllocated);
    }
    
    /**
     * @dev Get total number of depositors
     */
    function getTotalDepositors() external view returns (uint256) {
        return depositors.length;
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Emergency withdraw function for users in case of issues
     */
    function emergencyWithdraw() external hasDeposit {
        uint256 amount = userDeposits[msg.sender].amount;
        totalDeposits -= amount;
        delete userDeposits[msg.sender];
        
        payable(msg.sender).transfer(amount);
        
        emit EmergencyWithdraw(msg.sender, amount);
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
    
    /**
     * @dev Fallback function to accept ETH
     */
    receive() external payable {
        totalDeposits += msg.value;
    }
}
