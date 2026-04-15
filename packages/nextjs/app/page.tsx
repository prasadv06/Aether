"use client";

import type { NextPage } from "next";
import { Hero } from "~~/components/aether/Hero";
import { StorytellingSection } from "~~/components/aether/StorytellingSection";

const Home: NextPage = () => {
  return (
    <div className="flex flex-col flex-1 min-h-screen bg-white">
      <Hero />
      <StorytellingSection />
    </div>
  );
};

export default Home;
