## Setup
Install dependencies.
```bash
yarn
```
## Run tests locally
1. Run Hardhat Network in a standalone fashion. Open terminal and type:
```bash
npx hardhat node
```
2. Run tests. Open another terminal and type:
```bash
npx hardhat test --network localhost
```
## The issue
The `MyPaymaster` contract includes a magic gas limit overhead called `relayedCallOverhead_`.
The test sets the overhead value to `105_000` to ensure proper function execution.
If you uncomment the line of code that is commented out in `test 1` of `test/MyTest.test.ts`, you will see how the transaction fails to execute.
