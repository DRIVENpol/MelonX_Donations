//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title MelonX Donation Campaign
 * @notice Donate ETH or ERC20 tokens for this breast cancer campaign
 * @author Socarde Paul-Constantin, DRIVENlabs Inc.
 */

contract DonationCampain {

    /// @dev Variables for analytics
    uint256 public totalERC20Donations;
    uint256 public totalEthDonations;
    uint256 public uniqueDonors;
    uint256 public goalInUsd;

    /// @dev Addresses with control power
    /// @notice The factory address hash the highest rank of power
    address public owner;
    address public factory;

    /// @dev The state of the smart contract
    bool public isPaused;

    /// @dev Mapping to count unique donors
    mapping(address => bool) public uniqueDonor;

    /// @dev Mapping for ERC20 operations
    mapping(address => bool) public tokenIsApproved;

    /// @dev Struct to keep track of each erc20 donation
    struct ERC20Donation {
        uint256 amount;
        address erc20Token;
        address donor;
        string message;
        uint256 time;
    }

    /// @dev Struct to keep track of each eth donation
    struct EthDonation {
        uint256 amount;
        address donor;
        string message;
        uint256 time;
    }

    /// @dev Arrays of erc20 and eth donation
    ERC20Donation[] public erc20donations;
    EthDonation[] public ethDonations;

    /// @dev Events for deposits
    event Erc20Deposit(uint256 amount, address tokenAddress, address donor, string message, uint256 time);
    event EthDeposit(uint256 amount, address donor, string message, uint256 time);

    /// @dev Events for withdraws
    event WithdrawErc20ByOwner(uint256 amount, address token, address receiver, uint256 time);
    event WithdrawEthByOwner(uint256 amount, address receiver, uint256 time);

    /// @dev Event emitted when the switchPause function is called
    event SwitchPause(bool status, uint256 time);

    /// @dev Constructor
    /// @param _factory The factory address
    /// @param _owner The address of the beneficiary
    /// @param _tokensForPayment Array of approved ERC20 tokens hardcoded in the factory smart contract
    /// @param _goalInUsd User's goal for this campaign (will be displayed on the UI)
    constructor(address _factory, address _owner, address[] memory _tokensForPayment, uint256 _goalInUsd) {
        owner = _owner;
        factory = _factory;
        goalInUsd = _goalInUsd;
        _approveTokensForDonations(_tokensForPayment);
    }

    /// @dev Allow the smart contract to receive Ether
    receive() external payable {}

    /// @dev Require - msg.sender should be the beneficiary or the factory
    modifier onlyOwner() {
        require(msg.sender == owner || msg.sender == factory, "You are not the owner!");
        _;
    }

    /// @dev Require - msg.sender should be the beneficiary or the factory
    modifier onlyFactory() {
        require(msg.sender == factory, "You are not the factory!");
        _;
    }

    /// @dev [Internal 1] function to approve what ERC20 tokens can be used for donations
    /// @notice This function is called only once, in the constructor
    function _approveTokensForDonations(address[] memory tokens) internal {
        for(uint256 i = 0; i <= tokens.length; i++) {
            address _token = tokens[i];
            tokenIsApproved[_token] = true;
        }
    }

    /// @dev [Internal 2] function to mark an address as a donor
    /// @notice This action can be performed only once for an address in order to compute the number of the total donors
    function _setUniqueDonor(address _who) internal returns(bool) {
        if(uniqueDonor[_who] == true) {return false;} else {
            uniqueDonor[_who] = true;
            ++uniqueDonors;
            return true;
        }
    }

    /// @dev [External 1] function to create an Eth Donation
    /// @param message is used to send some good words with the attached amount
    function makeEthDonation(uint256 amount, string memory message) external payable {
        require(msg.value == amount, "Invalid amount!");
        require(isPaused == true, "This campaign is not active!");

        EthDonation memory _donation = EthDonation(amount, msg.sender, message, block.timestamp);

        ethDonations.push(_donation);

        _setUniqueDonor(msg.sender);
        ++totalEthDonations;

        emit EthDeposit(amount, msg.sender, message, block.timestamp);
    }

    /// @dev [External 2] function to create an Eth Donation
    /// @param message is used to send some good words with the attached amount
    function makeErc20Donation(uint256 amount, address token, string memory message) external {
        require(isPaused == true, "This campaign is not active!");
        require(tokenIsApproved[token] == true, "Can't make donations using this ERC20 token!");

        IToken _token = IToken(token);
        require(_token.transferFrom(msg.sender, address(this), amount), "ERC20 transfer failed!");

        ERC20Donation memory _donation = ERC20Donation(amount, token, msg.sender, message, block.timestamp);

        erc20donations.push(_donation);
        ++totalERC20Donations;

        emit Erc20Deposit(amount, token, msg.sender, message, block.timestamp);
    }

    /// @dev [Only Owner 1] function to withdraw ether by the beneficiary or by the factory
    /// @notice In case there is reported fraudulent activity, the factory can stop the withdrawals & donations
    function withdrawEther(address receiver) external onlyOwner {
        require(isPaused == true, "This campaign is not active!");
        uint256 _amount = address(this).balance;

        (bool sent, ) = receiver.call{value: _amount}("");
        require(sent, "Transaction failed!");

        emit WithdrawEthByOwner(_amount, receiver, block.timestamp);
    }

    /// @dev [Only Owner 2] function to withdraw erc20 tokens by the beneficiary or by the factory
    /// @notice In case there is reported fraudulent activity, the factory can stop the withdrawals & donations
    /// @param token The address of the ERC20 token used for donation
    function withdrawErc20Tokens(address token, address receiver) external onlyOwner {
        require(isPaused == true, "This campaign is not active!");
        require(tokenIsApproved[token] == true, "Can't withdraw this token!");
        
        IToken _token = IToken(token);

        uint256 _balance = _token.balanceOf(address(this));
        _token.approve(receiver, _balance);

        require(_token.transferFrom(address(this), receiver, _balance), "Invalid ERC20 Transfer!");
        
        emit WithdrawErc20ByOwner(_balance, token, receiver, block.timestamp);
    }

    /// @dev [Only Factory 1] function to withdraw erc20 tokens
    function withdrawAnyErc20(address token, address receiver) external onlyFactory {
        IToken _token = IToken(token);

        uint256 _balance = _token.balanceOf(address(this));
        _token.approve(receiver, _balance);

        require(_token.transferFrom(address(this), receiver, _balance), "Invalid ERC20 Transfer!");
        
        emit WithdrawErc20ByOwner(_balance, token, receiver, block.timestamp);
    }

    /// @dev [Only Factory 2] function to withdraw Eth
    function withdrawEthByFactory(address receiver) external onlyFactory {
        uint256 _amount = address(this).balance;

        (bool sent, ) = receiver.call{value: _amount}("");
        require(sent, "Transaction failed!");

        emit WithdrawEthByOwner(_amount, receiver, block.timestamp);
    }

    /// @dev [Only Factory 3] to pause the withdraws and the donations
    function switchPause() external onlyFactory {
        if(isPaused == true) {
            isPaused = false;
            emit SwitchPause(false, block.timestamp);
        } else {
            isPaused = true;
            emit SwitchPause(true, block.timestamp);
        }
    }

    /// @dev Return the length of each array of donations
    function getLengths() external view returns(uint256 eth, uint256 erc20) {
        eth = ethDonations.length;
        erc20 = erc20donations.length;

        return (eth, erc20);
    }

    /// @dev Return the details of eth donation at index
    function getEthDonationInfo(uint256 index) external view returns(
        uint256 amount,
        address donor,
        string memory message,
        uint256 time) {

        EthDonation memory _donation = ethDonations[index];

        amount = _donation.amount;
        donor = _donation.donor;
        message = _donation.message;
        time = _donation.time;

        return(amount, donor, message, time);
    }

    /// @dev Return the details of erc20 donation at index
    function getErc20DonationInfo(uint256 index) external view returns(
        uint256 amount,
        address token,
        address donor,
        string memory message,
        uint256 time) {

        ERC20Donation memory _donation = erc20donations[index];

        amount = _donation.amount;
        token = _donation.erc20Token;
        donor = _donation.donor;
        message = _donation.message;
        time = _donation.time;

        return(amount, token, donor, message, time);
    }

}
