// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IOnlyTrustEscrowRouter {
    struct EscrowSlot {
        bytes32 taskId;
        address depositor;
        address beneficiary;
        address token;
        uint256 amount;
        uint256 deadline;
        bool settled;
    }

    event Deposited(bytes32 indexed taskId, address indexed depositor, uint256 amount);
    event Settled(bytes32 indexed taskId, address indexed beneficiary, uint256 amount);
    event Refunded(bytes32 indexed taskId, address indexed depositor, uint256 amount);
    event SplitSettled(bytes32 indexed taskId, address indexed beneficiary, uint256 beneficiaryAmount, uint256 feeAmount);
    event SignerRotationInitiated(address indexed newSigner, uint256 effectiveAt);
    event SignerRotationFinalized(address indexed newSigner);

    function deposit(bytes32 taskId, address beneficiary, address token, uint256 amount, uint256 deadline) external;
    function claimSettlement(bytes32 taskId, bytes calldata signature) external;
    function refund(bytes32 taskId) external;
    function splitSettlement(bytes32 taskId, uint256 feePercentBps, bytes calldata signature) external;
}
