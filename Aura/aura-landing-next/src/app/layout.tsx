import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Meziani AI Labs | Autonomous Systems Infrastructure",
  description: "Deploy sovereign, self-hosted AI systems for enterprise operations.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  );
}
