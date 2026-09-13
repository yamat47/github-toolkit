---
name: typescript-idioms
description: Background knowledge (not a command) on framework-neutral TypeScript, loaded automatically while writing or reviewing TypeScript. Covers tsconfig (strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes, verbatimModuleSyntax, isolatedModules, erasableSyntaxOnly, module and target), types that make illegal states unrepresentable (unknown over any, discriminated unions, exhaustive switch with never, satisfies versus as, the non-null assertion, as const over enum, branded types, readonly, null at the perimeter), promises and async (floating promises, async handlers in void positions, AbortController, unknown in catch), functions and modules (overloads versus unions, options objects, explicit dependencies, plugin registration), boundaries (schema validation with Zod or Valibot, OpenAPI code generation, feature flags, secrets), typescript-eslint presets and rules, and naming. Use when implementing or reviewing .ts and .tsx files, tsconfig.json, an eslint config, or the script block of a .vue file.
license: MIT
---

# TypeScript idioms

Background knowledge consulted while implementing or reviewing TypeScript code. Each rule is written so a reviewer can check it against a diff. Rules marked as a preference are house style, not language rules. Component structure, reactivity, state management, and UI testing belong to `vue-patterns` and `react-patterns`; this skill covers the language, the compiler, the linter, and the boundaries with the outside world.

## 1. Compiler configuration

- Turn on `strict`. It switches on `strictNullChecks`, `noImplicitAny`, `useUnknownInCatchVariables`, `strictFunctionTypes`, `strictPropertyInitialization`, `strictBindCallApply`, `alwaysStrict`, and every check a later release adds to the set. Do not turn off one member to silence an error; fix the code.
- `noUncheckedIndexedAccess` types `arr[i]` and `obj[key]` as `T | undefined`. One position: turn it on everywhere, because without it the compiler assumes every index access returns a value, which is false. The other position: it is unwieldy in code that has already checked the bounds, and `.at()` returns `T | undefined` on demand without the flag. Check in a diff: with the flag, every index access is narrowed before use; without it, a lookup that can miss goes through `.at()`, `Map#get`, or a return type that says `| undefined`.
- `exactOptionalPropertyTypes` forbids assigning `undefined` to `prop?: T`. Write `prop?: T | undefined` when callers must be allowed to pass it. The flag makes "key absent" and "key present with `undefined`" different types, so the API has to say which one it means.
- `verbatimModuleSyntax` requires `import type` for type-only imports and keeps every other import in the output. `isolatedModules` (with `moduleDetection` set to `force`) rejects `const enum` and other constructs a per-file transpiler (esbuild, swc, a bundler) cannot resolve across files. Turn both on when anything other than `tsc` emits the JavaScript.
- `erasableSyntaxOnly` (5.8) forbids `enum`, `namespace`, and constructor parameter properties, so the same source runs under a runtime that strips types. Turn it on for a new project.
- `module` is `NodeNext` when `tsc` emits for Node and `preserve` (which implies `moduleResolution` set to `bundler`) when a bundler emits. `target` is a concrete year such as `es2022`, never `esnext`, so a compiler upgrade does not change the output.
- Consider `noImplicitOverride`, `noFallthroughCasesInSwitch`, and `noPropertyAccessFromIndexSignature`.
- `typescript` and every `@types/*` package are `devDependencies`. Preference: caret ranges in `package.json` by default; an exact pin carries a comment saying why. The OpenAPI generator in section 5 is one such case.

```ts
type Options = { retries?: number };
const a: Options = { retries: undefined }; // error under exactOptionalPropertyTypes

type Loose = { retries?: number | undefined };
const b: Loose = { retries: undefined }; // allowed: the type says so
```

## 2. Types that make illegal states unrepresentable

### `unknown`, unions, and exhaustiveness

- Never annotate with `any`. It turns off checking at every downstream use. Use `unknown` and narrow with `typeof`, `instanceof`, a type predicate, or a schema. When `any` cannot be avoided (an untyped library, a raw `JSON.parse`), confine it to one function whose signature is fully typed and return a narrowed value; the rest of the code never sees it.
- Model state as a discriminated union, not a bag of optionals. A record with `data?`, `error?`, and `loading` admits combinations that never happen and every reader has to rule them out again.
- Make every `switch` over a union exhaustive with a `never` default. The lint rule `switch-exhaustiveness-check` is not in any typescript-eslint preset; turn it on explicitly (section 6).
- Keep one source of truth for "which values belong to X". Derive the type from an `as const` array and derive the runtime guard from the same array. A type written as `Exclude<...>` plus a hand-written guard listing the members breaks silently when a member is added.

```ts
// BAD
type Result = { data?: User; error?: Error; loading: boolean };

// GOOD
type Result =
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'success'; data: User };
```

