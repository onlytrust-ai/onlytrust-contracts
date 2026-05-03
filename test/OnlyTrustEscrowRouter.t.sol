// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/OnlyTrustEscrowRouter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract OnlyTrustEscrowRouterTest is Test {
    OnlyTrustEscrowRouter public router;
    MockUSDC public usdc;

    address public owner = address(1);
    uint256 public signerPk = 0xA11CE;
    address public signer;
    address public depositor = address(3);
    address public beneficiary = address(4);
    address public feeRecipient = address(5);

    bytes32 constant SETTLEMENT_TYPEHASH =
        keccak256("SettlementClaim(bytes32 taskId,uint256 amount,address recipient,uint256 nonce,uint256 deadline)");
    bytes32 constant REFUND_TYPEHASH =
        keccak256("RefundClaim(bytes32 taskId,uint256 amount,address recipient,uint256 nonce,uint256 deadline)");

    bytes32 public taskId = keccak256("task-1");
    uint256 public amount = 1000e6; // 1000 USDC
    uint256 public deadline;

    function setUp() public {
        signer = vm.addr(signerPk);
        deadline = block.timestamp + 1 days;

        vm.prank(owner);
        router = new OnlyTrustEscrowRouter(signer, owner, feeRecipient);

        usdc = new MockUSDC();
        usdc.mint(depositor, 10_000e6);

        vm.prank(depositor);
        usdc.approve(address(router), type(uint256).max);
    }

    // --- Helpers ---

    function _signSettlement(
        bytes32 _taskId,
        uint256 _amount,
        address _recipient,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (bytes memory) {
        bytes32 structHash =
            keccak256(abi.encode(SETTLEMENT_TYPEHASH, _taskId, _amount, _recipient, _nonce, _deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(router.getDomainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signRefund(
        bytes32 _taskId,
        uint256 _amount,
        address _recipient,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(REFUND_TYPEHASH, _taskId, _amount, _recipient, _nonce, _deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(router.getDomainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _deposit() internal {
        vm.prank(depositor);
        router.deposit(taskId, beneficiary, address(usdc), amount, deadline);
    }

    // ==================== DEPOSIT TESTS ====================

    function test_deposit_success() public {
        _deposit();

        (address dep, address ben, address tok, uint256 amt, uint256 dl, bool settled, bool refunded) =
            router.escrows(taskId);
        assertEq(dep, depositor);
        assertEq(ben, beneficiary);
        assertEq(tok, address(usdc));
        assertEq(amt, amount);
        assertEq(dl, deadline);
        assertFalse(settled);
        assertFalse(refunded);
        assertEq(usdc.balanceOf(address(router)), amount);
    }

    function test_deposit_emits_event() public {
        vm.expectEmit(true, true, false, true);
        emit IOnlyTrustEscrowRouter.Deposited(taskId, depositor, amount);
        _deposit();
    }

    function test_deposit_duplicate_reverts() public {
        _deposit();
        vm.prank(depositor);
        vm.expectRevert("Escrow already exists");
        router.deposit(taskId, beneficiary, address(usdc), amount, deadline);
    }

    function test_deposit_zero_amount_reverts() public {
        vm.prank(depositor);
        vm.expectRevert("Amount must be > 0");
        router.deposit(taskId, beneficiary, address(usdc), 0, deadline);
    }

    function test_deposit_past_deadline_reverts() public {
        vm.prank(depositor);
        vm.expectRevert("Deadline must be in future");
        router.deposit(taskId, beneficiary, address(usdc), amount, block.timestamp - 1);
    }

    function test_deposit_zero_beneficiary_reverts() public {
        vm.prank(depositor);
        vm.expectRevert("Invalid beneficiary");
        router.deposit(taskId, address(0), address(usdc), amount, deadline);
    }

    function test_deposit_zero_token_reverts() public {
        vm.prank(depositor);
        vm.expectRevert("Invalid token");
        router.deposit(taskId, beneficiary, address(0), amount, deadline);
    }

    // ==================== CLAIM SETTLEMENT TESTS ====================

    function test_claimSettlement_success() public {
        _deposit();
        uint256 nonce = router.taskNonces(taskId);
        bytes memory sig = _signSettlement(taskId, amount, beneficiary, nonce, deadline);
        uint256 feeAmount = (amount * router.PLATFORM_FEE_BPS()) / 10_000;
        uint256 beneficiaryAmount = amount - feeAmount;

        vm.prank(beneficiary);
        router.claimSettlement(taskId, deadline, sig);

        (, , , , , bool settled, ) = router.escrows(taskId);
        assertTrue(settled);
        assertEq(usdc.balanceOf(beneficiary), beneficiaryAmount);
        assertEq(usdc.balanceOf(feeRecipient), feeAmount);
        assertEq(usdc.balanceOf(address(router)), 0);
    }

    function test_claimSettlement_emits_event() public {
        _deposit();
        bytes memory sig = _signSettlement(taskId, amount, beneficiary, 0, deadline);
        uint256 feeAmount = (amount * router.PLATFORM_FEE_BPS()) / 10_000;
        uint256 beneficiaryAmount = amount - feeAmount;

        vm.expectEmit(true, true, false, true);
        emit IOnlyTrustEscrowRouter.Settled(taskId, beneficiary, beneficiaryAmount);
        vm.expectEmit(true, true, false, true);
        emit IOnlyTrustEscrowRouter.SplitSettled(taskId, beneficiary, beneficiaryAmount, feeAmount);

        vm.prank(beneficiary);
        router.claimSettlement(taskId, deadline, sig);
    }

    function test_claimSettlement_invalid_sig_reverts() public {
        _deposit();
        bytes memory fakeSig = _signSettlement(taskId, amount, beneficiary, 0, deadline);
        fakeSig[0] = bytes1(uint8(fakeSig[0]) ^ 0xFF);

        vm.prank(beneficiary);
        vm.expectRevert("Invalid signature");
        router.claimSettlement(taskId, deadline, fakeSig);
    }

    function test_claimSettlement_already_settled_reverts() public {
        _deposit();
        bytes memory sig = _signSettlement(taskId, amount, beneficiary, 0, deadline);
        vm.prank(beneficiary);
        router.claimSettlement(taskId, deadline, sig);

        vm.prank(beneficiary);
        vm.expectRevert("Already settled");
        router.claimSettlement(taskId, deadline, sig);
    }

    function test_claimSettlement_wrong_recipient_reverts() public {
        _deposit();
        address wrongRecipient = address(99);
        bytes memory sig = _signSettlement(taskId, amount, wrongRecipient, 0, deadline);

        vm.prank(wrongRecipient);
        vm.expectRevert("Invalid signature");
        router.claimSettlement(taskId, deadline, sig);
    }

    function test_claimSettlement_expired_deadline_reverts() public {
        _deposit();
        uint256 expiredDeadline = block.timestamp - 1;
        bytes memory sig = _signSettlement(taskId, amount, beneficiary, 0, expiredDeadline);

        vm.prank(beneficiary);
        vm.expectRevert("Signature expired");
        router.claimSettlement(taskId, expiredDeadline, sig);
    }

    function test_claimSettlement_nonce_increments() public {
        _deposit();
        assertEq(router.taskNonces(taskId), 0);

        bytes memory sig = _signSettlement(taskId, amount, beneficiary, 0, deadline);
        vm.prank(beneficiary);
        router.claimSettlement(taskId, deadline, sig);

        assertEq(router.taskNonces(taskId), 1);
    }

    function test_claimSettlement_nonexistent_task_reverts() public {
        bytes32 fakeTask = keccak256("nonexistent");
        bytes memory sig = _signSettlement(fakeTask, amount, beneficiary, 0, deadline);

        vm.prank(beneficiary);
        vm.expectRevert("Escrow not found");
        router.claimSettlement(fakeTask, deadline, sig);
    }

    // ==================== REFUND TESTS ====================

    function test_refund_success() public {
        _deposit();
        uint256 balBefore = usdc.balanceOf(depositor);
        bytes memory sig = _signRefund(taskId, amount, depositor, 0, deadline);

        vm.prank(depositor);
        router.refund(taskId, deadline, sig);

        (, , , , , , bool refunded) = router.escrows(taskId);
        assertTrue(refunded);
        assertEq(usdc.balanceOf(depositor), balBefore + amount);
    }

    function test_refund_emits_event() public {
        _deposit();
        bytes memory sig = _signRefund(taskId, amount, depositor, 0, deadline);

        vm.expectEmit(true, true, false, true);
        emit IOnlyTrustEscrowRouter.Refunded(taskId, depositor, amount);

        vm.prank(depositor);
        router.refund(taskId, deadline, sig);
    }

    function test_refund_already_settled_reverts() public {
        _deposit();
        bytes memory claimSig = _signSettlement(taskId, amount, beneficiary, 0, deadline);
        vm.prank(beneficiary);
        router.claimSettlement(taskId, deadline, claimSig);

        bytes memory refundSig = _signRefund(taskId, amount, depositor, 1, deadline);
        vm.prank(depositor);
        vm.expectRevert("Already settled");
        router.refund(taskId, deadline, refundSig);
    }

    function test_refund_already_refunded_reverts() public {
        _deposit();
        bytes memory sig = _signRefund(taskId, amount, depositor, 0, deadline);
        vm.prank(depositor);
        router.refund(taskId, deadline, sig);

        vm.prank(depositor);
        vm.expectRevert("Already refunded");
        router.refund(taskId, deadline, sig);
    }

    function test_refund_expired_deadline_reverts() public {
        _deposit();
        uint256 expiredDeadline = block.timestamp - 1;
        bytes memory sig = _signRefund(taskId, amount, depositor, 0, expiredDeadline);

        vm.prank(depositor);
        vm.expectRevert("Signature expired");
        router.refund(taskId, expiredDeadline, sig);
    }

    function test_refund_invalid_sig_reverts() public {
        _deposit();
        bytes memory sig = _signRefund(taskId, amount, depositor, 0, deadline);
        sig[0] = bytes1(uint8(sig[0]) ^ 0xFF);

        vm.prank(depositor);
        vm.expectRevert("Invalid signature");
        router.refund(taskId, deadline, sig);
    }

    function test_refund_nonexistent_task_reverts() public {
        bytes32 fakeTask = keccak256("nonexistent");
        bytes memory sig = _signRefund(fakeTask, amount, depositor, 0, deadline);

        vm.prank(depositor);
        vm.expectRevert("Escrow not found");
        router.refund(fakeTask, deadline, sig);
    }

    // ==================== EIP-712 TESTS ====================

    function test_eip712_wrong_signer() public {
        _deposit();
        uint256 wrongPk = 0xBAD;
        bytes32 structHash =
            keccak256(abi.encode(SETTLEMENT_TYPEHASH, taskId, amount, beneficiary, uint256(0), deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(router.getDomainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(beneficiary);
        vm.expectRevert("Invalid signature");
        router.claimSettlement(taskId, deadline, sig);
    }

    // ==================== TIMELOCK TESTS ====================

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

    function test_cancelSignerRotation() public {
        address newSigner = address(5);
        vm.startPrank(owner);
        router.initiateSignerRotation(newSigner);
        router.cancelSignerRotation();
        vm.stopPrank();
        assertEq(router.pendingSigner(), address(0));
    }

    // ==================== PAUSABLE TESTS ====================

    function test_deposit_when_paused_reverts() public {
        vm.prank(owner);
        router.pause();

        vm.prank(depositor);
        vm.expectRevert();
        router.deposit(taskId, beneficiary, address(usdc), amount, deadline);
    }

    function test_claimSettlement_when_paused_reverts() public {
        _deposit();
        bytes memory sig = _signSettlement(taskId, amount, beneficiary, 0, deadline);

        vm.prank(owner);
        router.pause();

        vm.prank(beneficiary);
        vm.expectRevert();
        router.claimSettlement(taskId, deadline, sig);
    }

    function test_refund_when_paused_reverts() public {
        _deposit();
        bytes memory sig = _signRefund(taskId, amount, depositor, 0, deadline);

        vm.prank(owner);
        router.pause();

        vm.prank(depositor);
        vm.expectRevert();
        router.refund(taskId, deadline, sig);
    }

    // ==================== EDGE CASES ====================

    function test_deposit_insufficient_balance_reverts() public {
        address poorUser = address(99);
        usdc.mint(poorUser, 1e6);
        vm.startPrank(poorUser);
        usdc.approve(address(router), type(uint256).max);
        vm.expectRevert();
        router.deposit(keccak256("poor-task"), beneficiary, address(usdc), 1000e6, deadline);
        vm.stopPrank();
    }

    // ==================== FEE RECIPIENT TESTS ====================

    function test_settlement_fee_goes_to_feeRecipient_not_owner() public {
        _deposit();
        uint256 ownerBalBefore = usdc.balanceOf(owner);
        uint256 feeRecipientBalBefore = usdc.balanceOf(feeRecipient);
        bytes memory sig = _signSettlement(taskId, amount, beneficiary, 0, deadline);

        vm.prank(beneficiary);
        router.claimSettlement(taskId, deadline, sig);

        uint256 fee = (amount * 100) / 10_000;
        uint256 payout = amount - fee;

        assertEq(usdc.balanceOf(beneficiary), payout, "Provider gets amount minus fee");
        assertEq(usdc.balanceOf(feeRecipient), feeRecipientBalBefore + fee, "Fee recipient gets the fee");
        assertEq(usdc.balanceOf(owner), ownerBalBefore, "Owner balance unchanged");
        assertEq(usdc.balanceOf(address(router)), 0, "Contract holds nothing");
    }

    function test_settlement_zero_fee_for_dust_amount() public {
        // Deposit 1 micro-USDC: fee = 1 * 100 / 10_000 = 0
        uint256 dustAmount = 1;
        bytes32 dustTask = keccak256("dust-task");
        usdc.mint(depositor, dustAmount);
        vm.prank(depositor);
        router.deposit(dustTask, beneficiary, address(usdc), dustAmount, deadline);

        uint256 feeRecipientBalBefore = usdc.balanceOf(feeRecipient);
        bytes memory sig = _signSettlement(dustTask, dustAmount, beneficiary, 0, deadline);

        vm.prank(beneficiary);
        router.claimSettlement(dustTask, deadline, sig);

        assertEq(usdc.balanceOf(beneficiary), dustAmount, "Provider gets full dust amount");
        assertEq(usdc.balanceOf(feeRecipient), feeRecipientBalBefore, "Fee recipient gets nothing for dust");
    }

    function test_setFeeRecipient_by_owner() public {
        address newRecipient = makeAddr("newRecipient");
        vm.prank(owner);
        router.setFeeRecipient(newRecipient);
        assertEq(router.feeRecipient(), newRecipient);
    }

    function test_setFeeRecipient_emits_event() public {
        address newRecipient = makeAddr("newRecipient");
        vm.expectEmit(true, true, false, false);
        emit OnlyTrustEscrowRouter.FeeRecipientUpdated(feeRecipient, newRecipient);
        vm.prank(owner);
        router.setFeeRecipient(newRecipient);
    }

    function test_setFeeRecipient_reverts_for_non_owner() public {
        address randomUser = address(88);
        vm.prank(randomUser);
        vm.expectRevert();
        router.setFeeRecipient(randomUser);
    }

    function test_setFeeRecipient_reverts_for_zero_address() public {
        vm.prank(owner);
        vm.expectRevert("fee recipient cannot be zero");
        router.setFeeRecipient(address(0));
    }

    function test_constructor_reverts_for_zero_feeRecipient() public {
        vm.prank(owner);
        vm.expectRevert("fee recipient cannot be zero");
        new OnlyTrustEscrowRouter(signer, owner, address(0));
    }

    function test_constructor_reverts_for_zero_platformSigner() public {
        vm.prank(owner);
        vm.expectRevert("platform signer cannot be zero");
        new OnlyTrustEscrowRouter(address(0), owner, feeRecipient);
    }
}
