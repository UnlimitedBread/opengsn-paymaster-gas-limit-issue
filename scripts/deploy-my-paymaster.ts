import { ethers as ethersHh } from 'hardhat';
import { Contract, ContractFactory, Signer } from "ethers";
import { address } from './solidity-types';
import { PaymasterLimits } from './my-paymaster-types';

export async function deployMyPaymaster(
    _deployer: Signer,
    _admin: address,
    _relayHub: address,
    _trustedForwarder: address,
    _token: address,
    _limits: PaymasterLimits
): Promise<Contract> {
    const factory: ContractFactory = await ethersHh.getContractFactory("MyPaymaster", _deployer);
    const contract: Contract = await factory.deploy();
    await contract.initialize(
        _admin,
        _relayHub,
        _trustedForwarder,
        _token,
        _limits
    );
    return contract.deployed();
}