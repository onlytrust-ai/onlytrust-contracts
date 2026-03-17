// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/OnlyTrustEscrowRouter.sol";

contract OnlyTrustEscrowRouterTest is Test {
    OnlyTrustEscrowRouter public router;
    address public owner = address(1);
    address public signer = address(2);
    address public depositor = address(3);
    address public beneficiary = address(4);

    function setUp() public {
        vm.prank(owner);
        router = new OnlyTrustEscrowRouter(signer, owner);
    }

    function test_deployment() public view {
        assertEq(router.platformSigner(), signer);
        assertEq(router.owner(), owner);
    }

    function test_deposit_reverts_not_implemented() public {
        vm.prank(depositor);
        vm.expectRevert("Not implemented");
        router.deposit(bytes32(0), beneficiary, address(0), 100, block.timestamp + 1 days);
    }

    function test_claimSettlement_reverts_not_implemented() public {
        vm.prank(beneficiary);
        vm.expectRevert("Not implemented");
        router.claimSettlement(bytes32(0), "");
    }

    function test_refund_reverts_not_implemented() public {
        vm.prank(depositor);
        vm.expectRevert("Not implemented");
        router.refund(bytes32(0));
    }

    function test_splitSettlement_reverts_not_implemented() public {
        vm.prank(beneficiary);
        vm.expectRevert("Not implemented");
        router.splitSettlement(bytes32(0), 500, "");
    }

    function test_initiateSignerRotation() public {
        address newSigner = address(5);
        vm.prank(owner);
        router.initiateSignerRotation(newSigner);
        assertEq(router.pendingSigner(), newSigner);
    }

    function test_finalizeSignerRotation() public {
        address newSigner = address(5);
        vm.startPrank(owner);
        router.initiateSignerRotation(newSigner);
        vm.warp(block.timestamp + 24 hours);
        router.finalizeSignerRotation();
        vm.stopPrank();
        assertEq(router.platformSigner(), newSigner);
    }

    function test_finalizeSignerRotation_before_timelock() public {
        address newSigner = address(5);
        vm.startPrank(owner);
        router.initiateSignerRotation(newSigner);
        vm.expectRevert("Timelock not expired");
        router.finalizeSignerRotation();
        vm.stopPrank();
    }
}
