import { ethers as ethersHh } from 'hardhat';

// Blockchain snapshot helpers:

export async function createBlockchainSnapshot(): Promise<number> {
    return ethersHh.provider.send('evm_snapshot', []);
}

export async function rollbackToBlockchainSnapshot(_snapshotId: number): Promise<void> {
    return ethersHh.provider.send('evm_revert', [_snapshotId]);
}