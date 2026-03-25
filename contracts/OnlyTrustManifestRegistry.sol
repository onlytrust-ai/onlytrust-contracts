// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IOnlyTrustManifestRegistry.sol";

contract OnlyTrustManifestRegistry is IOnlyTrustManifestRegistry, Ownable2Step {
    struct ManifestRecord {
        address agent;
        uint256 timestamp;
        bool active;
    }

    mapping(bytes32 => ManifestRecord) public manifests;

    constructor(address _owner) Ownable(_owner) {}

    function publishManifest(bytes32 manifestHash) external override {
        ManifestRecord storage record = manifests[manifestHash];
        require(record.agent == address(0), "Already published or revoked");
        manifests[manifestHash] = ManifestRecord({
            agent: msg.sender,
            timestamp: block.timestamp,
            active: true
        });
        emit ManifestAnchored(manifestHash, msg.sender, block.timestamp);
    }

    function revokeManifest(bytes32 manifestHash) external override {
        ManifestRecord storage record = manifests[manifestHash];
        require(record.agent == msg.sender, "Not manifest owner");
        require(record.active, "Already revoked");
        record.active = false;
        emit ManifestRevoked(manifestHash, msg.sender);
    }

    function verifyManifest(
        bytes32 manifestHash
    ) external view override returns (bool active, address agent, uint256 timestamp) {
        ManifestRecord storage record = manifests[manifestHash];
        return (record.active, record.agent, record.timestamp);
    }
}
