---
name: react-patterns
description: Background knowledge (not a command) on React 19 with the React Compiler, Next.js App Router, and React Native with Expo. Covers state (what is state, colocation, status unions over booleans, ids over copies, no mirrored props, feature flags from the flag API), effects (You Might Not Need an Effect, dependencies, cleanup, the ignore flag, useEffectEvent), the Rules of React and hooks with eslint-plugin-react-hooks, React 19 APIs (ref as a prop, Context as provider, useActionState, useOptimistic, use), memoisation under the compiler, component splitting and naming, error boundaries, server state with query keys and staleTime, Zustand and Jotai, Server Components, use client, server-only, Server Actions, FlatList and native-thread animations, React Testing Library, React Native Testing Library, Playwright, and accessibility. Use when implementing or reviewing .tsx or .jsx components, hooks, Next.js route files and Server Actions, Expo Router screens, or their tests.
license: MIT
---

# React patterns

Background knowledge consulted while implementing or reviewing React code: web components, Next.js App Router files, and React Native screens built with Expo. Each rule is written so a reviewer can check it against a diff. Rules marked as a preference are house style, not React rules. Language-level TypeScript rules (compiler flags, `unknown` over `any`, discriminated unions, promise handling including `onClick={async ...}`, schema validation, OpenAPI code generation, lint presets) are in `typescript-idioms`; the Vue counterpart of this skill is `vue-patterns`. This skill does not repeat either.

## 1. State

- Keep a value in state only when it changes over time, does not arrive as a prop, and cannot be computed from other state or props. Everything else is a plain expression in render.
- Put state in the component that uses it. Lift it to the closest common parent only when a second component reads it, and pass the setter down as a callback. Colocation removes the re-renders that `memo` would otherwise have to suppress.
- Keep search, filter, and form state in the component or its hook unless another part of the app reads it. A store is not the default location.
- Group values that change together into one object. Replace booleans that can contradict each other (`isLoading`, `isError`, `isSuccess`) with a status union.
- Store the id of a selected item, not a copy of the item. The copy goes stale when the list changes.
- Do not mirror a prop into state. When the prop is only a starting value, name it `initialX` or `defaultX` so the contract is visible.
- Do not put server data in `useState`. Server state (anything fetched, cached, and owned by the backend) lives in a query library; the client state that remains is small.
- Reach for context late: lift first, use context for values many distant components read, and an external store last. Several small providers placed near their readers, not one provider at the root.
- Feature flags come from the flag mechanism; the rules are in `typescript-idioms`. A flag value copied into the client needs a release to change and is invisible to everyone else. The flag response can carry more than a boolean (a list of enabled users, a variant name).

```tsx
// BAD
const [isLoading, setIsLoading] = useState(false);
const [isError, setIsError] = useState(false);
const [selected, setSelected] = useState<Company | null>(null);

// GOOD
type Status = 'idle' | 'loading' | 'success' | 'error';
const [status, setStatus] = useState<Status>('idle');
const [selectedId, setSelectedId] = useState<Company['id'] | null>(null);
const selected = companies.find((c) => c.id === selectedId) ?? null;
```

## 2. Effects

An effect synchronises the component with something outside React (a subscription, a DOM library, analytics). Ask of every `useEffect` whether the code runs because the component was displayed or because something specific happened. Only the first is an effect; the second is an event handler.

Things that are not effects:

- Deriving data from props or state. Compute it in render. When the computation is measurably expensive and the compiler is not on, `useMemo`.
- Resetting state when a prop changes. Give the component a `key` from the parent so React remounts it.
- Adjusting state when a prop changes. Compare against the previous value during render (rare), or restructure so the value is derived.
- A request or mutation the user triggered (a POST on submit). It belongs in the handler.
- A chain of effects where each sets state that triggers the next. Compute the whole update in one handler.
- Notifying a parent or passing data up. Call the callback in the handler that changed the state; let the parent own the state when both need it.
- App initialisation that must run once. Guard it at module scope, not with an empty dependency array.
- Subscribing to an external store. `useSyncExternalStore`.

Rules for the effects that remain:

