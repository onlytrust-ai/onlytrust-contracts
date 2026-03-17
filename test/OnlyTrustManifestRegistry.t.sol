// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/OnlyTrustManifestRegistry.sol";

contract OnlyTrustManifestRegistryTest is Test {
    OnlyTrustManifestRegistry public registry;
    address public owner = address(1);
    address public agent = address(2);

    function setUp() public {
        vm.prank(owner);
        registry = new OnlyTrustManifestRegistry(owner);
    }

    function test_publishManifest() public {
        bytes32 hash = keccak256("test-manifest");
        vm.prank(agent);
        registry.publishManifest(hash);

        (bool active, address registeredAgent, uint256 timestamp) = registry.verifyManifest(hash);
        assertTrue(active);
        assertEq(registeredAgent, agent);
        assertGt(timestamp, 0);
    }

    function test_publishManifest_duplicate_reverts() public {
        bytes32 hash = keccak256("test-manifest");
        vm.prank(agent);
        registry.publishManifest(hash);

        vm.prank(agent);
        vm.expectRevert("Already published");
        registry.publishManifest(hash);
    }

    function test_revokeManifest() public {
        bytes32 hash = keccak256("test-manifest");
        vm.prank(agent);
        registry.publishManifest(hash);

        vm.prank(agent);
        registry.revokeManifest(hash);

        (bool active,,) = registry.verifyManifest(hash);
        assertFalse(active);
    }

    function test_revokeManifest_not_owner_reverts() public {
        bytes32 hash = keccak256("test-manifest");
        vm.prank(agent);
        registry.publishManifest(hash);

        vm.prank(address(99));
        vm.expectRevert("Not manifest owner");
        registry.revokeManifest(hash);
    }

    function test_verifyManifest_nonexistent() public view {
        bytes32 hash = keccak256("nonexistent");
        (bool active, address registeredAgent, uint256 timestamp) = registry.verifyManifest(hash);
        assertFalse(active);
        assertEq(registeredAgent, address(0));
        assertEq(timestamp, 0);
    }
}
