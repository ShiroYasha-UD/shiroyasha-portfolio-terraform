import { useState } from 'react';

const nodes = [
  { id: 'web', sub: 'Frontend', label: 'React / TS',
    why: 'Typed components and a small, predictable state layer. Built to static files and served from the edge, so the UI is fast and cheap to host.' },
  { id: 'edge', sub: 'Edge', label: 'CloudFront',
    why: 'TLS, caching and a firewall in front of everything. The API is never exposed directly, and static files never touch a server.' },
  { id: 'sso', sub: 'Identity', label: 'SAML / SSO',
    why: 'Google login for the app. Spring Security handles the SAML flow in a single auth service, so the other services never deal with login themselves.' },
  { id: 'api', sub: 'Services', label: 'Spring Boot',
    why: 'Where the actual business logic lives. Clear module boundaries, JPA/Hibernate for persistence, unit/integration tests against real database, and metrics from day one.' },
  { id: 'db', sub: 'OLTP', label: 'Aurora',
    why: 'PostgreSQL configured with active-from/to dates. Schema changes go through versioned migrations using Flyway, and heavy reporting never runs here.' },
  { id: 'dw', sub: 'Analytics', label: 'Read Replica',
    why: 'AWS Aurora Read Replica of the prod Database, so they can be slow and power-hungry without hurting the prod, wired to Google Data Studio where reports are.' },
];

export default function StackDiagram() {
  const [selected, setSelected] = useState('api');
  const current = nodes.find((node) => node.id === selected) ?? nodes[3];
  return <section className="stack panel" aria-labelledby="stack-title">
    <div className="section-heading"><h2 id="stack-title">My usual stack, and why each piece is there</h2><p className="mono muted">click around →</p></div>
    <div className="stack-nodes" aria-label="Select a part of the stack">{nodes.map((node, index) => <div className="stack-item" key={node.id}>
      <button type="button" className={selected === node.id ? 'stack-node selected' : 'stack-node'} aria-pressed={selected === node.id} onClick={() => setSelected(node.id)}><span>{node.sub}</span><strong>{node.label}</strong></button>
      {index < nodes.length - 1 && <span className="stack-arrow" aria-hidden="true">⟶</span>}
    </div>)}</div>
    <div className="stack-detail" aria-live="polite"><div className="stack-detail-content" key={current.id}><div><p className="eyebrow accent">{current.sub}</p><h3>{current.label}</h3></div><p>{current.why}</p></div></div>
  </section>;
}
