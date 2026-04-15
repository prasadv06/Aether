// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NullifierVerifier.sol";

/**
 * @title MockHonkVerifier
 * @notice Lightweight ZK verifier for HashKey Chain Testnet deployment
 * @dev The full HonkVerifier (~33KB) exceeds EIP-170 contract size limit (24KB).
 *      This simplified verifier implements the same IVerifier interface and can be
 *      swapped for the full verifier on chains that support EIP-7702 or higher limits.
 *
 *      For the hackathon demo, ZK proof generation still happens client-side using
 *      the real Noir circuit. This verifier accepts proofs after basic validation.
 *      In production, the full HonkVerifier would be deployed via CREATE2 + library
 *      linking on a chain that supports larger contracts.
 */
contract MockHonkVerifier is IVerifier {
    /// @notice Verify a ZK proof against public inputs
    /// @dev Performs basic structural validation. Full cryptographic verification
    ///      would use the HonkVerifier with BN254 pairing checks.
    /// @param proof The serialized proof bytes
    /// @param publicInputs The public inputs to verify against
    /// @return True if the proof structure is valid
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external pure override returns (bool) {
        // Require at least one public input (the nullifier)
        require(publicInputs.length > 0, "No public inputs");
        // Require non-empty proof bytes
        require(proof.length > 0, "Empty proof");
        // Basic structural check: proof must be at least 32 bytes
        require(proof.length >= 32, "Proof too short");

        return true;
    }
}
