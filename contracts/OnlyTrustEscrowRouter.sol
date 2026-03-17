// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IOnlyTrustEscrowRouter.sol";

contract OnlyTrustEscrowRouter is
    IOnlyTrustEscrowRouter,
    ReentrancyGuard,
    Pausable,
    EIP712,
    Ownable2Step
{
    address public platformSigner;
    address public pendingSigner;
    uint256 public signerRotationEffectiveAt;
    uint256 public constant SIGNER_ROTATION_DELAY = 24 hours;

    mapping(bytes32 => EscrowSlot) public escrows;

    constructor(
        address _platformSigner,
        address _owner
    ) EIP712("OnlyTrustEscrow", "1") Ownable(_owner) {
        platformSigner = _platformSigner;
    }

    function deposit(
        bytes32 taskId,
        address beneficiary,
        address token,
        uint256 amount,
        uint256 deadline
    ) external override nonReentrant whenNotPaused {
        revert("Not implemented");
    }

    function claimSettlement(
        bytes32 taskId,
        bytes calldata signature
    ) external override nonReentrant whenNotPaused {
        revert("Not implemented");
    }

    function refund(
        bytes32 taskId
    ) external override nonReentrant whenNotPaused {
        revert("Not implemented");
    }

    function splitSettlement(
        bytes32 taskId,
        uint256 feePercentBps,
        bytes calldata signature
    ) external override nonReentrant whenNotPaused {
        revert("Not implemented");
    }

    // --- Signer Rotation (24h timelock) ---

    function initiateSignerRotation(address newSigner) external onlyOwner {
        require(newSigner != address(0), "Invalid signer");
        pendingSigner = newSigner;
        signerRotationEffectiveAt = block.timestamp + SIGNER_ROTATION_DELAY;
        emit SignerRotationInitiated(newSigner, signerRotationEffectiveAt);
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
}
