import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Ammos Makenzy Beach",
    short_name: "Ammos",
    description: "Beach bar & restaurant on Makenzy Beach, Larnaca",
    start_url: "/",
    display: "standalone",
    background_color: "#0f1119",
    theme_color: "#0f1119",
    icons: [
      { src: "/icon.png", sizes: "512x512", type: "image/png" },
      { src: "/apple-icon.png", sizes: "180x180", type: "image/png" },
    ],
  };
}
