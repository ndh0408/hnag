// =============================================================================
// HNAG backend — flat ESLint config.
//
// Goal: enforce the module-boundary rule that NestJS DI is already supposed
// to give us, but that nothing in the codebase actually checks. Without this,
// it's trivially easy to write:
//
//     // in modules/posts/posts.service.ts
//     import { AuthService } from '../auth/auth.service';  // ← BAD
//
// which sidesteps the auth.module.ts barrel, breaks tree-shaking, makes the
// import graph cyclical-prone, and quietly bypasses anything auth.module.ts
// promised to gate (guards, interceptors, etc.).
//
// The rule below blocks any cross-module deep import. Modules MUST depend on
// each other through their .module.ts file — i.e. add the OtherModule to
// imports[], then inject the service via its constructor.
// =============================================================================
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';

export default [
  // Ignore generated + vendored output
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'coverage/**',
      'prisma/migrations/**',
      '**/*.tsbuildinfo',
    ],
  },

  // TypeScript source
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parser: tsparser,
      parserOptions: { ecmaVersion: 2022, sourceType: 'module' },
    },
    plugins: { '@typescript-eslint': tseslint },
    rules: {
      // ── Module-boundary enforcement ────────────────────────────────────
      //
      // Block deep imports from sibling modules. The only allowed shapes
      // for cross-module dependencies are:
      //
      //   1. The other module's barrel (`../other-module`, or its .module.ts
      //      explicitly imported in YOUR .module.ts file's `imports:` array)
      //   2. Anything under `common/` (shared infra: prisma, redis, auth helpers)
      //
      // Patterns are interpreted by import/no-restricted-paths-style globs.
      // Forbidding `../<module>/services/...` covers the most common offender.
      'no-restricted-imports': ['error', {
        patterns: [
          {
            // Block any deep import into another module's services / dto /
            // controllers. This is what NestJS DI is supposed to prevent
            // anyway — the only legal way to depend on sibling code is to
            // import the other Module class in your own module.ts.
            group: [
              '../*/services/*',           // siblings of the same module dir
              '../../*/services/*',         // sibling modules at modules/*
              '../../*/*.service',          // modules/X/X.service from modules/Y
              '../../*/*.controller',
              '../../*/dto/*',
            ],
            message:
              'Cross-module deep imports break NestJS DI boundaries. Add the other ' +
              'module to your module.ts imports[] and inject the service via the ctor. ' +
              'common/* is the only shared infra layer that may be imported anywhere.',
          },
        ],
      }],

      // ── General quality gates ──────────────────────────────────────────
      // Floor; not aiming for max-strict. These are the few that have
      // actually bitten the codebase per past review comments.
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-debugger': 'error',
      'no-unused-vars': 'off', // handled by @typescript-eslint
      '@typescript-eslint/no-unused-vars': ['warn', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],
      'prefer-const': 'warn',
      'no-var': 'error',
      'eqeqeq': ['error', 'smart'],
    },
  },

  // Tests are allowed everything
  {
    files: ['src/**/*.spec.ts', 'test/**/*.ts'],
    rules: {
      'no-restricted-imports': 'off',
      'no-console': 'off',
    },
  },
];