- Every reactive value read inside the effect is a dependency. Never suppress the lint rule; when a dependency is unwanted, change the code so it is not needed (move the object or function inside the effect, or use `useEffectEvent`).
- Cleanup undoes what setup did: unsubscribe, abort, disconnect. Strict Mode runs setup, cleanup, setup in development to expose a missing cleanup.
- A fetch in an effect needs an `ignore` flag (or an `AbortController`) set in cleanup so a slow earlier response cannot overwrite a later one. Prefer the framework loader or the query library over a hand-written fetch effect.
- Read the latest props or state without re-running the effect through `useEffectEvent` (stable in React 19.2, requires the current lint plugin). Do not stash a handler in a ref to get the same result.
- No `useMount`, `useEffectOnce`, or `useUpdateEffect` wrappers. They hide dependencies from the lint rule and from the reader.

```tsx
// BAD
useEffect(() => { setFullName(`${first} ${last}`); }, [first, last]);
useEffect(() => { setComment(''); }, [userId]);

// GOOD
const fullName = `${first} ${last}`;
<Profile userId={userId} key={userId} />
```

```tsx
useEffect(() => {
  let ignore = false;
  void loadResults(query).then((results) => {
    if (!ignore) setResults(results);
  });
  return () => { ignore = true; };
}, [query]);
```

## 3. Rules of React and hooks

- Components and hooks are pure: same props and state, same output, no side effects during render. Side effects happen in handlers and effects.
- Props, state, hook arguments, and hook return values are immutable. Do not mutate a value after passing it to JSX or a hook; create a new object.
- Never call a component as a function (`Row(props)`); render it (`<Row {...props} />`). Never define a component inside another component's body; it remounts on every render.
- Call hooks only at the top level of a component or another hook, never in conditions, loops, or nested functions. `use` is the one exception (section 4).
- A function is named `useX` when and only when it calls hooks. A helper without hooks is a plain function.
- Hooks share logic, not state. Two components calling `useFilter()` get two independent states; when they need one, lift it.
- Name a hook for its purpose (`useCompanySearch`, `useChatRoom`), not for its mechanism (`useAsync`, `useData`).
- Turn on Strict Mode and `eslint-plugin-react-hooks` with `rules-of-hooks` and `exhaustive-deps` as errors. Version 6 adds compiler-derived rules (`set-state-in-effect`, `set-state-in-render`, `refs`, `purity`, `immutability`, `static-components`, `error-boundaries`, `preserve-manual-memoization`). The plugin reference lists them under `recommended`; the React 19.2 release notes call them opt-in. Check which rules the installed version's `recommended` config turns on, and enable the compiler-derived set explicitly when it does not.

## 4. React 19 and the compiler

- `ref` is a prop on function components. New code does not use `forwardRef`; flag it in a diff.
- A ref callback returns nothing or a cleanup function. An implicit arrow return (`ref={(el) => (nodes[id] = el)}`) is a type error under React 19; use a block body.
- Render a context as `<ThemeContext value={theme}>`; `.Provider` is the legacy spelling.
- A mutation that tracks pending and error state uses `useActionState` with `<form action>`, and `useFormStatus` inside the form for the pending flag, instead of hand-rolled `isPending` and `error` state around `fetch`. `useOptimistic` shows the expected result while the action runs and reverts on failure.
- `use(promise)` reads a promise under `<Suspense>`. The promise is created outside render (passed from a Server Component or cached); a promise created in render is recreated every render and never settles for React. Errors surface through the nearest error boundary, not a `try`/`catch` around `use`. Unlike other hooks, `use` can be called conditionally. Do not read `promise.status` yourself.
- Register `onCaughtError` and `onUncaughtError` on `createRoot` so render errors reach the error tracker.

Memoisation under the compiler:

- New code does not add `useMemo`, `useCallback`, or `memo`. The compiler memoises; a manual call is justified only for precise control, such as keeping an effect dependency stable, and says so in a comment.
- Existing memoisation stays. The compiler documentation says removing it can change compilation output and asks for a test or measurement before removal; the pre-compiler guidance still presents `useMemo` as the tool for an expensive derivation. In a diff, check that a removed `useMemo` or `memo` comes with a measurement or a test, and that an added one names the reason.
- A component the compiler must skip (an incompatible library, a deliberate impurity) carries `"use no memo"` at the top of the function with the reason next to it.

