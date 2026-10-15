"use client";

import { useState } from "react";
import { youtubeEmbed } from "@/lib/utils";

/** Blurred photo + pulsing play button; plays the Ammos film on click. */
export function DiscoverVideo({ poster, video, youtubeUrl, label }: { poster: string; video: string; youtubeUrl?: string; label: string }) {
  const [playing, setPlaying] = useState(false);
  const yt = youtubeEmbed(youtubeUrl || "");
  return (
    <section className="discover" aria-label="Discover Ammos video">
      {!playing ? (
        <>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="discover-bg" src={poster} alt="" loading="lazy" />
          <div className="discover-shade" />
          <div className="discover-center" data-reveal>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/images/logo.svg" alt="" width={210} height={54} />
            <button type="button" className="play-btn" aria-label="Play the Ammos film" onClick={() => setPlaying(true)}>
              <span />
            </button>
            <span className="discover-label">{label}</span>
          </div>
        </>
      ) : (
        <>
          {yt ? (
            <iframe src={yt} title="Ammos film" allow="autoplay; encrypted-media; picture-in-picture" allowFullScreen />
          ) : (
            <video src={video} autoPlay controls playsInline />
          )}
          <button type="button" className="video-close" aria-label="Close video" onClick={() => setPlaying(false)}>
            ×
          </button>
        </>
      )}
    </section>
  );
}
