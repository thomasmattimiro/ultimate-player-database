import Link from "next/link";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-[60vh] max-w-3xl flex-col items-center justify-center px-6 py-20 text-center">
      <p className="text-sm font-semibold uppercase tracking-[0.18em] text-emerald-600">
        404 · Page not found
      </p>
      <h1 className="mt-4 text-4xl font-semibold tracking-tight text-slate-950 dark:text-white">
        We couldn&apos;t find that page.
      </h1>
      <p className="mt-4 max-w-xl text-base leading-7 text-slate-600 dark:text-slate-300">
        The page may have moved, or the address may be incorrect.
      </p>
      <Link
        href="/"
        className="mt-8 inline-flex items-center rounded-md bg-emerald-700 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-emerald-800"
      >
        Return home
      </Link>
    </main>
  );
}
