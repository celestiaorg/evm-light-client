const Tendermint_ORU = artifacts.require("Tendermint_ORU");

module.exports = function (deployer) {
  deployer.deploy(
    Tendermint_ORU,
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
    0,
    0
  );
};
