// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event AdminTransferred(address indexed user, address indexed newAdmin);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public admin;
    // If a user mistakenly transfers tokens to this contract, this account can withdraw them.
    address public abandonedBalanceOwner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyAdmin() virtual {
        require(msg.sender == admin, '!admin');
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;
        admin = _owner;
        abandonedBalanceOwner = _owner;

        emit OwnershipTransferred(address(0), _owner);
        emit AdminTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }

    function transferAdmin(address newAdmin) public virtual onlyAdmin {
        admin = newAdmin;

        emit AdminTransferred(msg.sender, newAdmin);
    }

    function transferAbandonedBalanceOwnership(address newOwner) public virtual {
        require(msg.sender == abandonedBalanceOwner, '!owner');
        abandonedBalanceOwner = newOwner;
    }
}
