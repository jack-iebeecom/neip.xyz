import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import Header from "@/components/Layout/Header";
import Footer from "@/components/Layout/Footer";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "neip.xyz - Global Network Testing Tools",
  description: "Test network connectivity to 7 countries worldwide. Free ping, traceroute, whois, and IP lookup tools with AI-powered analysis.",
  keywords: ["ping test", "traceroute", "network tools", "ip lookup", "whois", "network connectivity", "global servers"],
  authors: [{ name: "neip.xyz" }],
  robots: "index, follow",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-slate-900 text-gray-200`}
      >
        <div className="root-container">
          <Header />
          <main className="w-full">
            {children}
          </main>
          <Footer />
        </div>
      </body>
    </html>
  );
}