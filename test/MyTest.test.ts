import { expect } from 'chai';
import { BigNumber, Contract, Signer } from 'ethers';
import { ethers as ethersHh } from 'hardhat';
import { GsnTestEnvironment, TestEnvironment } from '@opengsn/dev';
import { RelayProvider } from '@opengsn/provider';
import { address, uint256, uint8 } from '../scripts/solidity-types';
import { Web3Provider } from '@ethersproject/providers';
import { parseEther, parseUnits } from 'ethers/lib/utils';
import { deployMyRecipient } from '../scripts/deploy-my-recipient';
import { deployGaslessErc20Token } from '../scripts/deploy-gasless-erc20-token';
import { PaymasterLimits } from '../scripts/my-paymaster-types';
import { deployMyPaymaster } from '../scripts/deploy-my-paymaster';
import { createBlockchainSnapshot, rollbackToBlockchainSnapshot } from './utils';

const Web3HttpProvider = require('web3-providers-http');

describe("MyTest", function () {
    let adminSigner: Signer;
    let adminAddress: address;

    let noEthUserAddress: address;

    let env: TestEnvironment;

    let forwarderAddress: address;
    let penalizerAddress: address;
    let relayHubAddress: address;
    let stakeManagerAddress: address;
    let versionRegistryAddress: address;

    let myRecipient: Contract;

    let token: Contract;
    const tokenName: string = "Gasless Token";
    const tokenSymbol: string = "GT";
    const tokenDecimals: uint8 = 18;
    const tokenMintAmount: BigNumber = parseUnits("100000000", tokenDecimals);

    let paymaster: Contract;

    let ethersProvider: Web3Provider;

    const maxBaseRelayFee: uint256 = 0;
    const maxPctRelayFee: uint256 = 0;
    const acceptanceBudgetOverhead: uint256 = 50_000;
    const relayedCallOverhead: uint256 = 0;
    const preRelayedCallGasLimit: uint256 = 70_000;
    const postRelayedCallGasUsed: uint256 = 12_000;
    const calldataSizeLimit: uint256 = 10_500;
    const gasLimitEpsilon: uint256 = 0;

    before(async function () {
        [adminSigner] = await ethersHh.getSigners();
        adminAddress = await adminSigner.getAddress();

        env = await GsnTestEnvironment.startGsn('localhost');

        forwarderAddress = env.contractsDeployment.forwarderAddress;
        penalizerAddress = env.contractsDeployment.penalizerAddress;
        relayHubAddress = env.contractsDeployment.relayHubAddress;
        stakeManagerAddress = env.contractsDeployment.stakeManagerAddress;
        versionRegistryAddress = env.contractsDeployment.versionRegistryAddress;

        const web3provider = new Web3HttpProvider('http://127.0.0.1:8545');

        myRecipient = await deployMyRecipient(adminSigner, forwarderAddress);

        token = await deployGaslessErc20Token(
            adminSigner,
            adminAddress,
            [],
            [],
            tokenName,
            tokenSymbol,
            tokenDecimals,
            forwarderAddress
        );

        const limits: PaymasterLimits = [
            maxBaseRelayFee,
            maxPctRelayFee,
            acceptanceBudgetOverhead,
            relayedCallOverhead,
            preRelayedCallGasLimit,
            postRelayedCallGasUsed,
            calldataSizeLimit,
            gasLimitEpsilon
        ];

        paymaster = await deployMyPaymaster(
            adminSigner,
            adminAddress,
            relayHubAddress,
            forwarderAddress,
            token.address,
            limits
        );

        const PAYMASTER_ROLE: string = await token.PAYMASTER_ROLE();
        await expect(token.connect(adminSigner).grantRole(PAYMASTER_ROLE, paymaster.address)).not.to.be.reverted;

        const relayHub: Contract = await ethersHh.getContractAt("IRelayHub", relayHubAddress);
        const depositAmount: BigNumber = parseEther("2");
        await expect(relayHub.connect(adminSigner).depositFor(paymaster.address, {value: depositAmount.toString()})).not.to.be.reverted;
        expect(await relayHub.balanceOf(paymaster.address)).to.be.equal(depositAmount.toString());

        const providerConfig = await {
            //loggerConfiguration: { logLevel: 'error'},
            paymasterAddress: paymaster.address,
            auditorsCount: 0
        }

        let gsnProvider = RelayProvider.newProvider({provider: web3provider, config: providerConfig});
        await gsnProvider.init();

        noEthUserAddress = gsnProvider.newAccount().address;
        console.log("noEthUserAddress:", noEthUserAddress);

        ethersProvider = new ethersHh.providers.Web3Provider(gsnProvider);

        expect(await ethersHh.provider.getBalance(noEthUserAddress)).to.be.equal(0);
        await expect(token.connect(adminSigner).mint(noEthUserAddress, tokenMintAmount)).not.to.be.reverted;
        expect(await token.balanceOf(noEthUserAddress)).to.be.equal(tokenMintAmount);
    });

    describe("GSN relayed transactions", function () {
        it("test 1", async function () {
            const snapshotId: number = await createBlockchainSnapshot();

            await expect(paymaster.connect(adminSigner).setRelayedCallOverhead(105_000)).not.to.be.reverted;
            //await expect(paymaster.connect(adminSigner).setRelayedCallOverhead(0)).not.to.be.reverted;

            await expect(myRecipient.connect(ethersProvider.getSigner(noEthUserAddress)).heavyFunc(2000)).not.to.be.reverted;

            await rollbackToBlockchainSnapshot(snapshotId);
        });
    });
});