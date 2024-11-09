// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @author darianb.eth
/// @custom:project Durin
/// @custom:company NameStone

import {StringUtils} from "./utils/StringUtils.sol";
import {BytesUtilsSub} from "./utils/BytesUtilsSub.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IL2Registry} from "./IL2Registry.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error InsufficientValue();
error ERC721NonexistentToken(uint256 tokenId);

contract L2Registrar is AccessControl {
    using StringUtils for string;
    using Address for address payable;
    using BytesUtilsSub for bytes;

    event AddressWithdrew(address indexed _address, uint256 indexed amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event NameRegistered(
        string indexed label,
        address indexed owner,
        uint256 price
    );

    // Admin Role for withdrawing funds
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // target registry
    IL2Registry public immutable targetRegistry;

    // The price for registrations.
    uint256 public namePrice;

    constructor(IL2Registry _registry) {
        targetRegistry = _registry;

        // Grant the contract deployer the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Checks if a given tokenId is available for registration.
     * @param tokenId The tokenId to check.
     * @return available True if the tokenId is available, false otherwise.
     */
    function available(uint256 tokenId) external view returns (bool) {
        try targetRegistry.ownerOf(tokenId) returns (address) {
            // If ownerOf doesn't revert, the token exists, so it is not available
            return false;
        } catch (bytes memory reason) {
            // Catch the specific custom error using error signature comparison
            if (
                keccak256(reason) ==
                keccak256(
                    abi.encodeWithSelector(
                        ERC721NonexistentToken.selector,
                        tokenId
                    )
                )
            ) {
                // Token does not exist (minting has not happened), it is available
                return true;
            } else {
                // Re-throw if it's another type of error
                revert(string(reason));
            }
        }
    }

    // a register function that uses mint to register a label
    function register(string memory label, address owner) public payable {
        // Check to make sure the caller sent enough Eth.
        if (msg.value < namePrice) {
            revert InsufficientValue();
        }

        // use setLabel to register the label
        targetRegistry.register(label, owner);

        // we can overestimate the price and then return any difference.
        if (msg.value > namePrice) {
            payable(msg.sender).sendValue(msg.value - namePrice);
        }
    }

    /**
     * @notice Set a price for a name
     * @param price The price in native currency
     */
    function setPrice(uint256 price) public onlyRole(ADMIN_ROLE) {
        uint256 oldPrice = namePrice;
        namePrice = price;
        emit PriceUpdated(oldPrice, price);
    }

    /**
     * @notice A function to allow referrers, name owners, or the contract owner to withdraw.
     */

    function withdraw(uint256 amount) public onlyRole(ADMIN_ROLE) {
        //get the address of the sender
        address payable sender = payable(msg.sender);

        emit AddressWithdrew(sender, amount);

        // Send the amount to the contract owner's address.
        sender.sendValue(amount);
    }
}