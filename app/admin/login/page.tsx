import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { LoginForm } from "@/components/admin/LoginForm";

export const metadata = { title: "Log in" };
export const dynamic = "force-dynamic";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const { next } = await searchParams;
  const safeNext = next && next.startsWith("/admin") && !next.startsWith("//") ? next : "/admin";
  if (await getSessionUser()) redirect(safeNext);
  return (
    <main className="a-login">
      <div className="a-login-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/images/logo.svg" alt="ammos" width={180} height={46} />
        <h1>Admin login</h1>
        <LoginForm next={safeNext} />
        <p className="a-help" style={{ textAlign: "center" }}>
          Forgot your password? Ask the owner to reset it, or run <code>npm run admin:create</code> on the server.
        </p>
      </div>
    </main>
  );
}
