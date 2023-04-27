import { uint256 } from "./solidity-types";

export type PaymasterLimits = [
    maxPctRelayFee: uint256,
    maxBaseRelayFee: uint256,

    acceptanceBudgetOverhead: uint256,
    relayedCallOverhead: uint256,

    preRelayedCallGasLimit: uint256,
    postRelayedCallGasUsed: uint256,

    calldataSizeLimit: uint256,

    gasLimitEpsilon: uint256
];