//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./MelonX_Campaign.sol";

interface IDonationCampaing {
    function withdrawAnyErc20(address token, address receiver) external;
    function withdrawEthByFactory(address receiver) external;
    function switchPause() external;
}

/**
 * @title MelonX Donation Campaign Factory
 * @notice Create Donation Campaigns
 * @author Socarde Paul-Constantin, DRIVENlabs Inc.
 */

contract DonationCampaing_Factory {

    /// @dev Variables for analytics
    uint256 public totalCampaigns;

    /// @dev Addresses with control power
    address public owner;

    /// @dev Array of approved tokens
    address[] public approvedTokens;

    /// @dev Array of campaigns (addresses)
    address[] public contracts;

    /// @dev Constructor
    constructor() {
        approvedTokens[0] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
        approvedTokens[1] = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD
        approvedTokens[2] = 0x55d398326f99059fF775485246999027B3197955; // USDT
    }

    /// @dev Event emitted when a new campaign is created
    event NewCampaign(address campaignAddress, address owner, uint256 goal);

    /// @dev Require - msg.sender should be owner
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    /// @dev [Only Owner 1] function to create a campaign
    /// @dev In this version of the smart contract, a campaign can be created only manually by the owner
    ///      in order to prevent fraudulent campaigns
    function createCampaign(address beneficiary, uint256 goal) external onlyOwner {
        DonationCampain campaign = new DonationCampain(address(this), beneficiary, approvedTokens, goal);

        contracts.push(address(campaign));

        ++totalCampaigns;

        emit NewCampaign(address(campaign), beneficiary, goal);
    }

    /// @dev [Only Owner 2] function to pause a campaign
    function pauseCampaign(uint256 index) external onlyOwner {
        IDonationCampaing(contracts[index]).switchPause();
    }

    /// @dev [Only Owner 3] withdraw Eth from fraudulent campaign
    function withdrawEth(uint256 index) external onlyOwner {
        IDonationCampaing(contracts[index]).withdrawEthByFactory(owner);
    }

    /// @dev [Only Owner 3] withdraw Erc20 from fraudulent campaign
    function withdrawErc20(uint256 index, address token) external onlyOwner {
        IDonationCampaing(contracts[index]).withdrawAnyErc20(token, owner);
    }

    /// @return totalCampaigns The total number of created campaigns
    function getTotalCampaign() external view returns(uint256) {
        return totalCampaigns;
    }

    /// @return contracts The array with created contract addresses
    function getAddresseseOfCampaigns() external view returns(address[] memory) {
        return contracts;
    }

}
