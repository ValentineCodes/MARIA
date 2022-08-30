// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LayoutTypes} from "../types/LayoutTypes.sol";
import {Query} from "../utils/Query.sol";
import {SafeCast} from '../../dependencies/openzeppelin/contracts/SafeCast.sol';
import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {GPv2SafeERC20} from '../../dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {Errors} from "../utils/Errors.sol";

library LibMToken {
    using SafeCast for uint256;
    using WadRayMath for uint256;
    using GPv2SafeERC20 for IERC20;

    bytes32 internal constant STORAGE_SLOT = keccak256("mToken.storage");

    bytes public constant EIP712_REVISION = bytes("1");
    bytes32 internal constant EIP712_DOMAIN = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant PERMIT_TYPEHASH = keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

    uint256 internal immutable _chainId;
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted during the transfer action
     * @param from The user whose tokens are being transferred
     * @param to The recipient
     * @param value The amount being transferred
     * @param index The next liquidity index of the reserve
     **/
    event BalanceTransfer(address indexed from, address indexed to, uint256 value, uint256 index);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

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

    modifier initializer(LayoutTypes.MTokenLayout storage s) {
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
        returns (LayoutTypes.ACLManagerLayout storage s)
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

    /**
     * @notice Initializes the MToken.
     **/
    function initializeMToken(
        LayoutTypes.MTokenLayout storage s,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address mariaDiamond,
        address treasury,
        address underlyingAsset
    ) internal initializer(s) {
        s._name = name;
        s._symbol = symbol;
        s._decimals = decimals;
        s._mariaDiamond = mariaDiamond;
        s._treasury = treasury;
        s._underlyingAsset = underlyingAsset;
        s._domainSeparator = _calculateDomainSeparator();
    }

    function RESERVE_TREASURY_ADDRESS(LayoutTypes.MTokenLayout storage s)
        internal
        view
        returns (address)
    {
        return s._treasury;
    }

    function UNDERLYING_ASSET_ADDRESS(LayoutTypes.MTokenLayout storage s)
        internal
        view
        returns (address)
    {
        return s._underlyingAsset;
    }

    function DOMAIN_SEPARATOR(LayoutTypes.MTokenLayout storage s) internal view returns (bytes32) {
        if(block.chainId === _chainId) {
            return s._domainSeparator;
        }
        return _calculateDomainSeparator();
    }

    function nonces(LayoutTypes.MTokenLayout storage s, address owner) internal view returns (uint256) {
        return s._nonces[owner];
    }

    function name(LayoutTypes.MTokenLayout storage s) internal view returns (string memory) {
        return s._name;
    }

    function symbol(LayoutTypes.MTokenLayout storage s) internal view returns (string memory) {
        return s._symbol;
    }

    function decimals(LayoutTypes.MTokenLayout storage s) internal view returns (uint8) {
        return s._decimals;
    }

    function balanceOf(LayoutTypes.MTokenLayout storage s, address user) internal view returns (uint256) {
        return s._userState[user].balance.rayMul(IPool(s._mariaDiamond).getReserveNormalizedIncome(s._underlyingAsset));
    }

    function totalSupply(LayoutTypes.MTokenLayout storage s) internal view returns (uint256) {
        uint256 currentScaledSupply = scaledTotalSupply(s);

        if (currentScaledSupply == 0) { return 0; }

        return currentScaledSupply.rayMul(IPool(s._mariaDiamond).getReserveNormalizedIncome(s._underlyingAsset));
    }

    function allowance(LayoutTypes.MTokenLayout storage s, address owner, address spender) internal view returns (uint256) {
        return s._allowances[owner][spender];
    }

    function approve(LayoutTypes.MTokenLayout storage s, address spender, uint256 amount) internal returns (bool) {
        _approve(s, Query._msgSender(), spender, amount);
        return true;
    }

    function scaledBalanceOf(LayoutTypes.MTokenLayout storage s, address user) internal view returns (uint256) {
        return s._userState[user].balance;
    }

    function scaledTotalSupply(LayoutTypes.MTokenLayout storage s) internal view returns (uint256) {
        return s._totalSupply;
    }

    function getScaledUserBalanceAndSupply(LayoutTypes.MTokenLayout storage s, address user) internal view returns (uint256, uint256) {
        return (scaledBalanceOf(s, user), scaledTotalSupply(s));
    }

    function getPreviousIndex(LayoutTypes.MTokenLayout storage s, address user) internal view returns (uint256) {
        return s._userState[user].additionalData;
    }

    function transfer(LayoutTypes.MTokenLayout storage s, address recipient, uint256 amount) internal returns (bool) {
        uint128 castAmount = amount.toUint128();
        _transfer(Query._msgSender(), recipient, castAmount);
        return true;
    }

    function transferFrom(
        LayoutTypes.MTokenLayout storage s,
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        uint128 castAmount = amount.toUint128();
        _approve(s, sender, Query._msgSender(), s._allowances[sender][Query._msgSender()] - castAmount);
        _transfer(s, sender, recipient, castAmount);
        return true;
    }

    function transferOnLiquidation(
        LayoutTypes.MTokenLayout storage s,
        address from,
        address to,
        uint256 value
    ) internal {
        _transfer(from, to, value, false);

        emit Transfer(from, to, value);
    }

    function transferUnderlyingTo(LayoutTypes.MTokenLayout storage s, address target, uint256 amount) internal {
        IERC20(s._underlyingAsset).safeTransfer(target, amount);
    }

    function increaseAllowance(LayoutTypes.MTokenLayout storage s, address spender, uint256 addedValue) internal returns (bool) {
        _approve(s, Query._msgSender(), spender, s._allowances[Query._msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(LayoutTypes.MTokenLayout storage s, address spender, uint256 subtractedValue) internal returns (bool) {
       _approve(s, Query._msgSender(), spender, s._allowances[Query._msgSender()][spender] + subtractedValue);
        return true;
    }

    function mint(
        LayoutTypes.MTokenLayout storage s,
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) internal returns (bool) {
        return _mintScaled(s, caller, onBehalfOf, amount, index);
    }

    function burn(
        LayoutTypes.MTokenLayout storage s,
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) internal {
        _burnScaled(s, from, receiverOfUnderlying, amount, index);
        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    function mintToTreasury(
        LayoutTypes.MTokenLayout storage s,
        uint256 amount,
        uint256 index
    ) internal returns (bool) {
        return _mintScaled(s, s._mariaDiamond, s._treasury, amount, index);
    }

    function permit(
        LayoutTypes.MTokenLayout storage s,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        require(owner != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
        //solium-disable-next-line
        require(block.timestamp <= deadline, Errors.INVALID_EXPIRATION);
        uint256 currentValidNonce = s._nonces[owner];
        bytes32 digest = keccak256(
        abi.encodePacked(
            '\x19\x01',
            DOMAIN_SEPARATOR(s),
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
        )
        );
        require(owner == ecrecover(digest, v, r, s), Errors.INVALID_SIGNATURE);
        s._nonces[owner] = currentValidNonce + 1;
        _approve(s, owner, spender, value);
    }

    function rescueTokens(
        LayoutTypes.MTokenLayout storage s,
        address token,
        address to,
        uint256 amount
    ) internal {
        require(token != s._underlyingAsset, Errors.UNDERLYING_CANNOT_BE_RESCUED);
        IERC20(token).safeTransfer(to, amount);
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
     * @notice Approve `spender` to use `amount` of `owner`s balance
     * @param owner The address owning the tokens
     * @param spender The address approved for spending
     * @param amount The amount of tokens to approve spending of
     */
    function _approve(
        LayoutTypes.MTokenLayout storage s,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        s._allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @notice Transfers the aTokens between two users. Validates the transfer
     * (ie checks for valid HF after the transfer) if required
     * @param from The source address
     * @param to The destination address
     * @param amount The amount getting transferred
     * @param validate True if the transfer needs to be validated, false otherwise
     **/
    function _transfer(
        LayoutTypes.MTokenLayout storage s,
        address from,
        address to,
        uint256 amount,
        bool validate
    ) internal {
        address underlyingAsset = s._underlyingAsset;

        uint256 index = IPool(s._mariaDiamond).getReserveNormalizedIncome(underlyingAsset);

        uint256 fromBalanceBefore = scaledBalanceOf(from).rayMul(index);
        uint256 toBalanceBefore = scaledBalanceOf(to).rayMul(index);

        _transfer(s, from, to, amount.rayDiv(index).toUint128());

        emit BalanceTransfer(from, to, amount, index);
    }

    /**
     * @notice Transfers tokens between two users and apply incentives if defined.
     * @param sender The source address
     * @param recipient The destination address
     * @param amount The amount getting transferred
     */
    function _transfer(
        LayoutTypes.MTokenLayout storage s,
        address sender,
        address recipient,
        uint128 amount
    ) internal {
        uint128 oldSenderBalance = s._userState[sender].balance;
        s._userState[sender].balance = oldSenderBalance - amount;
        uint128 oldRecipientBalance = s._userState[recipient].balance;
        s._userState[recipient].balance = oldRecipientBalance + amount;

        emit Transfer(sender, recipient, amount);
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
        LayoutTypes.MTokenLayout storage s,
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) internal returns (bool) {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_MINT_AMOUNT);

        uint256 scaledBalance = scaledBalanceOf(s, onBehalfOf);
        uint256 balanceIncrease = scaledBalance.rayMul(index) -
        scaledBalance.rayMul(s._userState[onBehalfOf].additionalData);

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
        LayoutTypes.MTokenLayout storage s,
        address user,
        address target,
        uint256 amount,
        uint256 index
    ) internal {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_BURN_AMOUNT);

        uint256 scaledBalance = scaledBalanceOf(user);
        uint256 balanceIncrease = scaledBalance.rayMul(index) -
        scaledBalance.rayMul(s._userState[user].additionalData);

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
    function _mint(LayoutTypes.MTokenLayout storage s, address account, uint128 amount) internal {
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
    function _burn(LayoutTypes.MTokenLayout storage s, address account, uint128 amount) internal {
        uint256 oldTotalSupply = s._totalSupply;
        s._totalSupply = oldTotalSupply - amount;

        uint128 oldAccountBalance = s._userState[account].balance;
        s._userState[account].balance = oldAccountBalance - amount;
    }

}
