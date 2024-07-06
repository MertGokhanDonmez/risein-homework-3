// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
// Imports
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PayPool is ReentrancyGuard {
    // Data
    uint256 public totalBalance;
    address public owner;
    address[] public depositAddresses;
    mapping(address => uint256) public allowances;
    // Enums
    enum DepositStatus {
        Pending,
        Approved,
        Rejected
    }

    // Structs
    struct DepositRecord {
        address depositor;
        uint256 amount;
        uint256 timestamp;
        DepositStatus status;
    }

    // Array to store deposit records
    DepositRecord[] public depositHistory;

    // Events
    event Deposit(address indexed depositer, uint256 amount);
    event AddressAdded(address indexed depositer);
    event AddressRemoved(address indexed depositer);
    event AllowanceGranted(address indexed user, uint256 amount);
    event AllowanceRemoved(address indexed user);
    event FundsRetrieved(address indexed recepient, uint256 amount);
    event DepositApproved(uint256 index);
    event DepositRejected(uint256 index);

    // Modifiers
    modifier isOwner() {
        require(msg.sender == owner, "Not owner!");
        _;
    }

    modifier gotAllowance(address user) {
        require(hasAllowance(user), "This address has no allowance");
        _;
    }

    modifier canDepositTokens(address depositer) {
        require(
            canDeposit(depositer),
            "This address is not allowed to deposit tokens"
        );
        _;
    }

    constructor() payable {
        totalBalance = msg.value;
        owner = msg.sender;
    }

    // Internal functions
    function hasAllowance(address user) internal view returns (bool) {
        return allowances[user] > 0;
    }

    function canDeposit(address depositer) internal view returns (bool) {
        for (uint256 i = 0; i < depositAddresses.length; i++) {
            if (depositAddresses[i] == depositer) {
                return true;
            }
        }
        return false;
    }

    // Execute Functions
    function addDepositAddress(address depositer) external isOwner {
        depositAddresses.push(depositer);
        emit AddressAdded(depositer);
    }

    function removeDepositAddress(uint256 index)
        external
        isOwner
        canDepositTokens(depositAddresses[index])
    {
        depositAddresses[index] = address(0);
        emit AddressRemoved(depositAddresses[index]);
    }

    // Modified deposit function to add deposit records
    function deposit() external payable canDepositTokens(msg.sender) {
        totalBalance += msg.value;

        // Create a deposit record with Pending status
        depositHistory.push(
            DepositRecord({
                depositor: msg.sender,
                amount: msg.value,
                timestamp: block.timestamp,
                status: DepositStatus.Pending
            })
        );

        emit Deposit(msg.sender, msg.value);
    }

    function retrieveBalance() external isOwner nonReentrant {
        uint256 balance = totalBalance;
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer failed");
        totalBalance = 0;
        emit FundsRetrieved(owner, balance);
    }

    function giveAllowance(uint256 amount, address user) external isOwner {
        require(
            totalBalance >= amount,
            "There are no enough tokens inside the pool to give allowance"
        );
        allowances[user] = amount;
        unchecked {
            totalBalance -= amount;
        }
        emit AllowanceGranted(user, amount);
    }

    function removeAllowance(address user) external isOwner gotAllowance(user) {
        allowances[user] = 0;
        emit AllowanceRemoved(user);
    }

    function allowRetrieval() external gotAllowance(msg.sender) nonReentrant {
        uint256 amount = allowances[msg.sender];
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Retrieval failed");
        allowances[msg.sender] = 0;
        emit FundsRetrieved(msg.sender, amount);
    }

    // Owner functions to approve/reject deposits
    function approveDeposit(uint256 index) external isOwner {
        require(index < depositHistory.length, "Invalid deposit index");
        depositHistory[index].status = DepositStatus.Approved;
        emit DepositApproved(index);
    }

    function rejectDeposit(uint256 index) external isOwner {
        require(index < depositHistory.length, "Invalid deposit index");
        depositHistory[index].status = DepositStatus.Rejected;
        emit DepositRejected(index);
    }

    // Function to retrieve deposit history
    function getDepositHistory() public view returns (DepositRecord[] memory) {
        return depositHistory;
    }
}
