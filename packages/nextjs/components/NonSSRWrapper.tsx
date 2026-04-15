"use client";

import React from "react";
import dynamic from "next/dynamic";

const NonSSRWrapper = ({ children }: { children: React.ReactNode }) => <>{children}</>;

export default dynamic(() => Promise.resolve(NonSSRWrapper), {
  ssr: false,
});
