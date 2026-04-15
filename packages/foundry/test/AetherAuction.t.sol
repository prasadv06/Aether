// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/AetherToken.sol";
import "../contracts/AetherAuction.sol";
import "../contracts/ZKKYCRegistry.sol";

/// @notice Mock verifier that always returns true (for testing)
contract MockVerifier {
    function verify(bytes calldata, bytes32[] calldata) external pure returns (bool) {
        return true;
    }
}

contract AetherAuctionTest is Test {
    AetherToken token;
    AetherAuction auction;
    ZKKYCRegistry registry;
    MockVerifier mockVerifier;

    address owner = address(this);
    address seller = makeAddr("seller");
    address bidder1 = makeAddr("bidder1");
    address bidder2 = makeAddr("bidder2");
    address stealthAddr = makeAddr("stealth");

    uint256 constant TOKEN_AMOUNT = 1000 ether;
    uint256 constant MINIMUM_BID = 0.1 ether;
    uint256 constant COMMIT_DURATION = 1 hours;
    uint256 constant SETTLE_DURATION = 1 hours;

    bytes32 constant NULLIFIER_1 = keccak256("nullifier1");
    bytes32 constant NULLIFIER_2 = keccak256("nullifier2");
    bytes32 constant COMMIT_HASH_1 = keccak256("commit1");
    bytes32 constant COMMIT_HASH_2 = keccak256("commit2");

    function setUp() public {
        token = new AetherToken(owner);
        mockVerifier = new MockVerifier();
        auction = new AetherAuction(owner, address(mockVerifier));
        registry = new ZKKYCRegistry(owner);

        // Configure ZK-KYC registry on auction
        auction.setZKKYCRegistry(address(registry));

        token.transfer(seller, TOKEN_AMOUNT);
    }

    function _createAuction() internal returns (uint256 auctionId) {
        vm.startPrank(seller);
        token.approve(address(auction), TOKEN_AMOUNT);
        auctionId = auction.createAuction(
            address(token), TOKEN_AMOUNT, MINIMUM_BID, COMMIT_DURATION, SETTLE_DURATION
        );
        vm.stopPrank();
    }

    // =========================================================================
    // Test 1: createAuction success
    // =========================================================================

    function test_CreateAuction_Success() public {
        uint256 sellerBalBefore = token.balanceOf(seller);

        vm.startPrank(seller);
        token.approve(address(auction), TOKEN_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit AetherAuction.AuctionCreated(0, seller, address(token), TOKEN_AMOUNT);

        uint256 auctionId = auction.createAuction(
            address(token), TOKEN_AMOUNT, MINIMUM_BID, COMMIT_DURATION, SETTLE_DURATION
        );
        vm.stopPrank();

        assertEq(auctionId, 0);
        assertEq(auction.nextAuctionId(), 1);

        AetherAuction.Auction memory a = auction.getAuction(auctionId);
        assertEq(a.seller, seller);
        assertEq(a.tokenAddress, address(token));
        assertEq(a.tokenAmount, TOKEN_AMOUNT);
        assertEq(a.minimumBid, MINIMUM_BID);
        assertEq(a.commitDeadline, block.timestamp + COMMIT_DURATION);
        assertEq(a.settleDeadline, block.timestamp + COMMIT_DURATION + SETTLE_DURATION);
        assertFalse(a.claimed);
        assertFalse(a.cancelled);

        assertEq(token.balanceOf(seller), sellerBalBefore - TOKEN_AMOUNT);
        assertEq(token.balanceOf(address(auction)), TOKEN_AMOUNT);
    }

    // =========================================================================
    // Test 2: commitBid with nullifier
    // =========================================================================

    function test_CommitBid_Success() public {
        uint256 auctionId = _createAuction();

        vm.expectEmit(true, true, false, true);
        emit AetherAuction.BidCommitted(auctionId, NULLIFIER_1);

        vm.prank(bidder1);
        auction.commitBid(auctionId, NULLIFIER_1, COMMIT_HASH_1);

        AetherAuction.Commit memory c = auction.getCommit(auctionId, NULLIFIER_1);
        assertEq(c.commitHash, COMMIT_HASH_1);
        assertTrue(c.exists);
        assertEq(auction.getCommitCount(auctionId), 1);
    }

    // =========================================================================
    // Test 3: commitBid reverts after deadline
    // =========================================================================

    function test_CommitBid_RevertsAfterDeadline() public {
        uint256 auctionId = _createAuction();

        vm.warp(block.timestamp + COMMIT_DURATION + 1);

        vm.prank(bidder1);
        vm.expectRevert("Commit phase ended");
        auction.commitBid(auctionId, NULLIFIER_1, COMMIT_HASH_1);
    }

    // =========================================================================
    // Test 4: commitBid reverts on duplicate nullifier
    // =========================================================================

    function test_CommitBid_RevertsDuplicateNullifier() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.commitBid(auctionId, NULLIFIER_1, COMMIT_HASH_1);

        vm.prank(bidder2);
        vm.expectRevert("Nullifier already used");
        auction.commitBid(auctionId, NULLIFIER_1, COMMIT_HASH_2);
    }

    // =========================================================================
    // Test 5: declareWinner success
    // =========================================================================

    function test_DeclareWinner_Success() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.commitBid(auctionId, NULLIFIER_1, COMMIT_HASH_1);

        vm.warp(block.timestamp + COMMIT_DURATION + 1);

        vm.expectEmit(true, true, false, true);
        emit AetherAuction.WinnerDeclared(auctionId, NULLIFIER_1);

        auction.declareWinner(auctionId, NULLIFIER_1);

        AetherAuction.Auction memory a = auction.getAuction(auctionId);
        assertEq(a.winningNullifier, NULLIFIER_1);
    }

    // =========================================================================
    // Test 6: claimWithProof success
    // =========================================================================

    function test_ClaimWithProof_Success() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.commitBid(auctionId, NULLIFIER_1, COMMIT_HASH_1);

        vm.warp(block.timestamp + COMMIT_DURATION + 1);
        auction.declareWinner(auctionId, NULLIFIER_1);

        bytes memory fakeProof = hex"deadbeef";

        vm.expectEmit(true, false, false, true);
        emit AetherAuction.AuctionClaimed(auctionId, stealthAddr);

        vm.prank(bidder1);
        auction.claimWithProof(auctionId, fakeProof, stealthAddr);

        assertEq(token.balanceOf(stealthAddr), TOKEN_AMOUNT);
        assertEq(token.balanceOf(address(auction)), 0);

        AetherAuction.Auction memory a = auction.getAuction(auctionId);
        assertTrue(a.claimed);
    }

    // =========================================================================
    // Test 7: cancelAuction refunds seller
    // =========================================================================

    function test_CancelAuction_RefundsSeller() public {
        uint256 auctionId = _createAuction();

        uint256 sellerBalBefore = token.balanceOf(seller);

        vm.prank(seller);
        auction.cancelAuction(auctionId);

        assertEq(token.balanceOf(seller), sellerBalBefore + TOKEN_AMOUNT);
        assertEq(token.balanceOf(address(auction)), 0);

        AetherAuction.Auction memory a = auction.getAuction(auctionId);
        assertTrue(a.cancelled);

        assertEq(
            uint256(auction.getAuctionPhase(auctionId)),
            uint256(AetherAuction.AuctionPhase.CANCELLED)
        );
    }

    // =========================================================================
    // Test 8: ZKKYCRegistry basic flow
    // =========================================================================

    function test_ZKKYCRegistry_RegisterAndVerify() public {
        bytes32 identityCommitment = keccak256("user_identity_hash");
        uint256 validityDuration = 365 days;

        // Register attestation
        registry.registerAttestation(
            identityCommitment,
            ZKKYCRegistry.KYCLevel.BASIC,
            validityDuration
        );

        // Check validity
        assertTrue(registry.isKYCValid(identityCommitment, ZKKYCRegistry.KYCLevel.BASIC));
        assertFalse(registry.isKYCValid(identityCommitment, ZKKYCRegistry.KYCLevel.ENHANCED));

        // Verify ZK-KYC
        bytes32 nullifier = keccak256("kyc_nullifier");
        assertTrue(registry.verifyZKKYC(nullifier, identityCommitment, ZKKYCRegistry.KYCLevel.BASIC));

        // Nullifier can't be reused
        vm.expectRevert("Nullifier already used");
        registry.verifyZKKYC(nullifier, identityCommitment, ZKKYCRegistry.KYCLevel.BASIC);
    }
}
