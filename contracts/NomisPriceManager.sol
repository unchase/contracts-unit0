// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./NomisStorageManager.sol";
import "./NomisWhitelistManager.sol";

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
 * @title NomisPriceManager
 * @dev The Nomis price manager contract.
 * @custom:security-contact info@nomis.cc
 */
contract NomisPriceManager is
    NomisStorageManager,
    NomisWhitelistManager
{
    /*#########################
    ##       Variables       ##
    ##########################*/

    uint256 internal _mintFee;
    uint256 internal _updateFee;
    
    /*#########################
    ##        Mappings       ##
    ##########################*/

    /**
     * @dev A mapping of calculation model to free mint count.
     */
    mapping(uint16 => uint16) public calculationModelToFreeMintCount;

    /**
     * @dev The individual mint fee value for each address.
     */
    mapping(address => mapping(uint16 => uint256)) internal _individualMintFee;

    /**
     * @dev The individual update fee value for each address.
     */
    mapping(address => mapping(uint16 => uint256)) internal _individualUpdateFee;

    /*#########################
    ##        Modifiers      ##
    ##########################*/

    /**
     * @dev Modifier that checks if the passed fee is equal to the current mint fee set.
     * @param calcModel The scoring calculation model.
     * @param chainId The blockchain id in which the score was calculated.
     * @param discountedMintFee The discounted mint fee.
     * Requirements:
     * The fee passed must be equal to the current mint or update fee set.
     */
    modifier equalsFee(uint16 calcModel, uint256 chainId, uint256 discountedMintFee) {
        address _wallet = msg.sender;
        uint256 _fee = msg.value;
        // check update fee

        uint256 walletUpdateFee = _individualUpdateFee[_wallet][calcModel];
        uint256 walletMintFee;
        if (discountedMintFee > 0) {
            walletMintFee = discountedMintFee;
        }

        Score storage scoreStruct = _score[_wallet][chainId][calcModel];

        if (_individualMintFee[_wallet][calcModel] > 0) {
            walletMintFee = _individualMintFee[_wallet][calcModel];
        }

        if (scoreStruct.updated > 0) {
            require(
                (_fee == walletUpdateFee && _fee > 0) ||
                    whitelist[_wallet][calcModel] ||
                    _fee == _updateFee,
                "Update fee: wrong update fee value"
            );
            _;
            return;
        }

        // check mint fee
        require(
            (_fee == walletMintFee && _fee > 0) ||
                whitelist[_wallet][calcModel] ||
                _fee == _mintFee ||
                calculationModelToMintCountUsed[calcModel] <
                calculationModelToFreeMintCount[calcModel],
            "Mint fee: wrong mint fee value"
        );
        _;
    }

    /*#########################
    ##         Events        ##
    ##########################*/

    /**
     * @dev Emitted when the mint fee is changed.
     * @param mintFee The new mint fee.
     */
    event ChangedMintFee(uint256 indexed mintFee);

    /**
     * @dev Emitted when the update fee is changed.
     * @param updateFee The new update fee.
     */
    event ChangedUpdateFee(uint256 indexed updateFee);

    /**
     * @dev Emitted when the individual mint fee is changed.
     * @param wallet The address of the wallet.
     * @param calculationModel The scoring calculation model.
     * @param mintFee The new individual mint fee.
     */
    event ChangedIndividualMintFee(
        address indexed wallet,
        uint16 indexed calculationModel,
        uint256 indexed mintFee
    );

    /**
     * @dev Emitted when the individual update fee is changed.
     * @param wallet The address of the wallet.
     * @param calculationModel The scoring calculation model.
     * @param updateFee The new individual update fee.
     */
    event ChangedIndividualUpdateFee(
        address indexed wallet,
        uint16 indexed calculationModel,
        uint256 indexed updateFee
    );

    /**
     * @dev Emitted when the free mint count is changed for calculation model.
     */
    event ChangedFreeMintCount(
        uint16 indexed calculationModel,
        uint16 indexed freeMintCount
    );

    /*#########################
    ##    Write Functions    ##
    ##########################*/

    /**
     * @dev Sets the new mint fee.
     * @param mintFee The new mint fee.
     * @notice Only the contract owner can call this function.
     */
    function setMintFee(uint256 mintFee) external onlyOwner {
        _mintFee = mintFee;

        emit ChangedMintFee(mintFee);
    }

    /**
     * @dev Sets the new update fee.
     * @param updateFee The new update fee.
     * @notice Only the contract owner can call this function.
     */
    function setUpdateFee(uint256 updateFee) external onlyOwner {
        _updateFee = updateFee;

        emit ChangedUpdateFee(updateFee);
    }

    /**
     * @dev Sets the individual mint fee for the given address.
     * @param wallet The address to set the individual mint fee for.
     * @param calcModel The scoring calculation model.
     * @param fee The individual mint fee.
     * @notice Only the contract owner can call this function.
     */
    function setIndividualMintFee(
        address wallet,
        uint16 calcModel,
        uint256 fee
    ) external onlyOwner {
        _individualMintFee[wallet][calcModel] = fee;

        emit ChangedIndividualMintFee(wallet, calcModel, fee);
    }

    /**
     * @dev Sets the individual update fee for the given address.
     * @param wallet The address to set the individual update fee for.
     * @param calcModel The scoring calculation model.
     * @param fee The individual update fee.
     * @notice Only the contract owner can call this function.
     */
    function setIndividualUpdateFee(
        address wallet,
        uint16 calcModel,
        uint256 fee
    ) external onlyOwner {
        _individualUpdateFee[wallet][calcModel] = fee;

        emit ChangedIndividualUpdateFee(wallet, calcModel, fee);
    }

    /**
     * @dev Sets the new free mint count for given scoring calculation model.
     * @param freeMintCount The new free mint count.
     * @param calcModel The scoring calculation model.
     * @notice Only the contract owner can call this function.
     */
    function setFreeMints(
        uint16 freeMintCount,
        uint16 calcModel
    ) external onlyOwner {
        calculationModelToFreeMintCount[calcModel] = freeMintCount;

        emit ChangedFreeMintCount(calcModel, freeMintCount);
    }

    /*#########################
    ##    Read Functions    ##
    ##########################*/

    /**
     * @dev Returns the current mint fee.
     * @return The current mint fee.
     */
    function getMintFee() external view returns (uint256) {
        return _mintFee;
    }

    /**
     * @dev Returns the current update fee.
     * @return The current update fee.
     */
    function getUpdateFee() external view returns (uint256) {
        return _updateFee;
    }

    /**
     * @dev Sets the individual mint fee for the given address.
     * @param wallet The address to set the individual mint fee for.
     * @param calcModel The scoring calculation model.
     * @return The individual mint fee.
     * @notice Only the contract owner can call this function.
     */
    function getIndividualMintFee(
        address wallet,
        uint16 calcModel
    ) external view returns (uint256) {
        return _individualMintFee[wallet][calcModel];
    }

    /**
     * @dev Sets the individual update fee for the given address.
     * @param wallet The address to set the individual update fee for.
     * @param calcModel The scoring calculation model.
     * @return The individual update fee.
     * @notice Only the contract owner can call this function.
     */
    function getIndividualUpdateFee(
        address wallet,
        uint16 calcModel
    ) external view returns (uint256) {
        return _individualUpdateFee[wallet][calcModel];
    }

    /**
     * @dev Returns the current free mint count for given scoring calculation model.
     * @param calcModel The scoring calculation model.
     * @return The current free mint count.
     */
    function getFreeMints(uint16 calcModel) external view returns (uint16) {
        return calculationModelToFreeMintCount[calcModel];
    }
}