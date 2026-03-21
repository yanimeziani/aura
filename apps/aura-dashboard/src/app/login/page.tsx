"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Shield, AlertTriangle } from "lucide-react";
import { storeToken } from "@/lib/auth";
import { validateToken, getGatewayUrl } from "@/lib/gateway";

export default function LoginPage() {
  const [token, setToken] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const result = await validateToken(token.trim());
      if (result.valid) {
        storeToken(token.trim());
        router.replace("/");
      } else {
        setError("INVALID_TOKEN: Access denied");
      }
    } catch {
      const url = getGatewayUrl();
      setError(
        `Gateway not reachable at ${url}. Start it from repo root, then reload this page.\n\n` +
          "Linux/macOS: ./ops/bin/nexa gateway   or   python3 nexa.py gateway\n" +
          "Windows:    nexa.cmd gateway   or   py -3 nexa.py gateway\n\n" +
          "Or run the full demo: ./ops/bin/nexa demo  (starts gateway + dashboard)."
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-black text-white font-mono flex items-center justify-center p-4">
      <div className="w-full max-w-md space-y-8">
        <div className="border-4 border-white p-8 space-y-6">
          <div className="text-center space-y-2">
            <Shield className="w-12 h-12 mx-auto opacity-70" />
            <h1 className="text-2xl font-black tracking-tighter uppercase">
              NEXA // AUTH
            </h1>
            <p className="text-xs opacity-50 uppercase">
              Vault token required for mesh access
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label
                htmlFor="token"
                className="text-xs uppercase opacity-50 block mb-2"
              >
                Vault Token
              </label>
              <input
                id="token"
                type="password"
                value={token}
                onChange={(e) => setToken(e.target.value)}
                placeholder="Enter vault token..."
                className="w-full bg-black border-2 border-white p-3 font-mono text-sm text-white placeholder:opacity-30 focus:outline-none focus:border-terminal"
                autoFocus
                required
              />
            </div>

            {error && (
              <div className="border-2 border-danger p-3 text-danger text-xs flex items-start gap-2">
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                <pre className="whitespace-pre-wrap break-words m-0 font-mono">
                  {error}
                </pre>
              </div>
            )}

            <button
              type="submit"
              disabled={loading || !token.trim()}
              className="w-full border-2 border-white p-3 font-bold uppercase text-sm hover:bg-white hover:text-black transition-all disabled:opacity-30 disabled:cursor-not-allowed"
            >
              {loading ? "AUTHENTICATING..." : "AUTHENTICATE"}
            </button>
          </form>
        </div>

        <p className="text-[10px] opacity-20 text-center uppercase">
          Sovereign mesh // No cloud dependencies // Local-first auth
        </p>
      </div>
    </div>
  );
}
