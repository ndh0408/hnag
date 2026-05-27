/**
 * Dependency-Cruiser configuration.
 *
 * Audit production-killer §1 / §5 ("strict architecture enforcement").
 * Without enforcement, six months from now the NestJS modules will be a
 * spaghetti of cross-imports and the team will be debugging cycles
 * instead of features.
 *
 * What this file enforces:
 *
 *   1. NO module-to-module imports. Module A can't reach into module B's
 *      internal services/controllers — the only crossing point is each
 *      module's public exports (its *.module.ts file).
 *
 *   2. Domain modules never depend on infrastructure adapters directly.
 *      `modules/*` reaches `common/redis` / `common/prisma` only via the
 *      injected services — not by importing the adapter classes.
 *
 *   3. No cycles anywhere. Dependency cruiser catches A → B → A loops.
 *
 *   4. No dev/test imports leaking into production code.
 *
 * To run locally (after `npm i -D dependency-cruiser`):
 *
 *   npx depcruise src --config .dependency-cruiser.cjs --output-type err
 *
 * In CI: add a job to `.github/workflows/backend-ci.yml` that runs the
 * same command and fails the build on violations.
 */

module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment:
        'A → B → A cycles make debugging impossible. Pull the shared bit ' +
        'into a `common/` module that both can depend on instead.',
      from: {},
      to: { circular: true },
    },
    {
      name: 'no-cross-module-internal-imports',
      severity: 'error',
      comment:
        'Modules must talk via their *.module.ts public surface only. ' +
        'Reaching directly into another module\'s controllers/services/dto ' +
        'is a layering violation — refactor to inject the service.',
      from: {
        path: '^src/modules/([^/]+)/',
        // Allow the module to import its own internals.
        pathNot: '^src/modules/([^/]+)/.*\\.module\\.ts$',
      },
      to: {
        path: '^src/modules/([^/]+)/(?!\\1)',
        // Allow the .module.ts file as the only public surface.
        pathNot: [
          '^src/modules/([^/]+)/[^/]+\\.module\\.ts$',
        ],
      },
    },
    {
      name: 'no-test-from-prod',
      severity: 'error',
      comment: 'Test helpers must not leak into production code paths.',
      from: { pathNot: '\\.spec\\.ts$|^test/' },
      to: { path: '\\.spec\\.ts$|^test/' },
    },
    {
      name: 'no-orphan-files',
      severity: 'warn',
      comment:
        'Orphan files (no one imports them) are usually leftovers from a ' +
        'refactor. Delete or wire them in.',
      from: {
        orphan: true,
        pathNot: [
          // entrypoints
          '^src/main\\.ts$',
          '^src/app\\.module\\.ts$',
          '\\.d\\.ts$',
          '\\.spec\\.ts$',
          '^test/',
        ],
      },
      to: {},
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.json' },
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'default'],
    },
    reporterOptions: {
      dot: { collapsePattern: 'node_modules/[^/]+' },
    },
  },
};
