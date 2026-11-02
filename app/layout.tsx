import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Ultimate Player Database",
    template: "%s | Ultimate Player Database",
  },
  description:
    "A comprehensive historical database and analytics platform for competitive ultimate frisbee.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}