// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IOnlyTrustEscrowRouter.sol";

contract OnlyTrustEscrowRouter is
    IOnlyTrustEscrowRouter,
    ReentrancyGuard,
    Pausable,
    EIP712,
    Ownable2Step
{
    using SafeERC20 for IERC20;

    // --- EIP-712 Type Hashes ---
    bytes32 public constant SETTLEMENT_TYPEHASH =
        keccak256("SettlementClaim(bytes32 taskId,uint256 amount,address recipient,uint256 nonce,uint256 deadline)");
    bytes32 public constant REFUND_TYPEHASH =
        keccak256("RefundClaim(bytes32 taskId,uint256 amount,address recipient,uint256 nonce,uint256 deadline)");
    uint256 public constant PLATFORM_FEE_BPS = 100;

    // --- State ---
    address public platformSigner;
    address public feeRecipient;
    address public pendingSigner;
    uint256 public signerRotationEffectiveAt;
    uint256 public constant SIGNER_ROTATION_DELAY = 24 hours;

    mapping(bytes32 => EscrowSlot) public escrows;
    mapping(bytes32 => uint256) public taskNonces;

    constructor(
        address _platformSigner,
        address _owner,
        address _feeRecipient
    ) EIP712("OnlyTrustEscrow", "1") Ownable(_owner) {
        require(_platformSigner != address(0), "platform signer cannot be zero");
        require(_feeRecipient != address(0), "fee recipient cannot be zero");
        platformSigner = _platformSigner;
        feeRecipient = _feeRecipient;
    }

    // --- Core Escrow Functions ---

    function deposit(
        bytes32 taskId,
        address beneficiary,
        address token,
        uint256 amount,
        uint256 deadline
    ) external override nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        require(deadline > block.timestamp, "Deadline must be in future");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(token != address(0), "Invalid token");
        require(escrows[taskId].amount == 0, "Escrow already exists");

        escrows[taskId] = EscrowSlot({
            depositor: msg.sender,
            beneficiary: beneficiary,
            token: token,
            amount: amount,
            deadline: deadline,
            settled: false,
            refunded: false
        });

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(taskId, msg.sender, amount);
    }

    function claimSettlement(
        bytes32 taskId,
        uint256 deadline,
        bytes calldata signature
    ) external override nonReentrant whenNotPaused {
        EscrowSlot storage slot = escrows[taskId];
        require(slot.amount > 0, "Escrow not found");
        require(!slot.settled, "Already settled");
        require(!slot.refunded, "Already refunded");

        // Verify EIP-712 signature from platform signer
        uint256 nonce = taskNonces[taskId];
        bytes32 structHash = keccak256(
            abi.encode(SETTLEMENT_TYPEHASH, taskId, slot.amount, slot.beneficiary, nonce, deadline)
        );
        _verifySignature(structHash, signature, deadline);

        // Execute settlement
        slot.settled = true;
        taskNonces[taskId] = nonce + 1;

        uint256 feeAmount = (slot.amount * PLATFORM_FEE_BPS) / 10_000;
        uint256 beneficiaryAmount = slot.amount - feeAmount;

        IERC20(slot.token).safeTransfer(slot.beneficiary, beneficiaryAmount);
        if (feeAmount > 0) {
            IERC20(slot.token).safeTransfer(feeRecipient, feeAmount);
        }

        emit Settled(taskId, slot.beneficiary, beneficiaryAmount);
        emit SplitSettled(taskId, slot.beneficiary, beneficiaryAmount, feeAmount);
    }

    function refund(
        bytes32 taskId,
        uint256 deadline,
        bytes calldata signature
    ) external override nonReentrant whenNotPaused {
        EscrowSlot storage slot = escrows[taskId];
        require(slot.amount > 0, "Escrow not found");
        require(!slot.settled, "Already settled");
        require(!slot.refunded, "Already refunded");

        // Verify EIP-712 signature from platform signer
        uint256 nonce = taskNonces[taskId];
        bytes32 structHash = keccak256(
            abi.encode(REFUND_TYPEHASH, taskId, slot.amount, slot.depositor, nonce, deadline)
        );
        _verifySignature(structHash, signature, deadline);

        // Execute refund
        slot.refunded = true;
        taskNonces[taskId] = nonce + 1;

        IERC20(slot.token).safeTransfer(slot.depositor, slot.amount);
        emit Refunded(taskId, slot.depositor, slot.amount);
    }

    function splitSettlement(
        bytes32,
        uint256 feePercentBps,
        bytes calldata
    ) external override nonReentrant whenNotPaused {
        require(feePercentBps <= 1000, "Max 10% fee");
        revert("Not implemented"); // V2
    }

    // --- Internal ---

    function _verifySignature(
        bytes32 structHash,
        bytes calldata signature,
        uint256 deadline
    ) internal view {
        require(block.timestamp <= deadline, "Signature expired");
        bytes32 digest = _hashTypedDataV4(structHash);
        (address recovered, ECDSA.RecoverError err, ) = ECDSA.tryRecover(digest, signature);
        require(err == ECDSA.RecoverError.NoError && recovered == platformSigner, "Invalid signature");
    }

    /// @notice Exposes the EIP-712 domain separator for off-chain signature construction
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    // --- Signer Rotation (24h timelock) ---

    event SignerRotationCancelled(address indexed cancelledSigner);

    function initiateSignerRotation(address newSigner) external onlyOwner {
        require(newSigner != address(0), "Invalid signer");
        require(pendingSigner == address(0), "Rotation already pending");
        pendingSigner = newSigner;
        signerRotationEffectiveAt = block.timestamp + SIGNER_ROTATION_DELAY;
        emit SignerRotationInitiated(newSigner, signerRotationEffectiveAt);
    }

    function cancelSignerRotation() external onlyOwner {
        require(pendingSigner != address(0), "No pending rotation");
        address cancelled = pendingSigner;
        pendingSigner = address(0);
        signerRotationEffectiveAt = 0;
        emit SignerRotationCancelled(cancelled);
    }

    function finalizeSignerRotation() external onlyOwner {
        require(pendingSigner != address(0), "No pending rotation");
        require(block.timestamp >= signerRotationEffectiveAt, "Timelock not expired");
        platformSigner = pendingSigner;
        pendingSigner = address(0);
        signerRotationEffectiveAt = 0;
        emit SignerRotationFinalized(platformSigner);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // --- Fee Recipient Management ---

    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0), "fee recipient cannot be zero");
        emit FeeRecipientUpdated(feeRecipient, _newFeeRecipient);
        feeRecipient = _newFeeRecipient;
    }
}
