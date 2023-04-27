// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";

contract GaslessErc20Token is ERC20Upgradeable, AccessControlUpgradeable, BaseRelayRecipient {
    using SafeERC20 for IERC20;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAYMASTER_ROLE = keccak256("PAYMASTER_ROLE");

    uint8 private decimals_;

    function initialize(
        address _admin,
        address[] memory _minters,
        address[] memory _paymasters,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _trustedForwarder
    ) external initializer {
        __ERC20_init(_name, _symbol);

        require(_admin != address(0), "Zero admin address");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);

        for (uint16 i = 0; i < _minters.length; ++i) {
            _grantRole(MINTER_ROLE, _minters[i]);
        }

        for (uint16 i = 0; i < _paymasters.length; ++i) {
            _grantRole(PAYMASTER_ROLE, _paymasters[i]);
        }

        decimals_ = _decimals;

        _setTrustedForwarder(_trustedForwarder);
    }

    function decimals() public view virtual override returns (uint8) {
        return decimals_;
    }

    function allowance(address _owner, address _spender) public view virtual override returns (uint256) {
        if (_spender != address(0) && hasRole(PAYMASTER_ROLE, _spender)) {
            return type(uint256).max;
        }
        return super.allowance(_owner, _spender);
    }

    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal virtual override {
        if (_spender != address(0) && hasRole(PAYMASTER_ROLE, _spender)) {
            return;
        }
        super._spendAllowance(_owner, _spender, _amount);
    }

    function mint(address _account, uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mint(_account, _amount);
    }

    function _msgSender() internal view virtual override(ContextUpgradeable, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, BaseRelayRecipient) returns (bytes calldata) {
        return BaseRelayRecipient._msgData();
    }

    function versionRecipient() external view virtual override returns (string memory) {
        return "2.5.5";
    }
}