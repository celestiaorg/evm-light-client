// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <8.0.0;
pragma experimental ABIEncoderV2;

/// @notice Remote chain block header.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#header
struct Header {
    uint64 height;
    uint64 timestamp;
    bytes32 lastBlockID;
    bytes32 lastCommitRoot;
    bytes32 consensusRoot;
    bytes32 stateCommitment;
    bytes32 availableDataRoot;
    bytes32 proposerAddress; // Note: this needs to be converted to a 20-byte address when used
}

/// @notice Compact ECDSA signature.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#signature
struct Signature {
    bytes32 r;
    bytes32 vs;
}

/// @notice Tendermint signature.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#commitsig
struct CommitSig {
    uint8 blockIDFlag;
    bytes32 validatorAddress; // Note: this needs to be converted to a 20-byte address when used
    uint64 timestamp;
    Signature signature;
}

/// @notice Tendermint commit (list of signatures).
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#commit
struct Commit {
    uint64 height;
    uint64 round;
    uint64 blockID;
    uint8 signaturesCount;
    CommitSig[] signatures;
}

/// @notice Bare minimim block data. Only contains the block header and commit.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#block
struct LightBlock {
    Header header;
    Commit lastCommit;
}

/// @notice Basic packed encoding serializer.
/// Uses abi.encodePacked format: https://solidity.readthedocs.io/en/v0.6.12/abi-spec.html#non-standard-packed-mode
library Serializer {
    using Serializer for Header;
    using Serializer for Signature;
    using Serializer for CommitSig;
    using Serializer for Commit;
    using Serializer for LightBlock;

    // Each CommitSig is 105 bytes
    uint256 constant COMMIT_SIG_BYTES = 105;

    function serialize(Header memory obj) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                obj.height,
                obj.timestamp,
                obj.lastBlockID,
                obj.lastCommitRoot,
                obj.consensusRoot,
                obj.stateCommitment,
                obj.availableDataRoot,
                obj.proposerAddress
            );
    }

    function serialize(Signature memory obj) internal pure returns (bytes memory) {
        return abi.encodePacked(obj.r, obj.vs);
    }

    function serialize(CommitSig memory obj) internal pure returns (bytes memory) {
        return abi.encodePacked(obj.blockIDFlag, obj.validatorAddress, obj.timestamp, obj.signature.serialize());
    }

    function serialize(Commit memory obj) internal pure returns (bytes memory) {
        require(obj.signaturesCount == obj.signatures.length);

        bytes memory sigs = new bytes(COMMIT_SIG_BYTES * obj.signaturesCount);
        for (uint8 i = 0; i < obj.signaturesCount; i++) {
            bytes memory packed = abi.encodePacked(obj.signatures[i].serialize());
            for (uint8 j = 0; j < COMMIT_SIG_BYTES; j++) {
                sigs[i * COMMIT_SIG_BYTES + j] = packed[j];
            }
        }

        return abi.encodePacked(obj.height, obj.round, obj.blockID, obj.signaturesCount, sigs);
    }

    function serialize(LightBlock memory obj) internal pure returns (bytes memory) {
        return abi.encodePacked(obj.header.serialize(), obj.lastCommit.serialize());
    }
}
