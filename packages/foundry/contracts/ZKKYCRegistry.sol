// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ZKKYCRegistry
 * @notice Zero-Knowledge KYC attestation registry for HashKey Chain
 * @dev Enables privacy-preserving KYC compliance verification.
 *      Users can prove KYC status via ZK proofs without revealing identity data.
 *      Designed to integrate with HashKey Chain's native KYC infrastructure.
 *
 * Architecture:
 *   1. KYC providers submit Poseidon hash commitments of attestations
 *   2. Users generate ZK proofs of their KYC status client-side
 *   3. Smart contracts verify proofs on-chain without accessing personal data
 *   4. Nullifiers prevent double-registration while preserving anonymity
 */
contract ZKKYCRegistry is Ownable {

    /// @notice KYC attestation status levels
    enum KYCLevel {
        NONE,           // No KYC
        BASIC,          // Basic identity verification
        ENHANCED,       // Enhanced due diligence
        INSTITUTIONAL   // Institutional-grade verification
    }

    /// @notice On-chain KYC attestation record (privacy-preserving)
    struct Attestation {
        bytes32 identityCommitment;   // Poseidon hash of identity data
        KYCLevel level;               // Verification level
        uint256 issuedAt;             // Timestamp of issuance
        uint256 expiresAt;            // Expiration timestamp
        address issuer;               // KYC provider address
        bool revoked;                 // Revocation status
    }

    /// @notice Mapping of identity commitments to attestations
    mapping(bytes32 => Attestation) public attestations;

    /// @notice Mapping of nullifiers to prevent double-registration
    mapping(bytes32 => bool) public usedNullifiers;

    /// @notice Authorized KYC issuers (e.g., HashKey KYC providers)
    mapping(address => bool) public authorizedIssuers;

    /// @notice Merkle root of all valid identity commitments
    bytes32 public identityMerkleRoot;

    /// @notice Total number of registered identities
    uint256 public totalIdentities;

    // Events
    event IssuerAuthorized(address indexed issuer);
    event IssuerRevoked(address indexed issuer);
    event AttestationRegistered(bytes32 indexed identityCommitment, KYCLevel level, address indexed issuer);
    event AttestationRevoked(bytes32 indexed identityCommitment);
    event MerkleRootUpdated(bytes32 newRoot);
    event ZKKYCVerified(bytes32 indexed nullifier, KYCLevel level);

    constructor(address initialOwner) Ownable(initialOwner) {
        // Owner is automatically an authorized issuer
        authorizedIssuers[initialOwner] = true;
        emit IssuerAuthorized(initialOwner);
    }

    // ==================== Issuer Management ====================

    /// @notice Authorize a new KYC issuer
    function authorizeIssuer(address issuer) external onlyOwner {
        require(issuer != address(0), "Invalid issuer address");
        require(!authorizedIssuers[issuer], "Already authorized");
        authorizedIssuers[issuer] = true;
        emit IssuerAuthorized(issuer);
    }

    /// @notice Revoke an issuer's authorization
    function revokeIssuer(address issuer) external onlyOwner {
        require(authorizedIssuers[issuer], "Not an authorized issuer");
        authorizedIssuers[issuer] = false;
        emit IssuerRevoked(issuer);
    }

    // ==================== Attestation Management ====================

    /// @notice Register a new KYC attestation (privacy-preserving)
    /// @param identityCommitment Poseidon hash commitment of the user's identity
    /// @param level KYC verification level
    /// @param validityDuration How long the attestation is valid (in seconds)
    function registerAttestation(
        bytes32 identityCommitment,
        KYCLevel level,
        uint256 validityDuration
    ) external {
        require(authorizedIssuers[msg.sender], "Not an authorized issuer");
        require(identityCommitment != bytes32(0), "Invalid identity commitment");
        require(level != KYCLevel.NONE, "Invalid KYC level");
        require(validityDuration > 0, "Invalid validity duration");
        require(!attestations[identityCommitment].revoked, "Previously revoked");

        attestations[identityCommitment] = Attestation({
            identityCommitment: identityCommitment,
            level: level,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + validityDuration,
            issuer: msg.sender,
            revoked: false
        });

        totalIdentities++;

        emit AttestationRegistered(identityCommitment, level, msg.sender);
    }

    /// @notice Revoke a KYC attestation
    function revokeAttestation(bytes32 identityCommitment) external {
        Attestation storage att = attestations[identityCommitment];
        require(
            msg.sender == att.issuer || msg.sender == owner(),
            "Not authorized to revoke"
        );
        require(!att.revoked, "Already revoked");

        att.revoked = true;
        emit AttestationRevoked(identityCommitment);
    }

    // ==================== ZK Verification ====================

    /// @notice Verify a ZK-KYC proof (simplified for hackathon demo)
    /// @dev In production, this would verify an actual ZK proof via a Groth16/PLONK verifier
    /// @param nullifier Unique nullifier to prevent double-use
    /// @param identityCommitment The identity commitment being proven
    /// @param requiredLevel Minimum KYC level required
    function verifyZKKYC(
        bytes32 nullifier,
        bytes32 identityCommitment,
        KYCLevel requiredLevel
    ) external returns (bool) {
        require(!usedNullifiers[nullifier], "Nullifier already used");
        require(identityCommitment != bytes32(0), "Invalid identity commitment");

        Attestation storage att = attestations[identityCommitment];
        require(att.issuedAt > 0, "No attestation found");
        require(!att.revoked, "Attestation revoked");
        require(block.timestamp <= att.expiresAt, "Attestation expired");
        require(uint8(att.level) >= uint8(requiredLevel), "Insufficient KYC level");

        // Mark nullifier as used
        usedNullifiers[nullifier] = true;

        emit ZKKYCVerified(nullifier, att.level);
        return true;
    }

    /// @notice Check if an identity commitment has a valid attestation
    function isKYCValid(bytes32 identityCommitment, KYCLevel requiredLevel)
        external
        view
        returns (bool)
    {
        Attestation storage att = attestations[identityCommitment];
        if (att.issuedAt == 0) return false;
        if (att.revoked) return false;
        if (block.timestamp > att.expiresAt) return false;
        if (uint8(att.level) < uint8(requiredLevel)) return false;
        return true;
    }

    /// @notice Update the Merkle root of valid identity commitments
    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        identityMerkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    /// @notice Get attestation details
    function getAttestation(bytes32 identityCommitment)
        external
        view
        returns (Attestation memory)
    {
        return attestations[identityCommitment];
    }
}
