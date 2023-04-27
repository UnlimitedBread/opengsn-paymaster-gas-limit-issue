// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import "@opengsn/contracts/src/BaseRelayRecipient.sol";

contract MyRecipient is BaseRelayRecipient {
    mapping(address => uint256) public values_;
    mapping(address => uint256) public payableValues_;
    uint256 public storageValue_;

    constructor(address _trustedForwarder) {
        _setTrustedForwarder(_trustedForwarder);
    }

    function setValue(uint256 _value) external {
        require(_value != 10, "value 10 is forbidden");
        values_[_msgSender()] = _value;
    }

    function setValuePayable() external payable {
        payableValues_[_msgSender()] = msg.value;
    }

    function getValue(address _addr) external view returns (uint256) {
        return values_[_addr];
    }

    function emptyFunc() external {}

    function heavyFunc(uint256 _iterationsCount) external {
        uint256 x;
        for (uint256 i = 0; i < _iterationsCount; ++i) {
            x = storageValue_;
            storageValue_ = i;
        }
    }

    function versionRecipient() external view virtual override returns (string memory) {
        return "2.5.5";
    }
}