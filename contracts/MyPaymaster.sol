// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "@opengsn/contracts/src/utils/GsnTypes.sol";
import "@opengsn/contracts/src/interfaces/IPaymaster.sol";
import "@opengsn/contracts/src/interfaces/IRelayHub.sol";
import "@opengsn/contracts/src/utils/GsnEip712Library.sol";
import "@opengsn/contracts/src/forwarder/IForwarder.sol";

import "hardhat/console.sol";

/**
 * Abstract base class to be inherited by a concrete Paymaster
 * A subclass must implement:
 *  - preRelayedCall
 *  - postRelayedCall
 */
abstract contract BasePaymaster is IPaymaster, AccessControlUpgradeable {
    IRelayHub internal relayHub_;
    address private trustedForwarder_;

    // Modifier to be used by recipients as access control protection for preRelayedCall & postRelayedCall.
    modifier relayHubOnly() {
        require(msg.sender == getHubAddr(), "can only be called by RelayHub");
        _;
    }

    // Any money moved into the paymaster is transferred as a deposit.
    // This way, we don't need to understand the RelayHub API in order to replenish the paymaster.
    receive() external virtual payable {
        require(address(relayHub_) != address(0), "relay hub address not set");
        relayHub_.depositFor{value:msg.value}(address(this));
    }

    function getHubAddr() public override view returns (address) {
        return address(relayHub_);
    }

    // This method must be called from preRelayedCall to validate that the forwarder
    // is approved by the paymaster as well as by the recipient contract.
    function _verifyForwarder(GsnTypes.RelayRequest calldata _relayRequest) public view {
        require(address(trustedForwarder_) == _relayRequest.relayData.forwarder, "Forwarder is not trusted");
        GsnEip712Library.verifyForwarderTrusted(_relayRequest);
    }

    function setRelayHub(IRelayHub _relayHub) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRelayHub(_relayHub);
    }

    function _setRelayHub(IRelayHub _relayHub) internal {
        relayHub_ = _relayHub;
    }

    function setTrustedForwarder(address _trustedForwarder) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustedForwarder(_trustedForwarder);
    }

    function _setTrustedForwarder(address _trustedForwarder) internal {
        trustedForwarder_ = _trustedForwarder;
    }

    function trustedForwarder() public view virtual override returns (address) {
        return trustedForwarder_;
    }

    // Check current deposit on relay hub.
    function getRelayHubDeposit() public view virtual override returns (uint256) {
        return relayHub_.balanceOf(address(this));
    }

    // Withdraw deposit from relay hub.
    function withdrawRelayHubDepositTo(
        uint256 _amount,
        address payable _target
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        relayHub_.withdraw(_amount, _target);
    }
}

struct PaymasterLimits {
    uint256 maxBaseRelayFee;
    uint256 maxPctRelayFee;

    uint256 acceptanceBudgetOverhead;
    uint256 relayedCallOverhead;

    uint256 preRelayedCallGasLimit;
    uint256 postRelayedCallGasUsed;

    uint256 calldataSizeLimit;

    uint256 gasLimitEpsilon;
}

