const Tendermint_ORU = artifacts.require("Tendermint_ORU");

contract("Tendermint_ORU", async (accounts) => {
  it("should deploy", async () => {
    const instance = await Tendermint_ORU.deployed();
  });

  it("should set constructor parameters", async () => {
    const instance = await Tendermint_ORU.deployed();

    const genesisHash = await instance._genesisHash.call();
    assert.equal(genesisHash, "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470");
    const genesisSubmissionHash = await instance._genesisSubmissionHash.call();
    assert.equal(genesisSubmissionHash, "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470");
    const bondSize = await instance._bondSize.call();
    assert.equal(bondSize, 0);
    const fraudTimeout = await instance._fraudTimeout.call();
    assert.equal(fraudTimeout, 0);
  });
});
