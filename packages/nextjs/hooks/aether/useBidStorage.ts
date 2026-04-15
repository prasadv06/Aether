"use client";

import { useCallback } from "react";
import { StoredBid } from "~~/types/auction";

const STORAGE_KEY = "aether-bids";

const getAll = (): StoredBid[] => {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
};

const saveAll = (bids: StoredBid[]) => {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(bids));
};

export const useBidStorage = () => {
  const getBid = useCallback((auctionId: number): StoredBid | undefined => {
    return getAll().find(b => b.auctionId === auctionId);
  }, []);

  const saveBid = useCallback((bid: StoredBid) => {
    const bids = getAll().filter(b => b.auctionId !== bid.auctionId);
    bids.push(bid);
    saveAll(bids);
  }, []);

  const markRevealed = useCallback((auctionId: number) => {
    const bids = getAll();
    const idx = bids.findIndex(b => b.auctionId === auctionId);
    if (idx !== -1) {
      bids[idx].revealed = true;
      saveAll(bids);
    }
  }, []);

  const getAllBids = useCallback((): StoredBid[] => {
    return getAll();
  }, []);

  return { getBid, saveBid, markRevealed, getAllBids };
};
