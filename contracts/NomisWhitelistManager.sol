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
 * @title NomisWhitelistManager
 * @dev The Nomis whitelist manager contract.
 * @custom:security-contact info@nomis.cc
 */
contract NomisWhitelistManager is
    OwnableUpgradeable
{
    /*#########################
    ##        Mappings       ##
    ##########################*/

    /**
     * @dev A mapping of addresses with scoring calculation model to whitelist.
     */
    mapping(address => mapping(uint16 => bool)) public whitelist;

    /*#########################
    ##         Events        ##
    ##########################*/

    /**
     * @dev Emitted when the wallet is added to whitelist or removed from it for calculation model.
     * @param wallet The address of the wallet.
     * @param calculationModel The scoring calculation model.
     * @param status The status of the wallet in whitelist.
     */
    event ChangedWhitelistStatus(
        address indexed wallet,
        uint16 indexed calculationModel,
        bool indexed status
    );

    /*#########################
    ##    Write Functions    ##
    ##########################*/

    /**
     * @dev Adds the given addresses to the whitelist.
     * @param actors The addresses to be added to the whitelist.
     * @param calcModel The scoring calculation model.
     */
    function whitelistAddresses(
        address[] calldata actors,
        uint16 calcModel
    ) external onlyOwner {
        for (uint256 i = 0; i < actors.length; ++i) {
            whitelist[actors[i]][calcModel] = true;

            emit ChangedWhitelistStatus(actors[i], calcModel, true);
        }
    }

    /**
     * @dev Removes the given addresses from the whitelist.
     * @param actors The addresses to be removed from the whitelist.
     * @param calcModel The scoring calculation model.
     */
    function unWhitelistAddresses(
        address[] calldata actors,
        uint16 calcModel
    ) external onlyOwner {
        for (uint256 i = 0; i < actors.length; ++i) {
            whitelist[actors[i]][calcModel] = false;

            emit ChangedWhitelistStatus(actors[i], calcModel, false);
        }
    }
}