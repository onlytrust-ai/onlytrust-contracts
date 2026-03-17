// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IOnlyTrustManifestRegistry {
    event ManifestAnchored(bytes32 indexed manifestHash, address indexed agent, uint256 timestamp);
    event ManifestRevoked(bytes32 indexed manifestHash, address indexed agent);

    function publishManifest(bytes32 manifestHash) external;
    function revokeManifest(bytes32 manifestHash) external;
    function verifyManifest(bytes32 manifestHash) external view returns (bool active, address agent, uint256 timestamp);
}
