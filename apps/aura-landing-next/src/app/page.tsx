"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { routing } from "@/i18n/routing";

export default function RootRedirect() {
  const router = useRouter();
  useEffect(() => {
    router.replace(`/${routing.defaultLocale}`);
  }, [router]);
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", fontFamily: "var(--font-body)" }}>
      <p style={{ opacity: 0.6 }}>Redirecting…</p>
    </div>
  );
}
