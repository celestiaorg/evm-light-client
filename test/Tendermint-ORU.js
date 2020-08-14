const truffleAssert = require("truffle-assertions");

const Tendermint_ORU = artifacts.require("Tendermint_ORU");

const ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";
const EMPTY_HASH = "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

contract("Tendermint_ORU", async (accounts) => {
  it("[constructor] should deploy", async () => {
    const instance = await Tendermint_ORU.deployed();
  });

  it("[constructor] should set constructor parameters", async () => {
    const instance = await Tendermint_ORU.deployed();

    const genesisHash = await instance._genesisHash.call();
    assert.equal(genesisHash, EMPTY_HASH);
    const genesisSubmissionHash = await instance._genesisSubmissionHash.call();
    assert.equal(genesisSubmissionHash, EMPTY_HASH);
    const bondSize = await instance._bondSize.call();
    assert.equal(bondSize, 0);
    const fraudTimeout = await instance._fraudTimeout.call();
    assert.equal(fraudTimeout, 0);
  });

  it("[submit] should submit", async () => {
    const instance = await Tendermint_ORU.deployed();

    await truffleAssert.passes(
      instance.submitBlock.call(
        {
          header: {
            height: 2,
            timestamp: 0,
            lastBlockID: EMPTY_HASH,
            lastCommitRoot: ZERO_HASH,
            consensusRoot: ZERO_HASH,
            stateCommitment: ZERO_HASH,
            availableDataRoot: ZERO_HASH,
            proposerAddress: ZERO_HASH,
          },
          lastCommit: {
            height: 1,
            round: 0,
            blockID: EMPTY_HASH,
            signatures: [],
          },
        },
        "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
      )
    );
  });
});
