"use client";

import { useEffect, useState } from "react";
import { keccak256, toBytes } from "viem";

export const MockKycPanel = ({ address }: { address?: string }) => {
  const [kycStatus, setKycStatus] = useState<"NONE" | "PROCESSING" | "PROVING" | "VERIFIED">("NONE");
  const [entityName, setEntityName] = useState("");
  const [identityHash, setIdentityHash] = useState<string | null>(null);

  // Load from local storage mapped to wallet address
  useEffect(() => {
    if (address) {
      try {
        const stored = localStorage.getItem(`aether_kyc_${address}`);
        if (stored) {
          const data = JSON.parse(stored);
          if (data.kycStatus === "VERIFIED") {
            setKycStatus("VERIFIED");
            setIdentityHash(data.identityHash);
          }
        }
      } catch (e) {
        console.warn("Error reading KYC JSON", e);
      }
    }
  }, [address]);

  const handleVerify = () => {
    if (!entityName.trim()) return;

    setKycStatus("PROCESSING");

    // Simulate network delay / Identity API
    setTimeout(() => {
      setKycStatus("PROVING");

      // Simulate Proof Generation and Hashing
      setTimeout(() => {
        const hash = keccak256(toBytes(entityName + Date.now().toString()));
        setIdentityHash(hash);
        setKycStatus("VERIFIED");

        if (address) {
          localStorage.setItem(
            `aether_kyc_${address}`,
            JSON.stringify({
              kycStatus: "VERIFIED",
              identityHash: hash,
            }),
          );
        }
      }, 2500);
    }, 1500);
  };

  return (
    <div className="bg-white border-4 border-black shadow-[8px_8px_0px_#A67BF5] relative flex flex-col w-full">
      <div className="p-6 md:p-8 flex-1 flex flex-col">
        <h2 className="text-2xl font-winky font-normal tracking-wide uppercase flex items-center gap-3 mb-4 text-black border-b-4 border-black pb-4">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={3}
            stroke="currentColor"
            className="w-8 h-8 text-[#A67BF5]"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
            />
          </svg>
          ZKKYC Verification
        </h2>

        <p className="font-dm text-sm font-bold text-black/70 mb-6">
          HashKey ZKID Track: Cryptographically verify your institutional status without revealing your on-chain
          identity to the public.
        </p>

        {kycStatus === "NONE" && (
          <div className="mt-auto space-y-4">
            <div className="flex flex-col gap-2">
              <label className="font-fira text-xs font-bold uppercase tracking-wider text-black">
                Entity Legal Name
              </label>
              <input
                type="text"
                placeholder="e.g. Acme Trading Group LLC"
                value={entityName}
                onChange={e => setEntityName(e.target.value)}
                className="w-full p-4 border-4 border-black font-fira text-lg font-bold bg-[#E5E5E5] text-black focus:outline-none focus:bg-white focus:ring-0 focus:border-[#A67BF5] shadow-[4px_4px_0px_#000]"
              />
            </div>

            <button
              onClick={handleVerify}
              disabled={!entityName.trim()}
              className="w-full py-4 bg-[#A67BF5] text-white border-4 border-black font-dm font-bold text-xl uppercase tracking-wider shadow-[6px_6px_0px_#000000] hover:translate-y-[2px] hover:translate-x-[2px] hover:shadow-[4px_4px_0px_#000000] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              Generate Identity Proof
            </button>
            <div className="bg-[#FFD700] border-2 border-black p-3 shadow-[2px_2px_0px_#000]">
              <p className="font-dm text-xs font-bold text-black">
                Your PII never leaves your browser. Noir circuits compile mathematical proofs locally.
              </p>
            </div>
          </div>
        )}

        {(kycStatus === "PROCESSING" || kycStatus === "PROVING") && (
          <div className="mt-auto flex flex-col items-center justify-center p-8 bg-[#E5E5E5] border-4 border-black shadow-[4px_4px_0px_#000]">
            <span className="loading loading-spinner text-[#A67BF5] w-12 h-12 mb-4"></span>
            <p className="font-fira font-bold uppercase tracking-widest text-[#A67BF5] animate-pulse">
              {kycStatus === "PROCESSING" ? "Contacting Identity Oracle..." : "Synthesizing ZK-SNARK..."}
            </p>
          </div>
        )}

        {kycStatus === "VERIFIED" && (
          <div className="mt-auto space-y-4">
            <div className="bg-[#A67BF5] text-white border-4 border-black p-4 shadow-[4px_4px_0px_#000] flex items-center justify-between">
              <div className="flex items-center gap-3">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={3}
                  stroke="currentColor"
                  className="w-6 h-6"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                </svg>
                <span className="font-fira text-lg font-bold uppercase tracking-wider">ZKID Attested</span>
              </div>
              <span className="font-fira bg-black text-white px-2 py-1 text-xs border border-white">
                [ INSTITUTIONAL ]
              </span>
            </div>

            <div className="bg-[#E5E5E5] border-2 border-black p-4 shadow-[2px_2px_0px_#000]">
              <p className="font-fira text-xs font-bold uppercase tracking-wider text-black mb-2">
                Identity Nullifier Hash
              </p>
              <p className="font-fira text-xs break-all text-[#A67BF5] font-bold bg-white p-2 border border-black">
                {identityHash}
              </p>
            </div>

            <p className="font-dm text-xs font-bold text-black/70 mt-2 text-center">
              Your wallet is now registered in the ZKKYCRegistry on HashKey Chain. You may now bid in regulated OTC
              Auctions.
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
