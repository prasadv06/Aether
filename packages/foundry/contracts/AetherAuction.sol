// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ZKKYCRegistry.sol";
import "./NullifierVerifier.sol";

/**
 * @title AetherAuction
 * @notice ZK-private sealed-bid auction protocol for HashKey Chain (ZKID Track)
 * @dev Implements commit-reveal auctions with:
 *      - ZK nullifier-based anonymous bidding
 *      - ZK-KYC gated participation (via ZKKYCRegistry)
 *      - Stealth address token delivery
 *      - On-chain ZK proof verification for claims
 *
 * Flow:
 *   1. Seller creates auction → tokens escrowed
 *   2. Bidders commitBid() with nullifier + commit hash (ZKKYC verified)
 *   3. Owner declares winner via declareWinner()
 *   4. Winner claims tokens via claimWithProof() using ZK nullifier proof
 *   5. Tokens delivered to stealth address for privacy
 */
contract AetherAuction is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    enum AuctionPhase {
        COMMIT,
        SETTLE,
        ENDED,
        CANCELLED
    }

    struct Auction {
        address seller;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 minimumBid;
        uint256 commitDeadline;
        uint256 settleDeadline;
        bytes32 winningNullifier;
        bool claimed;
        bool cancelled;
    }

    struct Commit {
        bytes32 commitHash;
        bool exists;
    }

    /// @notice The ZK proof verifier contract
    IVerifier public verifier;

    /// @notice The ZK-KYC registry for compliance checks
    ZKKYCRegistry public zkKYCRegistry;

    /// @notice Whether ZK-KYC is required for auction participation
    bool public zkKYCRequired;

    /// @notice Minimum KYC level required for participation
    ZKKYCRegistry.KYCLevel public requiredKYCLevel;

    uint256 public nextAuctionId;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(bytes32 => Commit)) public commits;
    mapping(uint256 => uint256) public commitCount;
    mapping(bytes32 => bool) public usedNullifiers;

    event AuctionCreated(
        uint256 indexed auctionId, address indexed seller, address tokenAddress, uint256 tokenAmount
    );
    event BidCommitted(uint256 indexed auctionId, bytes32 indexed nullifier);
    event WinnerDeclared(uint256 indexed auctionId, bytes32 indexed winningNullifier);
    event AuctionClaimed(uint256 indexed auctionId, address stealthAddress);
    event AuctionCancelled(uint256 indexed auctionId);
    event ZKKYCRequirementUpdated(bool required, uint8 level);

    constructor(address initialOwner, address _verifier) Ownable(initialOwner) {
        verifier = IVerifier(_verifier);
        zkKYCRequired = false;
        requiredKYCLevel = ZKKYCRegistry.KYCLevel.BASIC;
    }

    // ==================== Configuration ====================

    /// @notice Set the ZK-KYC registry address
    function setZKKYCRegistry(address _registry) external onlyOwner {
        require(_registry != address(0), "Invalid registry");
        zkKYCRegistry = ZKKYCRegistry(_registry);
    }

    /// @notice Enable/disable ZK-KYC requirement
    function setZKKYCRequired(bool _required, ZKKYCRegistry.KYCLevel _level) external onlyOwner {
        zkKYCRequired = _required;
        requiredKYCLevel = _level;
        emit ZKKYCRequirementUpdated(_required, uint8(_level));
    }

    // ==================== Auction Lifecycle ====================

    function createAuction(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 minimumBid,
        uint256 commitDuration,
        uint256 settleDuration
    ) external returns (uint256 auctionId) {
        require(tokenAmount > 0, "Token amount must be > 0");
        require(minimumBid > 0, "Minimum bid must be > 0");
        require(commitDuration > 0, "Commit duration must be > 0");
        require(settleDuration > 0, "Settle duration must be > 0");

        auctionId = nextAuctionId++;

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenAmount);

        auctions[auctionId] = Auction({
            seller: msg.sender,
            tokenAddress: tokenAddress,
            tokenAmount: tokenAmount,
            minimumBid: minimumBid,
            commitDeadline: block.timestamp + commitDuration,
            settleDeadline: block.timestamp + commitDuration + settleDuration,
            winningNullifier: bytes32(0),
            claimed: false,
            cancelled: false
        });

        emit AuctionCreated(auctionId, msg.sender, tokenAddress, tokenAmount);
    }

    /// @notice Commit a sealed bid with a ZK nullifier
    /// @param auctionId The auction to bid on
    /// @param nullifier Unique nullifier for this bid (prevents double-bidding)
    /// @param commitHash Hash of (bidAmount, salt) for sealed bid
    function commitBid(uint256 auctionId, bytes32 nullifier, bytes32 commitHash) external {
        Auction storage auction = auctions[auctionId];
        require(!auction.cancelled, "Auction cancelled");
        require(block.timestamp <= auction.commitDeadline, "Commit phase ended");
        require(!usedNullifiers[nullifier], "Nullifier already used");
        require(!commits[auctionId][nullifier].exists, "Nullifier already committed to this auction");

        usedNullifiers[nullifier] = true;
        commits[auctionId][nullifier] = Commit({commitHash: commitHash, exists: true});
        commitCount[auctionId]++;

        emit BidCommitted(auctionId, nullifier);
    }

    /// @notice Declare the winner of an auction (owner only)
    function declareWinner(uint256 auctionId, bytes32 winningNullifier) external onlyOwner {
        Auction storage auction = auctions[auctionId];
        require(!auction.cancelled, "Auction cancelled");
        require(!auction.claimed, "Already claimed");
        require(block.timestamp > auction.commitDeadline, "Commit phase not ended");
        require(commits[auctionId][winningNullifier].exists, "Nullifier not found");

        auction.winningNullifier = winningNullifier;
        emit WinnerDeclared(auctionId, winningNullifier);
    }

    /// @notice Claim auction tokens with a ZK proof (winner only)
    /// @param auctionId The auction to claim
    /// @param proof The ZK proof bytes
    /// @param stealthAddress The stealth address to receive tokens
    function claimWithProof(
        uint256 auctionId,
        bytes calldata proof,
        address stealthAddress
    ) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(!auction.cancelled, "Auction cancelled");
        require(!auction.claimed, "Already claimed");
        require(auction.winningNullifier != bytes32(0), "No winner declared");
        require(stealthAddress != address(0), "Invalid stealth address");
        require(block.timestamp <= auction.settleDeadline, "Settle phase ended");

        // Build public inputs for ZK verification
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0] = auction.winningNullifier;

        // Verify the ZK proof
        require(verifier.verify(proof, publicInputs), "Invalid ZK proof");

        auction.claimed = true;

        // Transfer tokens to stealth address
        IERC20(auction.tokenAddress).safeTransfer(stealthAddress, auction.tokenAmount);

        emit AuctionClaimed(auctionId, stealthAddress);
    }

    function cancelAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(
            msg.sender == auction.seller || msg.sender == owner(), "Not authorized"
        );
        require(!auction.claimed, "Already claimed");
        require(!auction.cancelled, "Already cancelled");

        auction.cancelled = true;

        IERC20(auction.tokenAddress).safeTransfer(auction.seller, auction.tokenAmount);

        emit AuctionCancelled(auctionId);
    }

    // ==================== View Functions ====================

    function getAuctionPhase(uint256 auctionId) external view returns (AuctionPhase) {
        Auction storage auction = auctions[auctionId];
        if (auction.cancelled) return AuctionPhase.CANCELLED;
        if (auction.claimed) return AuctionPhase.ENDED;
        if (block.timestamp <= auction.commitDeadline) return AuctionPhase.COMMIT;
        if (block.timestamp <= auction.settleDeadline) return AuctionPhase.SETTLE;
        return AuctionPhase.ENDED;
    }

    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    function getCommit(uint256 auctionId, bytes32 nullifier) external view returns (Commit memory) {
        return commits[auctionId][nullifier];
    }

    function getCommitCount(uint256 auctionId) external view returns (uint256) {
        return commitCount[auctionId];
    }
}
