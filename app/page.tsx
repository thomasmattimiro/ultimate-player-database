import Link from "next/link";

const sections = [
  {
    title: "Players",
    description: "Explore player profiles, career histories, and performance.",
    href: "/players",
  },
  {
    title: "Teams",
    description: "Follow team rosters, seasons, results, and competitive strength.",
    href: "/teams/standings",
  },
  {
    title: "Events",
    description: "Browse tournaments, divisions, games, and historical results.",
    href: "/events",
  },
  {
    title: "Rankings",
    description: "Explore transparent, versioned team ratings and rankings.",
    href: "/rankings",
  },
];

export default function HomePage() {
  return (
    <main className="site-shell">
      <header className="topbar">
        <Link className="brand" href="/">UPD<span>.</span></Link>
        <nav aria-label="Main navigation">
          <Link href="/players">Players</Link>
          <Link href="/teams/standings">Teams</Link>
          <Link href="/events">Events</Link>
          <Link href="/rankings">Rankings</Link>
          <Link href="/statistics">Statistics</Link>
          <Link href="/maps">Maps</Link>
        </nav>
        <span className="status-label">Building the record of the sport</span>
      </header>

      <section className="hero">
        <p className="eyebrow">THE ULTIMATE PLAYER DATABASE</p>
        <h1>The history, people, and performance of ultimate.</h1>
        <p className="hero-copy">
          A connected record of players, teams, tournaments, and games —
          built for discovery, historical context, and serious analysis.
        </p>
        <div className="hero-actions">
          <Link className="button button-primary" href="/players">Explore players</Link>
          <Link className="button button-secondary" href="/rankings">View rankings</Link>
        </div>
        <p className="data-note">
          The platform is under active development. No sample statistics are
          presented as real competitive results.
        </p>
      </section>

      <section className="section">
        <div className="section-heading">
          <div>
            <p className="eyebrow">EXPLORE THE DATABASE</p>
            <h2>One connected history of the sport.</h2>
          </div>
        </div>
        <div className="section-grid">
          {sections.map((section) => (
            <Link className="section-card" href={section.href} key={section.title}>
              <span className="card-kicker">DATABASE / {section.title.toUpperCase()}</span>
              <h3>{section.title}</h3>
              <p>{section.description}</p>
              <span className="card-link">Explore <span aria-hidden="true">→</span></span>
            </Link>
          ))}
        </div>
      </section>

      <footer className="footer">
        <span>Ultimate Player Database</span>
        <span>Historical data • Transparent analytics • Connected records</span>
      </footer>
    </main>
  );
}