import { ethers as ethersHh } from 'hardhat';
import { Contract, ContractFactory, Signer } from "ethers";
import { address } from './solidity-types';

export async function deployMyRecipient(_deployer: Signer, _trustedForwarder: address): Promise<Contract> {
    const factory: ContractFactory = await ethersHh.getContractFactory("MyRecipient", _deployer);
    const contract: Contract = await factory.deploy(_trustedForwarder);
    return contract.deployed();
}