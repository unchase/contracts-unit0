// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./NomisReferralManager.sol";
import "./NomisPriceManager.sol";

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
 * @title NomisScore
 * @dev The NomisScore contract is an ERC721 token contract with additional functionality for managing scores.
 * @custom:security-contact info@nomis.cc
 */
contract NomisScore is
    NomisReferralManager,
    NomisPriceManager,
    EIP712Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    /*#########################
    ##       Variables       ##
    ##########################*/

    string private _baseUri;

    /*#########################
    ##         Events        ##
    ##########################*/

    /**
     * @dev Emitted when a score is minted or changed.
     * @param tokenId The changed token id.
     * @param owner The address to which the score is being changed.
     * @param score The score being changed.
     * @param calculationModel The scoring calculation model.
     * @param chainId The blockchain id in which the score was calculated.
     */
    event ChangedScore(
        uint256 indexed tokenId,
        address indexed owner,
        uint16 score,
        uint16 calculationModel,
        uint256 chainId,
        string metadataUrl,
        string referralCode,
        string referrerCode
    );

    /**
     * @dev Emitted when the owner of the contract withdraws the funds from the contract balance.
     * @param owner The address of the owner who withdrew the funds.
     * @param balance The amount of funds withdrawn by the owner.
     */
    event Withdrawal(address indexed owner, uint256 indexed balance);

    /**
     * @dev Emitted when the base URI is changed.
     * @param baseUri The new base URI.
     */
    event ChangedBaseURI(string indexed baseUri);

    /*#########################
    ##      Constructor      ##
    ##########################*/

    /**
     * @dev Constructor for the NomisScore ERC721Upgradeable contract.
     * @param initialFee The initial minting fee for the contract.
     * @param initialCalcModelsCount The initial scoring calculation models count.
     * Initializes the token ID counter to zero and sets the initial minting fee.
     */
    function initialize(
        uint256 initialFee,
        uint16 initialCalcModelsCount
    ) public initializer {
        __ERC721_init("NomisScore", "NMSS");
        __EIP712_init("NMSS", "0.9");
        __Ownable_init();

        _tokenIds.increment();
        _mintFee = initialFee;
        _updateFee = initialFee;
        require(
            initialCalcModelsCount > 0,
            "constructor: initialCalcModelsCount should be greater than 0"
        );
        _calcModelsCount = initialCalcModelsCount;
    }

    /*#########################
    ##    Write Functions    ##
    ##########################*/

    /**
     * @dev Sets the score for the calling address.
     * @param signature The signature used to verify the message.
     * @param score The score being set.
     * @param calculationModel The scoring calculation model.
     * @param deadline The deadline for submitting the transaction.
     * @param metadataUrl The URI for the token metadata.
     * @param chainId The blockchain id in which the score was calculated.
     * @param referralCode The minter referral code.
     * @param referrerCode The referrer code.
     * @param discountedMintFee The discounted mint fee.
     */
    function setScore(
        bytes calldata signature,
        uint16 score,
        uint16 calculationModel,
        uint256 deadline,
        string calldata metadataUrl,
        uint256 chainId,
        string calldata referralCode,
        string calldata referrerCode,
        uint256 discountedMintFee
    ) external payable whenNotPaused equalsFee(calculationModel, chainId, discountedMintFee) {
        require(score <= 10000, "setScore: Score must be less than 10000");
        require(
            block.timestamp <= deadline,
            "setScore: Signed transaction expired"
        );
        require(
            calculationModel < _calcModelsCount,
            "setScore: calculationModel should be less than calculation model count"
        );

        bytes32 referralCodeBytes = keccak256(bytes(referralCode));
        bytes32 referrerCodeBytes = keccak256(bytes(referrerCode));

        // Verify the signer of the message
        bytes32 messageHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "SetScoreMessage(uint16 score,uint16 calculationModel,address to,uint256 nonce,uint256 deadline,bytes32 metadataUrl,uint256 chainId,bytes32 referralCode,bytes32 referrerCode,uint256 discountedMintFee)"
                    ),
                    score,
                    calculationModel,
                    msg.sender,
                    _nonce[msg.sender]++,
                    deadline,
                    keccak256(bytes(metadataUrl)),
                    chainId,
                    referralCodeBytes,
                    referrerCodeBytes,
                    discountedMintFee
                )
            )
        );

        address signer = ECDSAUpgradeable.recover(messageHash, signature);
        require(
            signer == owner() && signer != address(0),
            "setScore: Invalid signature"
        );

        bool isNewScore = false;
        Score storage scoreStruct = _score[msg.sender][chainId][
            calculationModel
        ];
        if (scoreStruct.updated == 0) {
            isNewScore = true;
            scoreStruct.tokenId = _tokenIds.current();
        }

        uint256 tokenId = scoreStruct.tokenId;
        scoreStruct.updated = block.timestamp;
        if (scoreStruct.value != score) {
            scoreStruct.value = score;
        }

        if (isNewScore) {
            _walletToReferralCode[msg.sender] = referralCode;
            _referralCodeToWallet[referralCodeBytes] = msg.sender;
            _referrerCodeToTokenIds[referrerCodeBytes].push(tokenId);

            _safeMint(msg.sender, tokenId);
            _tokenIds.increment();
            ++calculationModelToMintCountUsed[calculationModel];

            tokenIdToCalcModel[tokenId] = calculationModel;
            tokenIdToChainId[tokenId] = chainId;
            _walletToTokenIds[msg.sender].push(tokenId);

            if (referrerCodeBytes != 0) {
                address referrerWallet = _referralCodeToWallet[
                    referrerCodeBytes
                ];
                if (referrerWallet != address(0)) {
                    uint256 rewardValue = 0;
                    if (_individualReward[referrerWallet] > 0) {
                        rewardValue = _individualReward[referrerWallet];
                    } else {
                        rewardValue = _referralReward;
                    }

                    (bool success, ) = payable(referrerWallet).call{
                        value: rewardValue
                    }("");
                    require(success, "setScore: claim referral reward failed");

                    emit RewardedWallet(msg.sender, block.timestamp);

                    emit ClaimedReferralReward(
                        referrerWallet,
                        rewardValue,
                        1,
                        block.timestamp
                    );
                } else {
                    _claimableReferralWallets[referrerCodeBytes].push(msg.sender);
                }
            }
        }

        _setTokenURI(tokenId, metadataUrl);

        emit ChangedScore(
            tokenId,
            msg.sender,
            score,
            calculationModel,
            chainId,
            metadataUrl,
            referralCode,
            referrerCode
        );
    }

    /**
     * @dev Allows the contract owner to withdraw a specific amount of native balance held by the contract.
     * Can only be called by the owner.
     * Emits a {Withdrawal} event upon successful withdrawal.
     * Throws a require error if there are no funds available for withdrawal.
     * Throws a require error if the specified withdrawal amount is greater than the contract balance.
     * @param amount The amount of balance to be withdrawn.
     */
    function withdraw(uint256 amount) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Withdrawal: No funds available");
        require(amount <= balance, "Withdrawal: Insufficient funds");

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal: transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Pauses the contract.
     * See {Pausable-_pause}.
     * Can only be called by the owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     * See {Pausable-_unpause}.
     * Can only be called by the owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Changes the base URI for token metadata.
     * @param baseUri The new base URI.
     */
    function setBaseUri(string memory baseUri) external onlyOwner {
        _baseUri = baseUri;

        emit ChangedBaseURI(baseUri);
    }

    /*#########################
    ##    Read Functions    ##
    ##########################*/

    /**
     * @dev Returns the score and associated metadata for a given address.
     * @param addr The address to get the score for.
     * @param blockchainId The blockchain id in which the score was calculated.
     * @param calcModel The scoring calculation model.
     * @return score The score for the specified address.
     * @return updated The timestamp when the score was last updated for the specified address.
     * @return tokenId The token id with score for the specified address.
     * @return calculationModel The scoring calculation model.
     * @return chainId The blockchain id in which the score was calculated.
     * @return owner The score owner.
     */
    function getScore(
        address addr,
        uint256 blockchainId,
        uint16 calcModel
    )
        external
        view
        returns (
            uint16 score,
            uint256 updated,
            uint256 tokenId,
            uint16 calculationModel,
            uint256 chainId,
            address owner
        )
    {
        Score storage scoreStruct = _score[addr][blockchainId][calcModel];

        score = scoreStruct.value;
        updated = scoreStruct.updated;
        tokenId = scoreStruct.tokenId;
        calculationModel = calcModel;
        chainId = blockchainId;
        owner = addr;
    }

    /**
     * @dev Returns the score and associated metadata for a given token id.
     * @param id The token id to get the score for.
     * @return score The score for the specified address.
     * @return updated The timestamp when the score was last updated for the specified address.
     * @return tokenId The token id with score for the specified address.
     * @return calculationModel The scoring calculation model.
     * @return chainId The blockchain id in which the score was calculated.
     * @return owner The score owner.
     */
    function getScoreByTokenId(
        uint256 id
    )
        external
        view
        returns (
            uint16 score,
            uint256 updated,
            uint256 tokenId,
            uint16 calculationModel,
            uint256 chainId,
            address owner
        )
    {
        address scoreOwner = ownerOf(id);
        calculationModel = tokenIdToCalcModel[id];
        chainId = tokenIdToChainId[id];

        Score storage scoreStruct = _score[scoreOwner][chainId][
            calculationModel
        ];

        score = scoreStruct.value;
        updated = scoreStruct.updated;
        tokenId = scoreStruct.tokenId;
        owner = scoreOwner;
    }

    /**
     * @dev Get the current token id.
     * @return The current token id.
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @dev Returns the token IDs associated with a given address.
     * @param addr The address for which to retrieve the token IDs.
     * @return An array of token IDs owned by the specified address.
     */
    function getTokenIds(
        address addr
    ) external view returns (uint256[] memory) {
        require(_tokenIds.current() > 0, "getTokenIds: No tokens minted");

        return _walletToTokenIds[addr];
    }

    /**
     * @dev Returns the base URI of the token. This method is called internally by the {tokenURI} method.
     * @return A string containing the base URI of the token.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /**
     * @dev Returns an URI for a given token ID.
     * This method is called by the {tokenURI} method from ERC721Upgradeable contract, which in turn can be called by clients to get metadata.
     * @param tokenId The token ID to query for the URI.
     * @return A string containing the URI for the given token ID.
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param tokenId The ID of the token being transferred.
     * @param batchSize The batch size.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable) {
        require(
            from == address(0),
            "NonTransferrableERC721Token: Nomis score can't be transferred."
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}