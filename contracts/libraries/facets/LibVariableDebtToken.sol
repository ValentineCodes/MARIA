// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LayoutTypes} from "../types/LayoutTypes.sol";
import {Query} from "../utils/Query.sol";
import {SafeCast} from "../../dependencies/openzeppelin/contracts/SafeCast.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Errors} from "../utils/Errors.sol";
import {MathUtils, WadRayMath} from "../math/MathUtils.sol";

library LibVariableDebtToken {
    using SafeCast for uint256;
    using WadRayMath for uint256;

    bytes32 internal constant STORAGE_SLOT =
        keccak256("variableDebtToken.storage");
    
    // Credit Delegation Typehash
    bytes32 internal constant DELEGATION_WITH_SIG_TYPEHASH = keccak256('DelegationWithSig(address delegatee,uint256 value,uint256 nonce,uint256 deadline)');
    bytes internal constant EIP712_REVISION = bytes('1');
    bytes32 internal constant EIP712_DOMAIN = keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

    uint256 internal constant DEBT_TOKEN_REVISION = 0x1;

    uint256 internal immutable _chainId;

    /**
     * @dev Emitted when an aToken is initialized
     * @param underlyingAsset The address of the underlying asset
     * @param pool The address of the associated pool
     * @param treasury The address of the treasury
     * @param decimals The decimals of the underlying
     * @param name The name of the aToken
     * @param symbol The symbol of the aToken
     * @param params A set of encoded parameters for additional initialization
     **/
    event Initialized(
        address indexed underlyingAsset,
        address indexed pool,
        uint8 decimals,
        string name,
        string symbol,
        bytes params
    );

      /**
     * @dev Emitted on `approveDelegation` and `borrowAllowance
     * @param fromUser The address of the delegator
     * @param toUser The address of the delegatee
     * @param asset The address of the delegated asset
     * @param amount The amount being delegated
     */
    event BorrowAllowanceDelegated(
        address indexed fromUser,
        address indexed toUser,
        address indexed asset,
        uint256 amount
    );

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted after the mint action
     * @param caller The address performing the mint
     * @param onBehalfOf The address of the user that will receive the minted scaled balance tokens
     * @param value The amount being minted (user entered amount + balance increase from interest)
     * @param balanceIncrease The increase in balance since the last action of the user
     * @param index The next liquidity index of the reserve
     **/
    event Mint(
        address indexed caller,
        address indexed onBehalfOf,
        uint256 value,
        uint256 balanceIncrease,
        uint256 index
    );

    /**
     * @dev Emitted after scaled balance tokens are burned
     * @param from The address from which the scaled tokens will be burned
     * @param target The address that will receive the underlying, if any
     * @param value The amount being burned (user entered amount - balance increase from interest)
     * @param balanceIncrease The increase in balance since the last action of the user
     * @param index The next liquidity index of the reserve
     **/
    event Burn(
        address indexed from,
        address indexed target,
        uint256 value,
        uint256 balanceIncrease,
        uint256 index
    );

    modifier initializer(LayoutTypes.VariableDebtTokenLayout storage s) {
        uint256 revision = 0x1;
        require(
            s.initializing ||
                Query.isConstructor() ||
                revision > s.lastInitializedRevision,
            "Contract instance has already been initialized"
        );

        bool isTopLevelCall = !s.initializing;
        if (isTopLevelCall) {
            s.initializing = true;
            s.lastInitializedRevision = revision;
        }

        _;

        if (isTopLevelCall) {
            s.initializing = false;
        }
    }

    function layout()
        internal
        pure
        returns (LayoutTypes.VariableDebtTokenLayout storage s)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /**
     * @notice Only called in the constructor of {MTokenFacet}
     * @param chainId Chain id of deployed contract
     */
    function _constructor(uint256 chainId) internal {
        _chainId = chainId;
    }

    function initializeVariableDebtToken(        
        LayoutTypes.VariableDebtTokenLayout storage s,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address pool,
        address underlyingAsset,
        bytes calldata params
    ) external {
        s._name = name;
        s._symbol = symbol;
        s._decimals = decimals;
        s._pool = pool;
        s._underlyingAsset = underlyingAsset;
        s._domainSeparator = _calculateDomainSeparator();

        emit Initialized(
            underlyingAsset,
            pool,
            decimals,
            name,
            symbol,
            params
        );
    }

    function EIP712_REVISION() internal view returns (bytes) {
        return EIP712_REVISION;
    }

    function DELEGATION_WITH_SIG_TYPEHASH() internal view returns (bytes32) {
        return DELEGATION_WITH_SIG_TYPEHASH;
    }

    function DEBT_TOKEN_REVISION() internal view returns (uint256) {
        return DEBT_TOKEN_REVISION;
    }

    function DOMAIN_SEPARATOR(LayoutTypes.VariableDebtTokenLayout storage s) internal view returns (bytes32) {
        if(block.chainId === _chainId) {
            return s._domainSeparator;
        }
        return _calculateDomainSeparator();
    }

    function UNDERLYING_ASSET_ADDRESS(LayoutTypes.VariableDebtTokenLayout storage s)
        internal
        view
        returns (address)
    {
        return s._underlyingAsset;
    }

    function nonces(LayoutTypes.VariableDebtTokenLayout storage s, address owner) internal view returns (uint256) {
        return s._nonces[owner];
    }

    function name(LayoutTypes.VariableDebtTokenLayout storage s) internal view returns (string memory) {
        return s._name;
    }

    function symbol(LayoutTypes.VariableDebtTokenLayout storage s) internal view returns (string memory) {
        return s._symbol;
    }

    function decimals(LayoutTypes.VariableDebtTokenLayout storage s) internal view returns (uint8) {
        return s._decimals;
    }

    function totalSupply(LayoutTypes.VariableDebtTokenLayout storage s) external view returns (uint256) {
        return s._totalSupply.rayMul(IPool(s._pool).getReserveNormalizedVariableDebt(s._underlyingAsset));
    }

    function balanceOf(LayoutTypes.VariableDebtTokenLayout storage s, address user) internal view returns (uint256) {
        uint256 scaledBalance = s._userState[user].balance;

        if (scaledBalance == 0) {
            return 0;
        }

        return scaledBalance.rayMul(IPool(s._pool).getReserveNormalizedVariableDebt(s._underlyingAsset));
    }

    function approveDelegation(LayoutTypes.VariableDebtTokenLayout storage s, address delegatee, uint256 amount) internal {
        _approveDelegation(s, Query._msgSender(), delegatee, amount);
    }

    function delegationWithSig(
        LayoutTypes.VariableDebtTokenLayout storage s,
        address delegator,
        address delegatee,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        require(delegator != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
        //solium-disable-next-line
        require(block.timestamp <= deadline, Errors.INVALID_EXPIRATION);
        uint256 currentValidNonce = s._nonces[delegator];
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR(s),
                keccak256(
                    abi.encode(DELEGATION_WITH_SIG_TYPEHASH, delegatee, value, currentValidNonce, deadline)
                )
            )
        );
        require(delegator == ecrecover(digest, v, r, s), Errors.INVALID_SIGNATURE);
        s._nonces[delegator] = currentValidNonce + 1;
        _approveDelegation(s, delegator, delegatee, value);
    }

    function mint(
        LayoutTypes.VariableDebtTokenLayout storage s,
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    )
        internal
        returns (
            bool,
            uint256
        )
    {
        if(user != onBehalfOf) {
            _decreaseBorrowAllowance(s, onBehalfOf, user, amount);
        }

        return (_mintScaled(s, user, onBehalfOf, amount, index), s._totalSupply);
    }

    function burn(LayoutTypes.VariableDebtTokenLayout storage s, from, amount, index) internal returns (uint256) {
        _burnScaled(s, from, address(0), amount, index);
        return s._totalSupply;
    }

        /**
     * @notice Compute the current domain separator
     * @return The domain separator for the token
     */
    function _calculateDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN,
                    keccak256(bytes("Maria")),
                    keccak256(EIP712_REVISION),
                    block.chainid,
                    address(this)
                )
            );
    }

      /**
     * @notice Decreases the borrow allowance of a user on the specific debt token.
     * @param delegator The address delegating the borrowing power
     * @param delegatee The address receiving the delegated borrowing power
     * @param amount The amount to subtract from the current allowance
     **/
    function _decreaseBorrowAllowance(
        LayoutTypes.VariableDebtTokenLayout storage s,
        address delegator,
        address delegatee,
        uint256 amount
    ) internal {
        uint256 newAllowance = s._borrowAllowances[delegator][delegatee] - amount;

        s._borrowAllowances[delegator][delegatee] = newAllowance;

        emit BorrowAllowanceDelegated(delegator, delegatee, s._underlyingAsset, newAllowance);
    }

    /**
     * @notice Updates the borrow allowance of a user on the specific debt token.
     * @param delegator The address delegating the borrowing power
     * @param delegatee The address receiving the delegated borrowing power
     * @param amount The allowance amount being delegated.
     **/
    function _approveDelegation(
        LayoutTypes.VariableDebtTokenLayout storage s,
        address delegator,
        address delegatee,
        uint256 amount
    ) internal {
        s._borrowAllowances[delegator][delegatee] = amount;
        emit BorrowAllowanceDelegated(delegator, delegatee, s._underlyingAsset, amount);
    }

      /**
     * @notice Implements the basic logic to mint a scaled balance token.
     * @param caller The address performing the mint
     * @param onBehalfOf The address of the user that will receive the scaled tokens
     * @param amount The amount of tokens getting minted
     * @param index The next liquidity index of the reserve
     * @return `true` if the the previous balance of the user was 0
     **/
    function _mintScaled(
        LayoutTypes.VariableDebtTokenLayout storage s,
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) internal returns (bool) {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_MINT_AMOUNT);

        uint256 scaledBalance = s._userState[onBehalfOf].balance;
        uint256 balanceIncrease = scaledBalance.rayMul(index) - scaledBalance.rayMul(s._userState[onBehalfOf].additionalData);

        s._userState[onBehalfOf].additionalData = index.toUint128();

        _mint(onBehalfOf, amountScaled.toUint128());

        uint256 amountToMint = amount + balanceIncrease;
        
        emit Transfer(address(0), onBehalfOf, amountToMint);
        emit Mint(caller, onBehalfOf, amountToMint, balanceIncrease, index);

        return (scaledBalance == 0);
    }

    /**
     * @notice Implements the basic logic to burn a scaled balance token.
     * @dev In some instances, a burn transaction will emit a mint event
     * if the amount to burn is less than the interest that the user accrued
     * @param user The user which debt is burnt
     * @param target The address that will receive the underlying, if any
     * @param amount The amount getting burned
     * @param index The variable debt index of the reserve
     **/
    function _burnScaled(
        LayoutTypes.VariableDebtTokenLayout storage s,
        address user,
        address target,
        uint256 amount,
        uint256 index
    ) internal {
        uint256 amountScaled = amount.rayDiv(index);

        require(amountScaled != 0, Errors.INVALID_BURN_AMOUNT);

        uint256 scaledBalance = s._userState[user].balance;
        uint256 balanceIncrease = scaledBalance.rayMul(index) - scaledBalance.rayMul(s._userState[user].additionalData);

        s._userState[user].additionalData = index.toUint128();

        _burn(user, amountScaled.toUint128());

        if (balanceIncrease > amount) {
            uint256 amountToMint = balanceIncrease - amount;

            emit Transfer(address(0), user, amountToMint);
            emit Mint(user, user, amountToMint, balanceIncrease, index);
        } else {
            uint256 amountToBurn = amount - balanceIncrease;

            emit Transfer(user, address(0), amountToBurn);
            emit Burn(user, target, amountToBurn, balanceIncrease, index);
        }
    }

    /**
     * @notice Mints tokens to an account and apply incentives if defined
     * @param account The address receiving tokens
     * @param amount The amount of tokens to mint
     */
    function _mint(LayoutTypes.VariableDebtTokenLayout storage s, address account, uint128 amount) internal {
        uint256 oldTotalSupply = s._totalSupply;
        s._totalSupply = oldTotalSupply + amount;

        uint128 oldAccountBalance = s._userState[account].balance;
        s._userState[account].balance = oldAccountBalance + amount;
    }

    /**
     * @notice Burns tokens from an account and apply incentives if defined
     * @param account The account whose tokens are burnt
     * @param amount The amount of tokens to burn
     */
    function _burn(LayoutTypes.VariableDebtTokenLayout storage s, address account, uint128 amount) internal {
        uint256 oldTotalSupply = s._totalSupply;
        s._totalSupply = oldTotalSupply - amount;

        uint128 oldAccountBalance = s._userState[account].balance;
        s._userState[account].balance = oldAccountBalance - amount;
    }

}