# HNAG — Master Audit Prompt Pack

> Source-of-truth reusable prompts. Pair with [docs/99-PRODUCTION-READINESS.md](../docs/99-PRODUCTION-READINESS.md)
> which is the live tracker. These prompts are the **checklist**; the tracker
> is the **build log**.

## How to use

- Open a fresh Claude / Cursor / Codex session.
- Paste the master audit prompt (§1) — it produces the full 40-area report.
- Pair the agent's findings with `docs/99-PRODUCTION-READINESS.md` §3 and add
  any new items as their own checkbox row.
- For surgical re-audits (just security, just AI, just infra), use one of the
  specialised prompts §2 → §17 below.

⸻

## §1 — Master full project audit

```
You are a senior staff engineer, product architect, security engineer,
DevOps engineer, UX expert, and startup CTO.

Analyze my entire repository deeply like a real production audit for a
startup preparing to launch publicly.

Repository: <local path or GitHub URL>

I need exhaustive answers across all 40 areas: architecture, folder
structure, frontend quality, backend quality, database design, API design,
security vulnerabilities, authentication/authorization, session/token
handling, scalability, performance bottlenecks, memory leaks,
async/concurrency, state management, AI/recommendation logic, mobile
responsiveness, UX/UI, accessibility, SEO, DevOps/deployment readiness,
env-var handling, error handling, logging/monitoring, rate
limiting/abuse, production-deployment risks, technical debt, missing core
startup features, critical bugs, code smells, refactoring suggestions,
missing tests, CI/CD readiness, Docker/container readiness, database
optimization, caching opportunities, API optimization, security
hardening, real-world prod risks, scalability to 100k+, final launch
readiness score.

For every issue: WHY it is a problem, REAL WORLD impact, SEVERITY
(Critical / High / Medium / Low), exact file paths, code examples, fix
strategy, production-grade solution.

End with: A) Top 20 most dangerous issues; B) Top 20 highest impact
improvements; C) Must-fix before launch; D) Can wait until after launch;
E) Production readiness score /100; F) Scalability capacity estimate;
G) Technical debt level; H) Investor impression; I) UX quality;
J) Step-by-step roadmap to production.

Be brutally honest. Do not sugarcoat. Think like a real CTO preparing
this product for millions of users.
```

⸻

## §2 — Frontend + UI/UX audit

```
Audit the entire frontend / UI / UX of HNAG.

Review: design consistency, visual hierarchy, color system, typography,
component consistency, mobile/tablet/desktop responsiveness, animations,
loading/empty/error states, accessibility, touch interactions, navigation
UX, onboarding, food recommendation UX, search UX, AI interaction UX,
session persistence UX, performance UX, skeleton loading, scroll
behaviour, keyboard navigation, input validation UX, dark mode, edge
cases.

Find: bad UX patterns, broken flows, confusing screens, missing states,
slow interactions, accessibility issues, mobile issues, layout
instability, over-engineered components, missing production polish.

Then mentally redesign like a top-tier startup product. Compare against
Grab, TikTok, Notion, ChatGPT, Instagram, Spotify, Zalo.

Provide: UI score, UX score, production polish score, startup quality
score, conversion-optimization suggestions, retention-optimization
suggestions, full redesign recommendations.
```

⸻

## §3 — Backend + API audit

```
Deeply audit HNAG's backend architecture and APIs.

Review: API architecture, REST conventions, GraphQL structure, error
handling, validation, authentication, authorization, middleware, rate
limiting, database queries, ORM usage, N+1 problems, async handling,
queue systems, WebSocket handling, realtime scalability, AI request
handling, file uploads, caching, Redis usage, background jobs, logging,
monitoring, security, injection vulnerabilities, DOS risks, token/session
handling, multi-device sessions, edge case handling, API consistency,
pagination, search optimization, AI response handling, timeout handling,
retry logic.

Provide: critical architecture flaws, scaling bottlenecks, security
risks, data corruption risks, production deployment risks, suggested
enterprise architecture, microservice split, caching strategy, infra
architecture, production-ready backend roadmap.
```

⸻

## §4 — Database audit

