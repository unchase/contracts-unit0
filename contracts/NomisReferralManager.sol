// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

///////////////////////////////////////////////////////////////
//  ___   __    ______   ___ __ __    ________  ______       //
// /__/\ /__/\ /_____/\ /__//_//_/\  /_______/\/_____/\      //
// \::\_\\  \ \\:::_ \ \\::\| \| \ \ \__.::._\/\::::_\/_     //
//  \:. `-\  \ \\:\ \ \ \\:.      \ \   \::\ \  \:\/___/\    //
//   \:. _    \ \\:\ \ \ \\:.\-/\  \ \  _\::\ \__\_::._\:\   //
//    \. \`-\  \ \\:\_\ \ \\. \  \  \ \/__\::\__/\ /____\:\  //
//     \__\/ \__\/ \_____\/ \__\/ \__\/\________\/ \_____\/  //
//                                                           //
///////////////////////////////////////////////////////////////

/**
 * @title NomisReferralManager
 * @dev The NomisReferralManager contract.
 * @custom:security-contact info@nomis.cc
 */
contract NomisReferralManager is 
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721URIStorageUpgradeable
{
    /*#########################
    ##       Variables       ##
    ##########################*/

    uint256 internal _referralReward;

    /*#########################
    ##        Mappings       ##
    ##########################*/

    /**
     * @dev A mapping of addresses to referral codes (string).
     */
    mapping(address => string) internal _walletToReferralCode;

    /**
     * @dev A mapping of referrer codes (bytes32) to wallets.
     */
    mapping(bytes32 => address) internal _referralCodeToWallet;

    /**
     * @dev The individual rewards per referral value for each address.
     */
    mapping(address => uint256) internal _individualReward;

    /**
     * @dev A mapping of not claimed referrals to referer code
     */
    mapping(bytes32 => address[]) internal _claimableReferralWallets;

    /**
     * @dev A mapping of token ids of owners who referred by referrer code.
     */
    mapping(bytes32 => uint256[]) internal _referrerCodeToTokenIds;

    /*#########################
    ##         Events        ##
    ##########################*/

    /**
     * @dev Emitted when the referrer withdraws the own referral rewards from the contract balance.
     * @param owner The address of the referrer who withdrew the referral rewards.
     * @param balance The amount of referral rewards withdrawn by the referrer.
     * @param timestamp The timestamp when the referral rewards were withdrawn.
     * @param referralCount The number of claimable referrals for the referrer.
     */
    event ClaimedReferralReward(
        address indexed owner,
        uint256 indexed balance,
        uint referralCount,
        uint256 timestamp
    );

    /**
     * @dev Emitted when the referred wallet added the own referral rewards from the contract balance.
     * @param wallet The address of the wallet.
     * @param timestamp The timestamp when the referral rewards were claimed.
     */
    event RewardedWallet(address indexed wallet, uint256 timestamp);

    /**
     * @dev Emitted when the referred wallets added the own referral rewards from the contract balance.
     * @param wallets The addresses of the wallets.
     * @param timestamp The timestamp when the referral rewards were claimed.
     */
    event RewardedWallets(address[] wallets, uint256 timestamp);

    /**
     * @dev Emitted when the referral reward is changed.
     * @param referralReward The new referral reward.
     */
    event ChangedReferralReward(uint256 indexed referralReward);

    /*#########################
    ##    Write Functions    ##
    ##########################*/

    /**
     * @dev Claim referral rewards.
     */
    function claimReferralRewards() external whenNotPaused {
        // get reward value per referral
        uint256 rewardValue = 0;
        if (_individualReward[msg.sender] > 0) {
            rewardValue = _individualReward[msg.sender];
        } else {
            rewardValue = _referralReward;
        }

        // get an array of not claimed referrals
        bytes32 referralCodeBytes = keccak256(
            bytes(_walletToReferralCode[msg.sender])
        );
        address[] memory claimableReferralWallets = _claimableReferralWallets[
            referralCodeBytes
        ];

        uint256 referralsCount = claimableReferralWallets.length;

        emit RewardedWallets(claimableReferralWallets, block.timestamp);

        uint256 claimableReward = referralsCount * rewardValue;

        require(
            claimableReward > 0,
            "claimReferralRewards: No rewards available"
        );
        require(
            claimableReward <= address(this).balance,
            "claimReferralRewards: Insufficient funds"
        );

        delete _claimableReferralWallets[referralCodeBytes];

        (bool success, ) = msg.sender.call{value: claimableReward}("");
        require(success, "claimReferralRewards: transfer failed");

        emit ClaimedReferralReward(
            msg.sender,
            claimableReward,
            referralsCount,
            block.timestamp
        );
    }

    /**
     * @dev Sets the individual wallet reward.
     * @param wallet The address to set the individual reward for.
     * @param rewardValue The new reward value.
     * @notice Only the contract owner can call this function.
     */
    function setIndividualReward(
        address wallet,
        uint256 rewardValue
    ) external onlyOwner {
        _individualReward[wallet] = rewardValue;
    }

    /**
     * @dev Sets the referral reward.
     * @param referralReward The referral reward.
     * @notice Only the contract owner can call this function.
     * @notice The referral reward is the amount of native currency that will be paid to the referrer when a new score is minted.
     */
    function setReferralReward(uint256 referralReward) external onlyOwner {
        _referralReward = referralReward;

        emit ChangedReferralReward(referralReward);
    }

    /*#########################
    ##    Read Functions    ##
    ##########################*/

    /**
     * @dev Returns the referral code for the given address.
     * @param addr The address to get the referral code for.
     * @return The referral code for the given address.
     */
    function getReferralCode(
        address addr
    ) external view returns (string memory) {
        return _walletToReferralCode[addr];
    }

    /**
     * @dev Returns the address for the given referral code.
     * @param referralCode The referral code to get the wallet for.
     * @return The address for the given referral code.
     */
    function getWalletByReferralCode(
        string memory referralCode
    ) external view returns (address) {
        return getWalletByReferralCode(keccak256(bytes(referralCode)));
    }

    /**
     * @dev Returns the address for the given referral code.
     * @param referralCode The referral code to get the wallet for.
     * @return The address for the given referral code.
     */
    function getWalletByReferralCode(
        bytes32 referralCode
    ) private view returns (address) {
        require(
            referralCode != 0,
            "getWalletByReferralCode: Invalid referral code"
        );

        return _referralCodeToWallet[referralCode];
    }

    /**
     * @dev Returns the wallets for the given referrer code.
     * @param referrerCode The referrer code to get the wallets for.
     * @return The wallets for the given referrer code.
     */
    function getWalletsByReferrerCode(
        string memory referrerCode
    ) public view returns (address[] memory) {
        uint256[] memory referredTokenIds = _referrerCodeToTokenIds[
            keccak256(bytes(referrerCode))
        ];

        // Create a new dynamic array with the correct size to store valid token IDs
        address[] memory wallets = new address[](referredTokenIds.length);

        // Copy the valid token IDs to the new array
        for (uint256 i = 0; i < referredTokenIds.length; ++i) {
            wallets[i] = ownerOf(referredTokenIds[i]);
        }

        return wallets;
    }

    /**
     * @dev Returns the claimable reward for the given wallet.
     * @param wallet The wallet to get the claimable reward for.
     * @return The claimable reward for the given wallet.
     */
    function getClaimableReward(
        address wallet
    ) external view returns (uint256) {
        // get reward value per referral
        uint256 rewardValue = 0;
        if (_individualReward[wallet] > 0) {
            rewardValue = _individualReward[wallet];
        } else {
            rewardValue = _referralReward;
        }

        // get an array of all not claimed referrals
        bytes32 referralCodeBytes = keccak256(
            bytes(_walletToReferralCode[msg.sender])
        );
        address[] memory claimableReferralWallets = _claimableReferralWallets[
            referralCodeBytes
        ];

        return claimableReferralWallets.length * rewardValue;
    }

    /**
     * @dev Returns the current referral reward.
     * @return The current referral reward.
     * @notice Only the contract owner can call this function.
     */
    function getReferralReward() external view returns (uint256) {
        return _referralReward;
    }
}