```ts
const STATUSES = ['draft', 'published', 'archived'] as const;
type Status = (typeof STATUSES)[number];
const isStatus = (v: string): v is Status => (STATUSES as readonly string[]).includes(v);
```

```ts
function label(status: Status): string {
  switch (status) {
    case 'draft': return 'Draft';
    case 'published': return 'Published';
    case 'archived': return 'Archived';
    default: { const exhaustive: never = status; return exhaustive; }
  }
}
```

### Annotation, `satisfies`, `as`, and `!`

- Use an annotation when the declared type should become the variable's type: parameters, return types, and anything exported.
- Use `satisfies` when a value must conform to a type but its narrower inferred type should survive, such as a route table or a config object whose keys are indexed later.
- `as` does nothing at runtime and lets the code lie to the compiler. Use it only at a boundary where the shape was just checked, and prefer a type predicate or a schema (section 5) even there.
- Treat every `!` as a claim that needs proof. It is one character and easier to miss than `as`. Replace it with a narrowing check or a `throw` that names what was expected. `no-non-null-assertion` is in the `strict` preset.
- Never use the boxed types `Number`, `String`, `Boolean`, `Symbol`, or `Object` as types.

```ts
const routes = { home: '/', about: '/about' } satisfies Record<string, string>;
routes.home; // type is '/'

const loose: Record<string, string> = { home: '/', about: '/about' };
loose.home; // type is string, and loose.missing compiles too
```

### Constants and `enum`

- Prefer an `as const` object plus a derived union over `enum`. Numeric enums accept any number, produce a reverse mapping, and are nominal; `erasableSyntaxOnly` forbids all enums. Where enums already exist, string enums are the lesser problem; do not add new ones.
- A fixed set of values stays behind named constants. Do not replace `ACTION.start` with the literal `'start'` at a call site; the single definition is the point.
- A constants list that repeats a derived value on every item (`category` and `categoryLabel` on each option) is a table with a redundant column. Define the mapping once and reference it.
- Preference: when one entry is both "the generic value" and "the default", define the generic entry in the map with the others and declare the default as a reference to it. They are two facts.

```ts
// BAD
enum Action { Start = 'start', Stop = 'stop' }

// GOOD
const ACTION = { start: 'start', stop: 'stop' } as const;
type Action = (typeof ACTION)[keyof typeof ACTION];
```

### Branded types, `readonly`, and absence

- Use a branded type (`string & { readonly __brand: 'UserId' }`) when structurally identical primitives must not be interchangeable, such as two kinds of id. Caveats: the brand is not checked at runtime, arithmetic on a branded number yields a plain number, and creation needs an `as` or a type predicate inside one constructor function. When the same comparison on a domain value (a graduation year, the start of a week) appears in several places, put the comparison next to the type in one module rather than comparing raw primitives at each call site.
- Mark values that must not be mutated `readonly`, including array parameters the function does not mutate (`readonly T[]`), so the signature carries the promise.
- Push `null` and `undefined` to the perimeter. Handle absence where the value enters (parsing, fetching, form input) and pass non-nullable values inward. Do not put `null` inside a domain type alias.
- A lookup that finds nothing returns `null` or `undefined`, never a sentinel inside the valid range such as `0` or `''`. The same holds for "not yet entered" in form state.
- The absence of a key must not carry a meaning different from `false`. When a backend treats a missing parameter differently from `false`, fix the contract instead of omitting the key on the client.
- Filter out absent values with a type predicate. `filter(Boolean)` does not narrow the element type.

```ts
const isPresent = <T>(v: T | null | undefined): v is T => v != null;
const ids: string[] = maybeIds.filter(isPresent);

// BAD: 0 is a real id
function prefectureId(name: string): number { return TABLE[name] ?? 0; }
// GOOD
function prefectureId(name: string): number | null { return TABLE[name] ?? null; }
```

### When to annotate and when to infer

- Annotate exported function signatures and every type that forms a public API, and export those types so callers do not reconstruct them. Let locals infer; `no-inferrable-types` flags the rest.
- Derive a type instead of re-declaring it. A wrapper that mirrors another module's parameter or property types uses `Parameters<typeof f>[0]`, `ReturnType`, `Pick`, or an indexed access type such as `Props['size']`, so the two cannot drift apart.

## 3. Promises and async