```
Audit HNAG's database design and data architecture.

Review: table/schema design, relationships, indexes, query performance,
data normalization, over-normalization, missing indexes, cascade risks,
transaction handling, data consistency, data duplication risks, migration
quality, soft delete strategy, audit logs, search strategy, AI/history
storage, session storage, recommendation storage, analytics/event
storage, scaling limits, multi-region readiness.

Find: dangerous schema issues, slow query risks, future scaling
problems, data corruption risks, missing constraints, missing indexes,
migration dangers, bad relational design.

Redesign for 100k, 1M, 10M users. Provide: optimized schema strategy,
recommended indexes, query-optimization strategy, Redis/cache strategy,
event-driven architecture suggestions.
```

⸻

## §5 — Security audit

```
Act as a senior penetration tester and security architect.

Audit HNAG for: XSS, CSRF, SSRF, SQL/NoSQL injection, prompt injection,
AI jailbreak risks, token leakage, JWT issues, session fixation, OAuth
flaws, authentication bypass, authorization flaws, IDOR, file upload
vulnerabilities, rate limiting, DDOS, secret exposure, .env leakage,
admin privilege escalation, API abuse, AI abuse, unsafe
markdown/HTML rendering, CORS misconfiguration, cookie security, HTTPS
enforcement, dependency vulnerabilities, open source / supply chain
risks, logging sensitive data, user data privacy risks.

Per vulnerability: exploit scenario, severity, real-world impact, fix
strategy, enterprise-grade mitigation.

Provide: security score, production security readiness, top 10 critical
vulnerabilities, OWASP checklist, compliance readiness, security
hardening roadmap.
```

⸻

## §6 — AI system audit

```
Audit HNAG's AI/recommendation system architecture.

Review: prompt engineering, recommendation quality, context memory, AI
hallucination handling, AI moderation, prompt injection protection, user
personalization, ranking algorithms, food recommendation logic, session
memory, AI latency, AI fallback handling, AI provider abstraction,
multi-model support, streaming responses, cost optimization, AI caching,
embedding strategy, RAG architecture, AI observability, AI analytics, AI
abuse prevention, toxic content prevention, prompt storage, AI
scalability.

Provide: AI architecture score, recommendation quality score, scalability
score, AI production risks, cost-optimization opportunities, better AI
architecture, multi-agent opportunities, RAG opportunities, vector
database opportunities, long-term AI roadmap.
```

⸻

## §7 — Production deployment audit

```
Audit HNAG as if it ships tomorrow to real users.

Review: Docker, Docker Compose, Kubernetes readiness, CI/CD, GitHub
Actions, secrets management, monitoring, alerting, logging,
observability, Sentry integration, uptime strategy, database backup,
rollback strategy, blue-green deployment, CDN strategy, image
optimization, asset caching, Cloudflare readiness, Redis readiness, queue
system, worker system, horizontal scaling, database scaling, load
balancing, edge deployment, cost optimization, environment separation,
staging environments, disaster recovery, production debugging strategy.

Provide: launch blockers, infrastructure weaknesses, scalability
bottlenecks, DevOps missing pieces, estimated monthly infra cost,
suggested AWS/GCP/Vercel architecture, suggested deployment stack, launch
checklist, production incident checklist, day-1 launch strategy.
```

⸻

## §8 — Real user flow audit

```
Simulate being a real first-time user of HNAG.

Test: landing, onboarding, login/register, food recommendation flow,
search flow, AI assistant flow, mobile flow, error scenarios, slow
internet, returning user, session persistence, logout/login, empty data
situations, recommendation trustworthiness, emotional engagement,
addictive/retention potential, social/sharing opportunities, monetization
opportunities.

Provide: friction points, confusing moments, trust issues, UX dead ends,
retention killers, features users will love, features users will ignore,
memorability, amateur vs premium feel. Then: user retention score,
virality score, product-market-fit potential, investor demo quality,
consumer app quality score.
```

⸻

## §9 — Code refactoring prompt

```
Refactor HNAG mentally like a senior FAANG staff engineer.

Find: bad architecture, tight coupling, duplicate logic, massive files,
bad naming, state chaos, re-render problems, async bugs, weak
abstractions, hardcoded values, magic strings, technical debt, missing
types, weak interfaces, poor folder structure, missing domain
separation, anti-patterns.

Redesign: folder structure, architecture, API layer, state management,
component architecture, service layer, caching strategy, AI
abstraction, database abstraction, scalability architecture.

Provide: before-vs-after structure, refactor roadmap, priority order,
estimated effort, risk assessment.
```

⸻

## §10 — Final CTO launch decision

