import { ethers as ethersHh } from 'hardhat';
import { Contract, ContractFactory, Signer } from "ethers";
import { address, uint8 } from './solidity-types';

export async function deployGaslessErc20Token(
    _deployer: Signer,
    _admin: address,
    _minters: address[],
    _paymasters: address[],
    _name: string,
    _symbol: string,
    _decimals: uint8,
    _trustedForwarder: address
): Promise<Contract> {
    const factory: ContractFactory = await ethersHh.getContractFactory("GaslessErc20Token", _deployer);
    const contract: Contract = await factory.deploy();
    await contract.deployed();
    await contract.initialize(
        _admin,
        _minters,
        _paymasters,
        _name,
        _symbol,
        _decimals,
        _trustedForwarder
    );
    return contract;
}
