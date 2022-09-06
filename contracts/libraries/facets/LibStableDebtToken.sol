// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LayoutTypes} from "../types/LayoutTypes.sol";
import {Query} from "../utils/Query.sol";
import {SafeCast} from "../../dependencies/openzeppelin/contracts/SafeCast.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Errors} from "../utils/Errors.sol";
import {MathUtils, WadRayMath} from "../math/MathUtils.sol";

library LibStableDebtToken {
    using SafeCast for uint256;
    using WadRayMath for uint256;

    bytes32 internal constant STORAGE_SLOT =
        keccak256("stableDebtToken.storage");
    
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
     * @dev Emitted when new stable debt is minted
     * @param user The address of the user who triggered the minting
     * @param onBehalfOf The recipient of stable debt tokens
     * @param amount The amount minted (user entered amount + balance increase from interest)
     * @param currentBalance The current balance of the user
     * @param balanceIncrease The increase in balance since the last action of the user
     * @param newRate The rate of the debt after the minting
     * @param avgStableRate The next average stable rate after the minting
     * @param newTotalSupply The next total supply of the stable debt token after the action
     **/
    event Mint(
        address indexed user,
        address indexed onBehalfOf,
        uint256 amount,
        uint256 currentBalance,
        uint256 balanceIncrease,
        uint256 newRate,
        uint256 avgStableRate,
        uint256 newTotalSupply
    );

    /**
     * @dev Emitted when new stable debt is burned
     * @param from The address from which the debt will be burned
     * @param amount The amount being burned (user entered amount - balance increase from interest)
     * @param currentBalance The current balance of the user
     * @param balanceIncrease The the increase in balance since the last action of the user
     * @param avgStableRate The next average stable rate after the burning
     * @param newTotalSupply The next total supply of the stable debt token after the action
     **/
    event Burn(
        address indexed from,
        uint256 amount,
        uint256 currentBalance,
        uint256 balanceIncrease,
        uint256 avgStableRate,
        uint256 newTotalSupply
    );

    modifier initializer(LayoutTypes.StableDebtTokenLayout storage s) {
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
        returns (LayoutTypes.StableDebtTokenLayout storage s)
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

    function initializeStableDebtToken(        
        LayoutTypes.StableDebtTokenLayout storage s,
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

    function DOMAIN_SEPARATOR(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (bytes32) {
        if(block.chainId === _chainId) {
            return s._domainSeparator;
        }
        return _calculateDomainSeparator();
    }

    function UNDERLYING_ASSET_ADDRESS(LayoutTypes.StableDebtTokenLayout storage s)
        internal
        view
        returns (address)
    {
        return s._underlyingAsset;
    }

    function nonces(LayoutTypes.StableDebtTokenLayout storage s, address owner) internal view returns (uint256) {
        return s._nonces[owner];
    }

    function name(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (string memory) {
        return s._name;
    }

    function symbol(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (string memory) {
        return s._symbol;
    }

    function decimals(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (uint8) {
        return s._decimals;
    }

    function totalSupply(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (uint256) {
        return _calcTotalSupply(s, s._avgStableRate);
    }

    function balanceOf(LayoutTypes.StableDebtTokenLayout storage s, address account) internal view returns (uint256) {
        uint256 accountBalance = s._userState[account].balance;
        uint256 stableRate = s._userState[account].additionalData;

        if (accountBalance == 0) {
            return 0;
        }
        uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(stableRate, s._timestamps[account]);

        return accountBalance.rayMul(cumulatedInterest);
    }

    function getAverageStableRate(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (uint256) {
        return s._avgStableRate;
    }

    function getUserLastUpdated(LayoutTypes.StableDebtTokenLayout storage s, address user) internal view returns (uint40) {
        return s._timestamps[user];
    }

    function getUserStableRate(LayoutTypes.StableDebtTokenLayout storage s, address user) internal view returns (uint256) {
        return s._userState[user].additionalData;
    }

    function getSupplyData(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (uint256, uint256, uint256, uint40) {
        uint256 avgRate = s._avgStableRate;
        return (s._totalSupply, _calcTotalSupply(s, avgRate), avgRate, s._totalSupplyTimestamp);
    }

    function getTotalSupplyAndAvgRate(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (uint256, uint256) {
        uint256 avgRate = s._avgStableRate;
        return (_calcTotalSupply(s, avgRate), avgRate);
    }

    function getTotalSupplyLastUpdated(LayoutTypes.StableDebtTokenLayout storage s) internal view returns (uint40) {
        return s._totalSupplyTimestamp;
    }

    function principalBalanceOf(LayoutTypes.StableDebtTokenLayout storage s, address user) internal view returns (uint256) {
        return s._userState[account].balance;
    }

    function borrowAllowance(LayoutTypes.StableDebtTokenLayout storage s, address fromUser, address toUser) internal view returns (uint256) {
        return s._borrowAllowances[fromUser][toUser];
    }

    struct MintLocalVars {
        uint256 previousSupply;
        uint256 nextSupply;
        uint256 amountInRay;
        uint256 currentStableRate;
        uint256 nextStableRate;
        uint256 currentAvgStableRate;
    }

    function mint(LayoutTypes.StableDebtTokenLayout storage s, address user, address onBehalfOf, uint256 amount, uint256 rate) internal returns (bool, uint256, uint256) {
        MintLocalVars memory vars;

        if (user != onBehalfOf) {
            _decreaseBorrowAllowance(s, onBehalfOf, user, amount);
        }

        (, uint256 currentBalance, uint256 balanceIncrease) = _calculateBalanceIncrease(s, onBehalfOf);

        vars.previousSupply = totalSupply(s);
        vars.currentAvgStableRate = s._avgStableRate;
        vars.nextSupply = s._totalSupply = vars.previousSupply + amount;

        vars.amountInRay = amount.wadToRay();

        vars.currentStableRate = s._userState[onBehalfOf].additionalData;
        vars.nextStableRate = (vars.currentStableRate.rayMul(currentBalance.wadToRay()) +
        vars.amountInRay.rayMul(rate)).rayDiv((currentBalance + amount).wadToRay());

        s._userState[onBehalfOf].additionalData = vars.nextStableRate.toUint128();

        //solium-disable-next-line
        s._totalSupplyTimestamp = s._timestamps[onBehalfOf] = uint40(block.timestamp);

        // Calculates the updated average stable rate
        vars.currentAvgStableRate = s._avgStableRate = (
        (vars.currentAvgStableRate.rayMul(vars.previousSupply.wadToRay()) +
            rate.rayMul(vars.amountInRay)).rayDiv(vars.nextSupply.wadToRay())
        ).toUint128();

        uint256 amountToMint = amount + balanceIncrease;
        _mint(s, onBehalfOf, amountToMint, vars.previousSupply);

        emit Transfer(address(0), onBehalfOf, amountToMint);
        emit Mint(
            user,
            onBehalfOf,
            amountToMint,
            currentBalance,
            balanceIncrease,
            vars.nextStableRate,
            vars.currentAvgStableRate,
            vars.nextSupply
        );

        return (currentBalance == 0, vars.nextSupply, vars.currentAvgStableRate);
    }

    function burn(LayoutTypes.StableDebtTokenLayout storage s, address from, uint256 amount) internal returns (uint256, uint256) {
        (, uint256 currentBalance, uint256 balanceIncrease) = _calculateBalanceIncrease(s, from);

        uint256 previousSupply = totalSupply(s);
        uint256 nextAvgStableRate = 0;
        uint256 nextSupply = 0;
        uint256 userStableRate = s._userState[from].additionalData;

        // Since the total supply and each single user debt accrue separately,
        // there might be accumulation errors so that the last borrower repaying
        // might actually try to repay more than the available debt supply.
        // In this case we simply set the total supply and the avg stable rate to 0
        if (previousSupply <= amount) {
            s._avgStableRate = 0;
            s._totalSupply = 0;
        } else {
            nextSupply = s._totalSupply = previousSupply - amount;
            uint256 firstTerm = uint256(s._avgStableRate).rayMul(previousSupply.wadToRay());
            uint256 secondTerm = userStableRate.rayMul(amount.wadToRay());

            // For the same reason described above, when the last user is repaying it might
            // happen that user rate * user balance > avg rate * total supply. In that case,
            // we simply set the avg rate to 0
            if (secondTerm >= firstTerm) {
                nextAvgStableRate = s._totalSupply = s._avgStableRate = 0;
            } else {
                nextAvgStableRate = s._avgStableRate = ((firstTerm - secondTerm).rayDiv(nextSupply.wadToRay())).toUint128();
            }
        }

        if (amount == currentBalance) {
            s._userState[from].additionalData = 0;
            s._timestamps[from] = 0;
        } else {
            //solium-disable-next-line
            s._timestamps[from] = uint40(block.timestamp);
        }
        //solium-disable-next-line
        s._totalSupplyTimestamp = uint40(block.timestamp);

        if (balanceIncrease > amount) {
            uint256 amountToMint = balanceIncrease - amount;
            
            _mint(s, from, amountToMint, previousSupply);

            emit Transfer(address(0), from, amountToMint);
            emit Mint(
                from,
                from,
                amountToMint,
                currentBalance,
                balanceIncrease,
                userStableRate,
                nextAvgStableRate,
                nextSupply
            );
        } else {
            uint256 amountToBurn = amount - balanceIncrease;

            _burn(s, from, amountToBurn, previousSupply);

            emit Transfer(from, address(0), amountToBurn);
            emit Burn(from, amountToBurn, currentBalance, balanceIncrease, nextAvgStableRate, nextSupply);
        }

        return (nextSupply, nextAvgStableRate);
    }

    function approveDelegation(LayoutTypes.StableDebtTokenLayout storage s, address delegatee, uint256 amount) internal {
        _approveDelegation(s, Query._msgSender(), delegatee, amount);
    }

    function delegationWithSig(
        LayoutTypes.StableDebtTokenLayout storage s,
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
     * @notice Calculates the total supply
     * @param avgRate The average rate at which the total supply increases
     * @return The debt balance of the user since the last burn/mint action
     **/
    function _calcTotalSupply(LayoutTypes.StableDebtTokenLayout storage s, uint256 avgRate) internal view returns (uint256) {
        uint256 principalSupply = s._totalSupply;

        if (principalSupply == 0) {
            return 0;
        }

        uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(avgRate, s._totalSupplyTimestamp);

        return principalSupply.rayMul(cumulatedInterest);
    }

      /**
     * @notice Calculates the increase in balance since the last user interaction
     * @param user The address of the user for which the interest is being accumulated
     * @return The previous principal balance
     * @return The new principal balance
     * @return The balance increase
     **/
    function _calculateBalanceIncrease(LayoutTypes.StableDebtTokenLayout storage s, address user) internal view returns (uint256, uint256, uint256) {
        uint256 previousPrincipalBalance = principalBalanceOf(s, user);

        if (previousPrincipalBalance == 0) {
            return (0, 0, 0);
        }

        uint256 newPrincipalBalance = balanceOf(s, user);

        return (
            previousPrincipalBalance,
            newPrincipalBalance,
            newPrincipalBalance - previousPrincipalBalance
        );
    }

      /**
     * @notice Updates the borrow allowance of a user on the specific debt token.
     * @param delegator The address delegating the borrowing power
     * @param delegatee The address receiving the delegated borrowing power
     * @param amount The allowance amount being delegated.
     **/
    function _approveDelegation(
        LayoutTypes.StableDebtTokenLayout storage s,
        address delegator,
        address delegatee,
        uint256 amount
    ) internal {
        s._borrowAllowances[delegator][delegatee] = amount;
        emit BorrowAllowanceDelegated(delegator, delegatee, s._underlyingAsset, amount);
    }

    /**
     * @notice Decreases the borrow allowance of a user on the specific debt token.
     * @param delegator The address delegating the borrowing power
     * @param delegatee The address receiving the delegated borrowing power
     * @param amount The amount to subtract from the current allowance
     **/
    function _decreaseBorrowAllowance(
        LayoutTypes.StableDebtTokenLayout storage s,
        address delegator,
        address delegatee,
        uint256 amount
    ) internal {
        uint256 newAllowance = s._borrowAllowances[delegator][delegatee] - amount;

        s._borrowAllowances[delegator][delegatee] = newAllowance;

        emit BorrowAllowanceDelegated(delegator, delegatee, s._underlyingAsset, newAllowance);
    }

      /**
     * @notice Mints stable debt tokens to a user
     * @param account The account receiving the debt tokens
     * @param amount The amount being minted
     **/
    function _mint(
        LayoutTypes.StableDebtTokenLayout storage s,
        address account,
        uint256 amount
    ) internal {
        uint128 castAmount = amount.toUint128();
        uint128 oldAccountBalance = s._userState[account].balance;
        s._userState[account].balance = oldAccountBalance + castAmount;
    }

    /**
     * @notice Burns stable debt tokens of a user
     * @param account The user getting his debt burned
     * @param amount The amount being burned
     **/
    function _burn(
        LayoutTypes.StableDebtTokenLayout storage s,
        address account,
        uint256 amount
    ) internal {
        uint128 castAmount = amount.toUint128();
        uint128 oldAccountBalance = s._userState[account].balance;
        s._userState[account].balance = oldAccountBalance - castAmount;
    }
}