```
Act as a world-class startup CTO and investor.

Evaluate whether HNAG is truly ready for public launch. Think like a
YC partner, FAANG staff engineer, startup CTO, security lead, DevOps
lead, product designer, AI architect.

Answer: is this production-ready? what would break first under real
users? biggest technical risk, business risk, UX problem, scalability
problem, security problem, AI problem? what feels world-class? what
feels amateur? would investors be impressed? would users return daily?
could this scale to millions? would you approve launch? what MUST be
fixed first?

Provide scores: production readiness, launch confidence, investor
confidence, product quality, technical architecture, AI quality, UX,
security, scalability.

End with a brutally honest final verdict.
```

⸻

## §11 — Things HNAG must have before real launch

A short list to staple to every review pass:

```
Rate limiting · abuse detection · AI moderation · analytics dashboard ·
user feedback system · crash reporting · error logging · AI response
tracking · session analytics · A/B testing · recommendation analytics ·
search analytics · user-behavior tracking · CDN · image optimization ·
lazy loading · skeleton loading · retry handling · offline handling ·
PWA · SEO metadata · social preview · monitoring dashboard · admin
dashboard · feature flags · backup system · health checks · queue
workers · cache invalidation · environment separation · staging
environment · security headers · CSP · API throttling · bot protection ·
spam prevention · AI cost protection.
```

⸻

## §12 — Suggested production stack

```
Frontend  : Next.js, TypeScript, Tailwind, ShadCN, TanStack Query,
            Zustand, Framer Motion
Mobile    : Flutter (current), Riverpod (already in pubspec, now use it)
Backend   : NestJS / Fastify, PostgreSQL (PostGIS), Prisma, Redis, BullMQ
AI        : OpenAI, Gemini, Claude, fallback routing, embeddings, vector DB
Infra     : Vercel / AWS / Cloudflare, Docker, GitHub Actions, Sentry,
            Grafana, Prometheus
Storage   : S3-compatible storage + CDN caching
Monitoring: PostHog, Sentry, OpenTelemetry
```

⸻

## §13 — Realistic pre-launch checklist

```
Must fix before launch:
  security vulnerabilities · broken auth flows · memory leaks · missing
  loading states · missing error handling · unoptimized DB queries · AI
  abuse protection · API rate limiting · env-var issues · build
  instability · mobile responsiveness · SEO · slow page loads · broken
  session persistence · missing monitoring.

Should fix soon after launch:
  advanced analytics · recommendation fine-tuning · social features ·
  advanced caching · multi-region deployment · AI personalization · A/B
  testing · multi-language · recommendation explainability.
```

⸻

## §14 — Ultra-detailed file-by-file audit

```
Go through EVERY SINGLE FILE in HNAG one by one.

Per file: purpose, code quality, bugs, architecture issues, security
issues, performance issues, scalability issues, maintainability issues,
bad patterns, improvements, refactors, production-grade alternatives.

Rank: worst files, best files, highest-risk files, files needing urgent
rewrite.

Provide: technical debt heatmap, refactor priority order, production-risk
heatmap, launch blockers, engineering roadmap.
```

⸻

## §15 — Recommended audit flow

1. Master audit (§1)
2. Security audit (§5)
3. Backend audit (§3)
4. Frontend audit (§2)
5. Database audit (§4)
6. AI audit (§6)
7. Deployment audit (§7)
8. File-by-file audit (§14)
9. Fix critical → re-run all audits
10. Launch staging → load test → real-user testing → production

⸻

## §16 — Load testing prompt

```
Simulate 10k, 100k, and 1M concurrent users on HNAG.

Analyze what breaks first: API, database, AI, memory, CPU, WebSocket,
cache, queue, session, search bottlenecks.

Provide: scaling plan, infrastructure requirements, Redis strategy, queue
strategy, horizontal scaling plan, AI request optimization, cost estimate
at scale, architecture redesign for millions of users.
```

⸻

## §17 — Startup investor review

```
Act like an investor reviewing HNAG.

Evaluate: product quality, technical moat, AI differentiation,
scalability, UX quality, market readiness, consumer appeal, engineering
quality, viral potential, monetization potential.

Answer: would you invest? biggest weakness? biggest strength? most
impressive part? what kills this startup? what makes this startup win?

Provide /100 scores: investor confidence, product quality, technical
quality, market potential, AI differentiation.
```