```tsx
// BAD
const Input = forwardRef<HTMLInputElement, Props>((props, ref) => <input ref={ref} {...props} />);
<div ref={(el) => (nodes.current[id] = el)} />
<ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>

// GOOD
function Input({ ref, ...props }: Props & { ref?: Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
<div ref={(el) => { nodes.current[id] = el; }} />
<ThemeContext value={theme}>{children}</ThemeContext>
```

```tsx
const [error, submitAction, isPending] = useActionState(
  async (_previous: string | null, formData: FormData) => {
    const result = await renameCompany(String(formData.get('name')));
    return result.ok ? null : result.message;
  },
  null,
);
```

## 5. Components

- One component has one responsibility. Split a screen or page that fetches, derives, and renders several regions into a component per region, and move data fetching and derived state into hooks in their own files. A screen file that is never split keeps growing.
- Name a component for what it is (`CompanyCard`, `EventList`), not for where it appears or which version it is. A numeric suffix (`CompaniesScreen2`) marks an unfinished migration; plan its removal when the old one goes.
- Pass the whole domain object as a prop (`company={company}`), not an id plus a name plus a status that must stay in sync at every call site.
- Model a domain concept as an object with predicate methods (`contract.isFreePlan()`, `event.hasStarted()`) rather than free helper functions scattered across components. The predicate lives once and is tested once.
- Preference: name a boolean prop for the capability the caller sees (`isCancelable`), not for the implementation detail (`showCancelButton`).
- Pass call-site-dependent values (tracking parameters, labels, destinations) in from the caller. A shared component that branches on where it was rendered grows one branch per call site.
- A callback prop fires on the event it names. `onScrollEnd` fires once when the end is reached, not on every scroll event.
- When new code duplicates logic that exists elsewhere (a remaining-time calculation, a formatter), share it, in the same PR or a named follow-up.
- Name a configuration constant so its value cannot be misread: `SESSION_SAMPLING_PERCENT = 1`, not `SESSION_SAMPLING_RATE = 1` with a comment saying it means one percent.
- A constant sent verbatim to analytics is data other people filter on. Renaming it breaks their dashboards; tell the consumers in the PR.
- `console.warn` or `console.error` in a shipped app is not error handling; nobody reads it. Route the error to the error tracker, or write down what the log achieves.
- Error boundaries catch render errors only, not handler errors, async errors, or server-side errors (errors inside `startTransition` are caught). Place one where a meaningful fallback exists (a widget, a route), not around every leaf.

```tsx
// BAD
<CompanyCard companyId={company.id} companyName={company.name} isPremium={company.plan === 'premium'} />
<ConfirmDialog showCancelButton onConfirm={submit} />

// GOOD
<CompanyCard company={company} />
<ConfirmDialog isCancelable onConfirm={submit} />
```

## 6. Server state and stores

Server state in a query library (TanStack Query):

- The query key is the dependency array of the `queryFn`: every value the function reads is in the key, so a change refetches and two callers with the same inputs share one cache entry.
- One custom hook per query (`useCompany(id)`), so key, function, and options live in one place. A dependent query uses `enabled`, not a conditional hook call.
- Set `staleTime` deliberately. The default is zero, which refetches on every mount, focus, and reconnect; permissions and feature flags take `'static'` or a long value.
- Do not copy query data into `useState`. Read it from the hook. The one exception is initial form values, named as such.
- `setQueryData` is for optimistic updates only; other writes go through a mutation and invalidation.
- Preference: do not add defensive parsing for a fixed-format value your own backend returns under a generated type. The type already states the shape; a schema is for input you do not control.

```tsx
function useCompany(id: string) {
  return useQuery({
    queryKey: ['company', id],
    queryFn: () => fetchCompany(id),
    staleTime: 5 * 60 * 1000,
  });
}
```

Client stores:

- Zustand: select atomic slices (`useStore((s) => s.count)`). Selecting the whole store re-renders the component on every change. Use `useShallow` when a selector returns an object or array. Actions live inside the store, next to the state they change.
- Jotai fits when atoms replace `useState` plus context pairs, when state must split with the code that uses it, or when a Suspense-based async value is wanted; Zustand fits one module-level store with actions. Define atoms at module scope so their identity is stable.
- Preference: when a directory follows a library idiom whose name collides with a project term (`src/atoms` for Jotai atoms next to atomic-design components), add a one-line comment saying which meaning applies.