- Every promise is awaited, returned, chained with `.catch` or `.then(onOk, onError)`, or marked with `void` deliberately. A dropped promise drops its rejection. `no-floating-promises` reports this.
- A promise never sits in a boolean position (`if (p)`, `p ? a : b`, `items.filter(async ...)`) and an `async` function is never passed where a `void`-returning callback is expected. `no-misused-promises` reports both. `onClick={async () => ...}` in JSX and `@click="asyncFn"` in a template are the same rule: the caller discards the promise, so a rejection there is unhandled.
- Iterate with `for...of` and `await` for sequential work, or `Promise.all` over `map` for parallel work. `forEach(async ...)` returns before any callback finishes and loses every rejection.
- A function that starts a request accepts `signal?: AbortSignal` and passes it to `fetch` (or the client). The caller creates the `AbortController` and aborts on cleanup or on the next request. Treat an abort as expected, not as an error to report.
- `catch (e)` binds `unknown` under `strict`. Narrow with `instanceof Error` before reading `.message`, and rethrow what you do not recognise.
- Preference: when a function is called in a context it does not support (a browser-only helper during server rendering), throw instead of returning a plausible default. The unexpected call is the bug.

```ts
// BAD
button.addEventListener('click', async () => { await save(); });
ids.forEach(async (id) => { await remove(id); });

// GOOD
button.addEventListener('click', () => { void save().catch(reportError); });
for (const id of ids) await remove(id);
await Promise.all(ids.map((id) => remove(id)));
```

```ts
async function search(query: string, signal?: AbortSignal): Promise<Hit[]> {
  const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`, { signal });
  return Hits.parse(await res.json());
}
```

## 4. Functions and modules

- Prefer one signature with a union or an optional parameter to overloads that differ in one position. When overloads are needed, order them specific before general.
- A callback parameter has a `void` return type when its result is ignored, its own parameters are not optional, and there is one overload with the maximum arity rather than one per arity.
- Take a single options object when the meaning of an argument is not obvious at the call site (`build(report, null)` says nothing) or when the parameter list is likely to grow. Adding a positional parameter later breaks every implementation and mock.
- Pass dependencies in explicitly. A function that reads the current route, the clock, a config value, or a global client inside its body hides coupling; a parameter is both documentation and a test seam.
- A function detects a condition or formats a message, not both. `getLinkedWarning()` returning `string | null` hides two decisions; `isLinked()` and `linkedWarning()` each say what they return.
- A function does only what its name promises. `roundScore` that also returns `''` for zero has a hidden second behaviour; split it or rename it.
- Register library plugins (`dayjs.extend(...)`, a locale, a global interceptor) in one setup module imported once at the entry point. A process-wide side effect at the top of an arbitrary module makes it impossible to know which extensions apply to a given file.
- Use the platform before writing a parser: `URL` and `URLSearchParams` for query strings, `Intl` for formatting, `structuredClone` for deep copies.
- Remove unused imports and delete code rather than commenting it out. A commented-out import leaves the reader unsure whether the feature still works.
- A function extracted into its own module gets a unit test, including the case where several optional inputs are supplied together; that combination is where readers guess wrong. Do not mock the library the function wraps; feed it realistic inputs so the test still guards the wrapper after an upgrade. Tests of components, hooks, and composables belong to the framework skills.
- Preferences: one function per file so the test layout mirrors the code; a `types/` directory holds only types, and type guards live beside the runtime code they serve; split a file once it holds more than one reader can follow.

```ts
// BAD
interface DeviceClient { get(deviceId: string, includeInactive?: boolean): Promise<Device>; }
function isDueThisWeek(due: Date): boolean { return dayjs(due).isSame(dayjs(), 'week'); }

// GOOD
interface DeviceClient { get(options: { deviceId: string; includeInactive?: boolean }): Promise<Device>; }
function isDueThisWeek(due: Date, now: Date): boolean { return dayjs(due).isSame(now, 'week'); }
```

## 5. Boundaries

- Validate input the code does not control (third-party API responses, form data, URL parameters, environment variables) with a schema and derive the type from the schema. Writing the type by hand next to the schema is the same fact twice. A response from your own backend, typed by a client generated from its schema, needs no second schema.
- Use `safeParse` for failures the program expects (user input, an external response that can be malformed) and `parse` where a failure is a bug.
- Zod has the larger ecosystem of integrations; Valibot fits when bundle size dominates, and the size figures that show it as a fraction of Zod come from Valibot's own comparison.
- Generate API types and clients from the OpenAPI document. Never write a response type by hand when a document exists; the generator does the refactors for free. Pin the generator to an exact version, regenerate in CI, fail the build when the output differs from what is committed, and never hand-edit generated files.
- A type or key list that mirrors a third-party API carries a comment naming the provider documentation it was copied from; that is the only place it can be verified.
- Evaluate feature flags through a typed flag API with a mandatory default that is returned when evaluation fails. Never hard-code user ids or modulo arithmetic on an id as a rollout. When the flag is off, skip the work entirely: no request, no assignment, no result discarded afterwards. Remove debug output before the flag is turned on, or leave a TODO saying when it goes. Test both paths, and delete the flag and the dead branch once the rollout is complete; a flag is inventory with a carrying cost.
- Never keep an API key or secret as a code constant, not even as an empty placeholder with a "fill in before use" comment; that placeholder is where the real key gets pasted and committed. Read secrets from the environment or a runtime configuration and validate them with a schema at startup.

```ts
const User = z.object({ id: z.string(), email: z.string() });
type User = z.infer<typeof User>;

