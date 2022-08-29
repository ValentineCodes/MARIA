// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LayoutTypes} from "../types/LayoutTypes.sol";
import {Query} from "../utils/Query.sol";
import {SafeCast} from '../../dependencies/openzeppelin/contracts/SafeCast.sol';
import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {GPv2SafeERC20} from '../../dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {Context} from "../../dependencies/openzeppelin/contracts/Context.sol";
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
   * @dev Emitted when the allowance of a `spender` for an `owner` is set by
   * a call to {approve}. `value` is the new allowance.
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);

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
        address mariaDiamond,
        address treasury,
        address underlyingAsset
    ) internal initializer(s) {
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
        _approve(s, Context._msgSender(), spender, amount);
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

    function transferUnderlyingTo(LayoutTypes.MTokenLayout storage s, address target, uint256 amount) internal {
        IERC20(s._underlyingAsset).safeTransfer(target, amount);
    }

    function increaseAllowance(LayoutTypes.MTokenLayout storage s, address spender, uint256 addedValue) internal returns (bool) {
        _approve(s, Context._msgSender(), spender, s._allowances[Context._msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(LayoutTypes.MTokenLayout storage s, address spender, uint256 subtractedValue) internal returns (bool) {
       _approve(s, Context._msgSender(), spender, s._allowances[Context._msgSender()][spender] + subtractedValue);
        return true;
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


}