```tsx
// BAD
const { items, open } = useCartStore();

// GOOD
const count = useCartStore((s) => s.items.length);
const { open, close } = useCartStore(useShallow((s) => ({ open: s.open, close: s.close })));
```

## 7. Next.js App Router

- Components are Server Components by default. Add `'use client'` only at the interactive leaves (state, handlers, effects, browser APIs). Every module a client module imports becomes client code, so the directive sits as low in the tree as possible.
- A Server Component can be passed into a Client Component as `children` or a prop. A context provider is a Client Component that wraps `children`, rendered as deep as it can be.
- Props that cross the server-to-client boundary are serialisable: no functions, class instances, or whole database records.
- `import 'server-only'` at the top of a module that reads secrets or the database, so a client import fails at build time. Only `NEXT_PUBLIC_` variables reach the client, and only the data access layer reads `process.env`. The data access layer returns DTOs shaped for the UI, not ORM rows.
- `fetch` is not cached by default. Use `'use cache'` for data that can be shared, `<Suspense>` close to the uncached data for streaming (finer than a route-level `loading.js`), and `React.cache` around ORM calls that repeat within one request.
- Start independent requests before awaiting any of them (`Promise.all`, or a preload call) instead of one `await` after another.
- Every Server Action is a public POST endpoint. It authenticates and authorises inside its own body; a check on the page that renders the form is not a boundary. It validates `FormData` and parameters with a schema, accepts ids and loads the records itself (schema validation checks shape, not ownership), returns only what the UI needs, and calls `revalidatePath` or `updateTag` before `redirect`, which throws.
- The client dispatches actions one at a time; `Promise.all` over several actions runs them sequentially anyway.

```tsx
'use server';
export async function archiveCompany(companyId: string) {
  const user = await requireUser();
  const company = await findOwnedCompany(companyId, user.id);
  if (!company) notFound();
  await archive(company.id);
  revalidatePath('/companies');
  redirect('/companies');
}
```

## 8. React Native and Expo

- New projects use Expo Router: file-based routes under `app/`, `_layout` files, typed routes, deep links generated from the file tree.
- The New Architecture is the default since React Native 0.76 and Expo SDK 52 and mandatory from SDK 55. A dependency without New Architecture support blocks the upgrade; check it with `npx expo-doctor` and the React Native directory before adding it. Synchronous measurement goes in `useLayoutEffect`.
- Long lists use `FlatList` (with `getItemLayout` when row heights are known) or a virtualised list library, never `ScrollView` with `map`.
- Animations run on the native thread (`useNativeDriver: true`, or a native-thread animation library) and animate `transform` and `opacity`, not `width` or `height`, which trigger layout.
- Measure performance in a release build; a development build measures the developer tooling. Strip `console.log` from release builds. Heavy work in `onPress` goes behind `requestAnimationFrame` so the touch feedback renders first.
- Changes with a wide blast radius get a real-device check before merge, on every path and not only the happy one: native build configuration (the Podfile, Gradle files, config plugins), login and post-login flows, and the crash-reporting integration (send a test event and confirm it arrives). Temporarily changing a staging response is a fair way to exercise a path such as a forced-update screen.
- Changing the minimum supported OS version drops users. It is a product decision; confirm it with the product owner before merging.
- The web sections apply unchanged: state, effects, hooks, query library, stores.

```tsx
// BAD
<ScrollView>{events.map((event) => <EventRow key={event.id} event={event} />)}</ScrollView>

// GOOD
<FlatList
  data={events}
  keyExtractor={(event) => event.id}
  renderItem={({ item }) => <EventRow event={item} />}
/>
```

## 9. Testing UI code

