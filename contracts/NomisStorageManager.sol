// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
 * @title NomisStorageManager
 * @dev The Nomis storage manager contract.
 * @custom:security-contact info@nomis.cc
 */
contract NomisStorageManager is
    OwnableUpgradeable
{
    /*#########################
    ##        Structs        ##
    ##########################*/

    /**
     * @dev The Score struct represents a user's score.
     * @param tokenId The token id with score for the specified address.
     * @param updated The timestamp when the score was last updated for the specified address.
     * @param value The score for the specified address.
     */
    struct Score {
        uint256 tokenId;
        uint256 updated;
        uint16 value;
    }

    /*#########################
    ##       Variables       ##
    ##########################*/

    uint16 internal _calcModelsCount;

    /*#########################
    ##        Mappings       ##
    ##########################*/

    /**
     * @dev A mapping of token id to calculation model.
     */
    mapping(uint256 => uint16) public tokenIdToCalcModel;

    /**
     * @dev A mapping of token id to chain id.
     */
    mapping(uint256 => uint256) public tokenIdToChainId;

    /**
     * @dev A mapping of calculation model to mint count used.
     */
    mapping(uint16 => uint256) public calculationModelToMintCountUsed;

    /**
     * @dev A mapping of addresses, chains and calculation methods to scores.
     */
    mapping(address => mapping(uint256 => mapping(uint16 => Score)))
        internal _score;

    /**
     * @dev A mapping of addresses to nonces for replay protection.
     */
    mapping(address => uint256) internal _nonce;

    /**
     * @dev A mapping of wallet to its token ids.
     */
    mapping(address => uint256[]) internal _walletToTokenIds;

    /*#########################
    ##         Events        ##
    ##########################*/

    /**
     * Emitted when the calculation models count is changed.
     */
    event ChangedCalculationModelsCount(uint256 indexed calcModelsCount);

    /*#########################
    ##    Write Functions    ##
    ##########################*/

    /**
     * @dev Sets the number of scoring calculation models.
     * @param calcModelsCount The number of scoring calculation models to set.
     */
    function setCalcModelsCount(uint16 calcModelsCount) external onlyOwner {
        require(
            calcModelsCount > 0,
            "setCalcModelsCount: calcModelsCount should be greater than 0"
        );
        _calcModelsCount = calcModelsCount;

        emit ChangedCalculationModelsCount(calcModelsCount);
    }

    /*#########################
    ##    Read Functions    ##
    ##########################*/

    /**
     * @dev Returns the number of scoring calculation models.
     * @return The number of scoring calculation models.
     */
    function getCalcModelsCount() external view returns (uint16) {
        return _calcModelsCount;
    }

    /**
     * @dev Returns the nonce value for the calling address.
     * @param addr The address to get the nonce for.
     * @return The nonce value for the calling address.
     */
    function getNonce(address addr) external view returns (uint256) {
        return _nonce[addr];
    }
}