contract MyPaymaster is BasePaymaster {
    using SafeERC20 for IERC20;

    address public token_;

    uint256 public maxBaseRelayFee_; // wei
    uint256 public maxPctRelayFee_; // % of the cost of the gas for the transaction (in addition to being reimbursed for gas used)

    uint256 public acceptanceBudgetOverhead_; // Overhead of forwarder verify + signature, plus hub overhead.

    uint256 public relayedCallOverhead_; // Magic gas limit overhead for relayed call

    uint256 public preRelayedCallGasLimit_;
    uint256 public postRelayedCallGasUsed_;

    uint256 public calldataSizeLimit_;

    uint256 public gasLimitEpsilon_;

    function initialize(
        address _admin,
        address _relayHub,
        address _trustedForwarder,
        address _token,
        PaymasterLimits memory _limits
    ) external initializer {
        require(_admin != address(0), "Zero admin address");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        _setRelayHub(IRelayHub(_relayHub));
        _setTrustedForwarder(_trustedForwarder);

        require(_token != address(0), "Zero token address");
        token_ = _token;

        maxBaseRelayFee_ = _limits.maxBaseRelayFee;
        maxPctRelayFee_ = _limits.maxPctRelayFee;

        acceptanceBudgetOverhead_ = _limits.acceptanceBudgetOverhead;
        relayedCallOverhead_ = _limits.relayedCallOverhead;

        preRelayedCallGasLimit_ = _limits.preRelayedCallGasLimit;
        postRelayedCallGasUsed_ = _limits.postRelayedCallGasUsed;

        calldataSizeLimit_ = _limits.calldataSizeLimit;

        gasLimitEpsilon_ = _limits.gasLimitEpsilon;
    }

    function setMaxPctRelayFee(uint256 _maxPctRelayFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxPctRelayFee_ != _maxPctRelayFee, "Already done");
        maxPctRelayFee_ = _maxPctRelayFee;
    }

    function setMaxBaseRelayFee(uint256 _maxBaseRelayFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxBaseRelayFee_ != _maxBaseRelayFee, "Already done");
        maxBaseRelayFee_ = _maxBaseRelayFee;
    }

    function setAcceptanceBudgetOverhead(uint256 _acceptanceBudgetOverhead) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(acceptanceBudgetOverhead_ != _acceptanceBudgetOverhead, "Already done");
        acceptanceBudgetOverhead_ = _acceptanceBudgetOverhead;
    }

    function setRelayedCallOverhead(uint256 _relayedCallOverhead) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(relayedCallOverhead_ != _relayedCallOverhead, "Already done");
        relayedCallOverhead_ = _relayedCallOverhead;
    }

    function setPreRelayedCallGasLimit(uint256 _preRelayedCallGasLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(preRelayedCallGasLimit_ != _preRelayedCallGasLimit, "Already done");
        preRelayedCallGasLimit_ = _preRelayedCallGasLimit;
    }

    function setPostRelayedCallGasUsed(uint256 _postRelayedCallGasUsed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(postRelayedCallGasUsed_ != _postRelayedCallGasUsed, "Already done");
        postRelayedCallGasUsed_ = _postRelayedCallGasUsed;
    }

    function setCalldataSizeLimit(uint256 _calldataSizeLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(calldataSizeLimit_ != _calldataSizeLimit, "Already done");
        calldataSizeLimit_ = _calldataSizeLimit;
    }

    function setGasLimitEpsilon(uint256 _gasLimitEpsilon) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(gasLimitEpsilon_ != _gasLimitEpsilon, "Already done");
        gasLimitEpsilon_ = _gasLimitEpsilon;
    }

    function getGasAndDataLimits() public view virtual override returns (
        IPaymaster.GasAndDataLimits memory
    ) {
        return IPaymaster.GasAndDataLimits(
            preRelayedCallGasLimit_ + acceptanceBudgetOverhead_,
            preRelayedCallGasLimit_,
            postRelayedCallGasUsed_ + relayedCallOverhead_,
            calldataSizeLimit_
        );
    }

    function preRelayedCall(
        GsnTypes.RelayRequest calldata _relayRequest,
        bytes calldata _signature,
        bytes calldata _approvalData,
        uint256 _maxPossibleGas
    ) external relayHubOnly returns (
        bytes memory context,
        bool rejectOnRecipientRevert
    ) {
        (_signature);

        uint256 gas = gasleft();

        console.log("preRelayedCall maxPossibleGas:", _maxPossibleGas);

        _verifyForwarder(_relayRequest);
        _verifyRelayFee(_relayRequest);
        require(_approvalData.length == 0, "Invalid approval data length");

        uint256 tokenMaxChargeAmount = calculateTokenMaxCharge(_relayRequest, _maxPossibleGas);
        IERC20(token_).safeTransferFrom(_relayRequest.request.from, address(this), tokenMaxChargeAmount);

        context = abi.encode(
            _relayRequest.request.from,
            _maxPossibleGas,
            tokenMaxChargeAmount,
            postRelayedCallGasUsed_, // Read from storage here to reduce gas usage of {postRelayedCall}
            gasLimitEpsilon_ // Read from storage here to reduce gas usage of {postRelayedCall}
        );

        rejectOnRecipientRevert = true;

        gas -= gasleft();
        console.log("preRelayedCall gas used:", gas);
    }

    function _verifyRelayFee(GsnTypes.RelayRequest calldata _relayRequest) private view {
        require(_relayRequest.relayData.baseRelayFee <= maxBaseRelayFee_, "Base relay fee too big");
        require(_relayRequest.relayData.pctRelayFee <= maxPctRelayFee_, "Percent relay fee too big");
    }

    function calculateTokenMaxCharge(
        GsnTypes.RelayRequest calldata _relayRequest,
        uint256 _maxPossibleGas
    ) public view returns (uint256) {
        uint256 ethMaxCharge = relayHub_.calculateCharge(_maxPossibleGas, _relayRequest.relayData);
        ethMaxCharge += _relayRequest.request.value;

        return convertEthToToken(ethMaxCharge);
    }

    function convertEthToToken(uint256 _ethAmount) public pure returns (uint256) {
        return _ethAmount; // conversion rate is 1:1 for simplicity of this test
    }

    function postRelayedCall(
        bytes calldata _context,
        bool _success,
        uint256 _gasUseWithoutPost,
        GsnTypes.RelayData calldata _relayData
    ) external relayHubOnly {
        (_success);

        uint256 gas = gasleft();

        console.log("---");
        console.log("postRelayedCall gasUseWithoutPost:", _gasUseWithoutPost);

        (
            address from,
            uint256 maxPossibleGas,
            uint256 tokenMaxChargeAmount,
            uint256 postRelayedCallGasUsed,
            uint256 gasLimitEpsilon
        ) = abi.decode(_context, (address, uint256, uint256, uint256, uint256));

        uint256 totalGasUsed = _gasUseWithoutPost + postRelayedCallGasUsed;
        console.log("postRelayedCall totalGasUsed:", totalGasUsed);

        uint256 tokenActualCharge = tokenMaxChargeAmount;

        if (totalGasUsed < maxPossibleGas) {
            if (maxPossibleGas - totalGasUsed > gasLimitEpsilon) {
                tokenActualCharge = convertEthToToken(relayHub_.calculateCharge(totalGasUsed, _relayData));
                if (tokenMaxChargeAmount > tokenActualCharge) {
                    IERC20(token_).safeTransfer(from, tokenMaxChargeAmount - tokenActualCharge);
                }
            }
        }

        gas -= gasleft();
        console.log("postRelayedCall gas used:", gas);
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a <= _b ? _a : _b;
    }

    function versionPaymaster() external view virtual override returns (string memory) {
        return "2.5.5";
    }
}