- A test resembles how the software is used: it renders the component and interacts through the DOM (React Testing Library) or the native element tree (React Native Testing Library), not through component instances or implementation details. No shallow rendering.
- Query in this order: `getByRole` (with `name`), `getByLabelText`, `getByPlaceholderText`, `getByText`, `getByDisplayValue`, `getByAltText`, `getByTitle`, and `getByTestId` last. Use `screen`, and never `container.querySelector`.
- Interact with `userEvent.setup()`, not `fireEvent`; it dispatches the full sequence of events a user produces.
- Wait with `await screen.findBy...`, not `waitFor(() => getBy...)`. `queryBy*` is only for asserting absence. No side effects or several assertions inside `waitFor`, and no manual `act`.
- Unit-test hooks with `renderHook` and pure logic (predicates, formatters, reducers) directly; that is where the edge cases live and the tests are cheap. Most other tests are integration tests of a component with its children and minimal mocking.
- Critical flows get a Playwright test: role or text locators, never CSS or XPath; web-first assertions (`await expect(locator).toBeVisible()`), never an un-awaited `isVisible()`; third-party services mocked; traces kept on CI.
- A jsdom test proves behaviour in a simulated browser; a browser-mode test or an end-to-end test proves it in a real one. Neither replaces the other.

```tsx
// BAD
fireEvent.click(container.querySelector('.save')!);
await waitFor(() => expect(screen.getByText('Saved')).toBeInTheDocument());

// GOOD
const user = userEvent.setup();
await user.click(screen.getByRole('button', { name: 'Save' }));
expect(await screen.findByText('Saved')).toBeInTheDocument();
```

## 10. Accessibility

- Use the native element before ARIA: `<button>`, `<a href>`, `<input>`, `<select>`, `<dialog>`. Do not change a native element's semantics with `role`. No ARIA is better than bad ARIA.
- Every control has a label: `<label htmlFor>` paired through `useId()`, or `aria-label` when a visible label is impossible. A placeholder is not a label.
- A `<button>` for an action, an `<a>` for navigation. A `div` with `onClick` is neither, and the keyboard cannot reach it. Give every `<button>` a `type`.
- Every interactive element is keyboard-operable: reachable by Tab, activated by Enter or Space, dismissible by Escape when it is a dialog or menu. A custom widget with an ARIA role promises the keyboard behaviour of that role.
- Never `aria-hidden` or `role="presentation"` on a focusable element. Hide visually with CSS instead.
- Headings descend in order without skipping levels; landmarks (`main`, `nav`) mark the page regions.
- Write `aria-*` attributes as in HTML (`aria-describedby`, not `ariaDescribedBy`).
- In React Native, set `accessibilityRole`, `accessibilityLabel`, and `accessibilityState` on `Pressable` and image elements so the screen reader announces what the control does.

```tsx
function EmailField() {
  const id = useId();
  return (
    <>
      <label htmlFor={id}>Email</label>
      <input id={id} type="email" autoComplete="email" />
    </>
  );
}
```

## Checklist

- [ ] Is every `useState` a value that changes over time, is not a prop, and cannot be computed? Are contradictory booleans a status union, and selections stored as ids?
- [ ] Is state kept in the component that uses it, with server data in the query library and no query data copied into state?
- [ ] Does any `useEffect` derive data, reset state on a prop change, run a user-triggered request, chain into another effect, or notify a parent?
- [ ] Does every effect list its reactive values, clean up what it set up, and guard fetches with an `ignore` flag or `AbortController`? Is any lint rule suppressed?
- [ ] Are hooks at top level, named `useX` only when they call hooks, and named for purpose rather than mechanism?
- [ ] Does the diff add `forwardRef`, `.Provider`, an implicit-return ref callback, or hand-rolled pending state where `useActionState` fits?
- [ ] Is every new `useMemo`, `useCallback`, or `memo` justified in a comment, and every removed one backed by a test or measurement?
- [ ] Is each component one responsibility, named for what it is, given the whole domain object, and free of branches on its call site?
- [ ] Is a feature flag, allowlist, or rollout percentage hard-coded in the client?
- [ ] Is a runtime error logged with `console.warn` instead of reaching the error tracker?
- [ ] Does every query hook include all inputs in its key and set `staleTime` deliberately? Does any Zustand selector return the whole store?
- [ ] Is `'use client'` at the leaves, are boundary props serialisable, and does every Server Action authenticate, authorise, validate, and accept ids inside its body?
- [ ] Does a long list use `ScrollView`, does an animation touch `width` or `height`, and was a native-config, login, or crash-reporting change checked on a real device?
- [ ] Do tests query by role or label, use `userEvent`, and `await findBy*` instead of `waitFor(getBy*)`?
- [ ] Does every control have a label, every action a `<button>`, every navigation an `<a>`, and is every interactive element reachable by keyboard?