const result = User.safeParse(await res.json());
if (!result.success) return showErrors(result.error);
return result.data;
```

```ts
// BAD
const rolledOut = ALLOWLIST.includes(user.id) || user.id % 10 === 0;
const fetched = await fetchSuggestions(); // work done even when the flag is off
const suggestions = rolledOut ? fetched : [];

// GOOD
const showSuggestions = await flags.getBoolean('search-suggestions', false);
const suggestions = showSuggestions ? await fetchSuggestions() : [];
```

## 6. Lint

- `recommended-type-checked` is the floor. `strict-type-checked` is reasonable when most of the team is proficient in TypeScript; it is not semver-stable and type-aware linting is slower, so decide it once per repository.
- Keep `no-floating-promises` and `no-misused-promises` at error. They are the compile-time check for section 3.
- `no-unnecessary-condition` (in `strict-type-checked`) reports a condition the types already decide. When it fires, either the type is wrong (a lookup typed as always present) or the check is dead; fix whichever is true rather than disabling the rule.
- Enable `switch-exhaustiveness-check` explicitly; no preset includes it.
- `consistent-type-imports` versus `verbatimModuleSyntax`: one position is the lint rule, which autofixes and needs no compiler change; the other is the compiler flag, which holds in every editor and build without a lint run. Enabling both produces duplicate reports. Check in a diff: exactly one of the two is active.
- `prefer-nullish-coalescing`, `prefer-optional-chain`, and `consistent-type-definitions` live in `stylistic-type-checked`, not in `strict`; opt in when the team wants them.
- Every disabled rule, whether in the config or inline, has a comment saying why. A rule turned off to keep a diff small gets a date for turning it back on; a rule left off for convenience becomes permanent.
- Formatting preferences (one import specifier per line, quote style) go into the formatter or linter config, never into review comments.

## 7. Naming

- A boolean or predicate reads as an unambiguous question with a subject: `isPublished`, `hasSeats`, `canEdit`. A predicate function is `isStatus`, not `checkStatus`. `pending` or `triggered` alone do not say what is true about what.
- Avoid a domain word that means several things in the product. `canSkipReview` needs a sentence of explanation when "review" names three processes; name the specific actor or process.
- A function that mutates state carries a command name (`publishArticle`, `resetFilters`). A getter-like name (`articleStatus`) on a function that writes misleads every caller.
- Make an identifier specific enough not to collide or need its file for meaning: `parseEventDate`, not `parse`; `EVENT_PAGE_SIZE`, not `SIZE`.
- Constants are `SCREAMING_SNAKE_CASE` (`FIRST_VIEW_COMPANY_COUNT`), so a fixed value looks fixed.
- Preference: lookup-table keys are ASCII identifiers; display strings belong in the values.

## Checklist

- [ ] Is `strict` on, and is every deviation from the strictness set (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `verbatimModuleSyntax`) a deliberate, documented choice?
- [ ] Does any `any`, `as`, or `!` appear where `unknown`, a type predicate, a schema, or a narrowing check would do?
- [ ] Is state a discriminated union, and does every `switch` over a union end in a `never` default?
- [ ] Is each set of allowed values defined once (an `as const` array or object) with the type and the runtime guard derived from it?
- [ ] Does any function return a sentinel (`0`, `''`) for absence, or treat a missing key differently from `false`?
- [ ] Is every promise awaited, returned, or explicitly `void`ed, and is no `async` function passed as a click handler or other `void` callback?
- [ ] Does any `forEach(async ...)` remain, and does every request accept an `AbortSignal`?
- [ ] Are non-obvious or growing parameter lists an options object, and are the clock, route, config, and clients passed in rather than read inside?
- [ ] Does any function both detect a condition and format its message, or do more than its name promises?
- [ ] Is a library plugin registered outside the single setup module?
- [ ] Is untrusted input parsed with a schema whose type is derived, and are API types generated from the OpenAPI document with a pinned generator?
- [ ] Is every feature flag read through the flag API with a default, does the off path skip the work, and is the flag scheduled for removal?
- [ ] Is a secret, even a placeholder, present as a code constant?
- [ ] Does every disabled lint rule carry a reason, and is exactly one of `consistent-type-imports` and `verbatimModuleSyntax` active?
- [ ] Does every boolean, predicate, and mutating function read unambiguously, and are constants `SCREAMING_SNAKE_CASE`?
