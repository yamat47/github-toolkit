---
name: vue-patterns
description: Background knowledge (not a command) on Vue 3 Composition API, Pinia, and Nuxt 4 conventions, loaded automatically while writing or reviewing Vue code. Covers single-file components (multi-word names, key on v-for, no v-if with v-for, scoped styles, splitting by responsibility, the whole domain object as a prop), props and emits (defineProps, defineEmits, defineModel, reactive props destructure, no prop mutation), reactivity (computed, watch, watchEffect, onWatcherCleanup, shallowRef, useTemplateRef), composables (useXxx, toValue, MaybeRefOrGetter, domain objects with predicates), state (local first, provide and inject, Pinia setup stores, storeToRefs, useState, SSR module-scope state, feature flags), Nuxt 4 (auto-imports, useFetch, useAsyncData, $fetch), errors (errorHandler, onErrorCaptured), testing with Vue Testing Library and Playwright, and accessibility. Use when implementing or reviewing .vue single-file components, composables, Pinia stores, Nuxt pages, layouts, plugins, or their tests.
license: MIT
---

# Vue patterns

Background knowledge consulted while implementing or reviewing Vue 3 code. Each rule is written so a reviewer can check it against a diff. Rules marked as a preference are house style, not Vue rules. Language-level TypeScript (compiler flags, `unknown` over `any`, discriminated unions, the promise rules that also cover `@click` on an async function, schema validation, OpenAPI code generation) is in `typescript-idioms`; the React versions of the framework rules are in `react-patterns`. Neither is repeated here.

## 1. Components

- Give every component a multi-word PascalCase name (`TodoItem`, not `Todo`) so it can never collide with a current or future HTML element. Declare props in camelCase and write them in kebab-case in templates.
- One component per file, and the file is named for what the component is. A footer block is not `FooterPage.vue`; a component that renders one variant carries the variant in its name.
- Declare props with a type-based `defineProps<Props>()` that states the element type of every array and the shape of every object. A bare `Array` or `Object` tells the reader nothing.
- Put a `:key` on every `v-for`. The key is stable and unique among siblings: an id, never an index or a measured value such as a height.
- Never put `v-if` and `v-for` on the same element. Filter in a `computed` or wrap the element in `<template v-for>`.
- Scope styles with `<style scoped>` or CSS modules in every component except the root. Even then, give class names that are specific to the component (`event-related-link`, not `link`); `:deep` selectors and global styles cross the boundary.
- Split a component that has grown past one screen by single responsibility. A loosely coupled part such as an input with suggestion search becomes its own component that emits events. A root component that has collected page-level concerns (metadata, tracking) is decomposed the same way.
- A component never inspects its caller's context to decide its own behaviour: no `route.path === '/candidates'` inside a summary component. Pass the fact as a prop, or let the injection expose whether a value was provided. The callee knowing the caller is the wrong direction of dependency.
- Pass the whole domain object as a prop, not an id plus a name that must stay in sync. Separate props let a caller pass a mismatched pair; one object cannot.
- Preference: a reusable component takes whole display strings as props rather than interpolating a fragment into a fixed phrase inside the component. Decide how generic the component is before writing it.
- A boolean prop that hides part of the component (`showRelatedLinks`) exists only when a caller uses the hiding path. Delete the prop otherwise; each optional branch is code to maintain.
- Preference: when one component serves two modes with branches throughout (`mode === 'weekly'`), split it into one component per mode, or introduce a more abstract component that takes the mode. A parent that knows "in this mode show this" knows too much about the child. The same test applies before sharing a component across variants: every variant-specific branch multiplies what has to be verified.
- When sibling elements must share one style, define it once as a component or a class instead of repeating the same props on each element; repetition lets one sibling drift.
- Keep template expressions simple and move logic into `computed`. Pass a constant string as a plain attribute (`page-type="list"`), not a bound expression (`:page-type="'list'"`).
- Preference: state lives in script and appearance lives in CSS. Toggle a class (`:class="{ 'is-opened': opened }"`) rather than computing colours or borders in a `:style` object, use classes for static styling, and take colours from the design tokens rather than raw hex values.
- Preference: bind declaratively rather than driving the DOM imperatively. `querySelectorAll('.editor > h2')` against a library's markup is fragile; when it cannot be avoided, wrap the library in one module, and cover that module with unit tests so an upgrade does not need manual verification.

```vue
<!-- BAD -->
<li v-for="item in items" v-if="item.active" :key="item.id">{{ item.name }}</li>

<!-- GOOD -->
<script setup lang="ts">
const activeItems = computed(() => items.value.filter((item) => item.active))
</script>
<template>
  <li v-for="item in activeItems" :key="item.id">{{ item.name }}</li>
</template>
```

```ts
// BAD
const props = defineProps<{ categoryId: number; categoryName: string }>()

// GOOD
const props = defineProps<{ category: Category }>()
```

## 2. Props, emits, and models

- Data flows one way. Never assign to a prop or mutate a nested object inside one; `vue/no-mutating-props` catches the first, review catches the second. A prop used as an initial value is copied into a local `ref`; a prop that needs transforming goes through a `computed`; a change the parent must know about is emitted.
- Declare props either type-based or at runtime, not both. Give defaults with reactive props destructure (`const { label = 'Total' } = defineProps<Props>()`) in Vue 3.5, or `withDefaults` on older versions, with a factory function for an object or array default.
- Destructure `props` only on Vue 3.5 or later, where the transform is on by default; before that the destructured value is a snapshot (`vue/no-setup-props-reactivity-loss`). When a destructured prop goes to `watch` or into a composable, pass a getter (`() => count`); a destructured prop passed by value is a plain value, not a reactive source.
- Type emits with the named tuple syntax and declare every event the component emits (`vue/require-explicit-emits`). An undeclared event falls through to the root element as a native listener.
- Use `defineModel()` for `v-model`. Do not combine `defineModel({ default })` with a parent that may pass `undefined`: the child shows the default while the parent holds `undefined`, and the two disagree until the first change.
- Preference: selection state belongs to the parent. An option or item component does not know the currently selected value, the way an `<option>` does not know its `<select>`.
- Preference: name a boolean prop or CSS state class as a state (`opened`, `is-opened`), not an action (`open`); name a boolean by the meaning it carries (`hasMoreItems`), not by the widget that reads it (`isShowMoreButton`); name a handler as noun plus intransitive verb (`onTitleChange`, not `onChangeTitle`).
- Use props and events, never `$parent` or a shared mutable object, to talk between parent and child.

```ts
const { count, label = 'Total' } = defineProps<{ count: number; label?: string }>()
const emit = defineEmits<{ change: [id: number]; close: [] }>()
const query = defineModel<string>({ required: true })

// BAD: passes a snapshot
useCounterLabel(count)
// GOOD: passes a reactive source
useCounterLabel(() => count)
```

## 3. Reactivity

- `computed` holds every derived value. Its getter is pure: no request, no assignment, no DOM access, and nothing ever assigns to the result (`vue/no-side-effects-in-computed-properties`, `vue/no-async-in-computed-properties`).
- `watch` and `watchEffect` exist for side effects: a request, storage, a third-party call, a DOM measurement. Vue sanctions watchers for this; a watcher is not a smell by itself, only a watcher that computes a value another `computed` could hold. `watch` names its sources and runs lazily; `watchEffect` tracks what it reads and runs at once.
- Read the DOM after an update with `flush: 'post'`. Avoid `flush: 'sync'` on a source that changes often.
- A watcher that starts async work registers cleanup with `onWatcherCleanup` (3.5) or the `onCleanup` argument, so a stale response never overwrites a newer one.
- `deep: true` walks the whole structure on every change; on a large object use `deep: 1` or watch the specific property. Watching a `reactive()` object is deep by default.
- Register lifecycle hooks and watchers synchronously at the top level of `setup` (`vue/no-lifecycle-after-await`, `vue/no-watch-after-await`). A hook registered inside a callback or event handler binds to no instance and runs never or leaks.
- In script, a `ref` is read and written through `.value`; only the template unwraps top-level refs. After a migration or a large refactor, search for refs compared or passed without `.value`.
- Hold large immutable data (a fetched list, a parsed document) in `shallowRef` and replace the whole value; deep reactivity on ten thousand nodes costs more than it returns.
- Keep list item props stable: pass `:active="item.id === activeId"` rather than `activeId` to every item, so only two items re-render when the selection moves.
- Reference template elements with `useTemplateRef<HTMLInputElement>('input')` (3.5). Do not pass a generic argument to `reactive()`; annotate the variable instead.
- Load rarely shown components with `defineAsyncComponent` or lazy routes and virtualise long lists before reaching for `v-memo` or `v-once`.

```ts
const results = shallowRef<Result[]>([])
watch(query, async (next) => {
  const controller = new AbortController()
  onWatcherCleanup(() => controller.abort())
  results.value = await search(next, { signal: controller.signal })
})

const input = useTemplateRef<HTMLInputElement>('input')
onMounted(() => input.value?.focus())
```

## 4. Composables

- Name a composable `useXxx`. Accept `MaybeRefOrGetter<T>` and read it with `toValue()` inside `computed`, `watch`, or `watchEffect` so the dependency is tracked. Return a plain object of refs, never a `reactive()` object, so the caller can destructure without losing reactivity.
- Browser and DOM work happens in `onMounted`, and its teardown in `onUnmounted`, inside the composable that owns the resource (an event listener, an observer). This keeps the composable safe under SSR.
- Preference: a composable that loads data defines `load` and returns it; the component decides when to call it (`onMounted(load)` in the page, not inside the composable). Invocation timing is the caller's decision.
- Prefer composables to mixins. A mixin hides where a property comes from and collides on names. Reach for a component instead only when layout is shared as well.
- Organise `setup` by logical concern (search, pagination, selection), each concern one composable or one contiguous block, not by primitive type (all refs, then all computeds).
- Preference: model a domain concept as an object that answers questions about itself (`contract.targetYearRequired`, `contract.eventAvailable`) instead of free-standing helpers (`isEventAvailable(type, subType)`) or checks inside components. Script-like predicate functions multiply and put dependencies in the wrong place; a domain object is reusable from any component or store. Watch for a page component that has become a long procedural script and split it into such objects before it grows further.
- Reuse the shared conversion or helper that already exists before writing the mapping inline in a component; two copies drift.
- Preference: guard a permission-dependent fetch at the call site so the call is never made, rather than returning early inside the fetch function. A caller that asks for what it may not have is the problem.

```ts
export function useFullName(user: MaybeRefOrGetter<User>) {
  const fullName = computed(() => {
    const { firstName, lastName } = toValue(user)
    return `${firstName} ${lastName}`
  })
  return { fullName }
}

// GOOD: the page decides when to load
const { todos, load } = useTodos()
onMounted(load)
```

## 5. State

- State is local until a second reader appears. Search and form state live in a `ref` or a composable in the component that owns the form; a store-backed `searchQuery` that no other view reads is surface area without a reader, and chaining the value up through several emitted events is worse. Move state to a store when several views depend on it or when it would otherwise be drilled through many layers.
- Do not place a value used by one component in a store.
- For a deep subtree, use `provide` and `inject` with a `Symbol() as InjectionKey<T>` key. Mutations stay in the provider: provide a `readonly()` view and the functions that change it. `inject` returns `T | undefined` unless a default is given; handle that.
- Pinia stores are setup stores named `useXxxStore`. Never destructure a store directly; take state and getters through `storeToRefs` and destructure actions freely. A store does not return the route or other app-provided values.
- Under SSR, never create shared state at module scope (`const cart = ref([])` in a `.ts` module); one request's data leaks into the next. Use a store, or in Nuxt `useState`.
- Per-user rollout goes through the feature-flag mechanism; the rules are in `typescript-idioms`. A stub that always returns `false` says in its comment that a flag will replace it.

```ts
export const themeKey = Symbol() as InjectionKey<Readonly<Ref<Theme>>>
provide(themeKey, readonly(theme))

export const useCartStore = defineStore('cart', () => {
  const items = ref<Item[]>([])
  const total = computed(() => items.value.reduce((sum, i) => sum + i.price, 0))
  function add(item: Item) { items.value.push(item) }
  return { items, total, add }
})
const { items, total } = storeToRefs(useCartStore())
const { add } = useCartStore()
```

```ts
// BAD
const canSearch = userId % 20 === 2 || [12, 48, 301].includes(userId)

// GOOD
const canSearch = flags.isEnabled('free-word-search', { defaultValue: false })
```

## 6. Nuxt 4

- Application code lives under `app/`. `components/`, `composables/`, and `utils/` are auto-imported; a name that already exists there is a collision, not a new export. Import explicitly from `#imports` when the source must be visible, and set `imports.scan` to false to turn scanning off for a directory.
- Never call `$fetch` at the top level of `setup`; it runs on the server and again during hydration. Use `useFetch` for a URL and `useAsyncData` for any other async source. `$fetch` belongs in event handlers and other code that runs on one side only.
- Two calls with the same key share `data`, `error`, and `status`, so they must pass the same `handler`, `transform`, `pick`, `default`, and `deep`. `data` is a `shallowRef` that defaults to `undefined` (pass `deep: true` to opt in). `lazy: true` means the component renders before the data arrives and must handle the loading state itself.
- Pass a getter or `computed` for a reactive URL so the request re-runs when the source changes. Do not use `useAsyncData` for a side effect such as calling a store action.
- Shared state that must survive server rendering goes in `useState('key')`, which is serialised and shallow; wrap it in a composable so the key is written once.

```ts
// BAD
const user = await $fetch('/api/user')

// GOOD
const { data: user } = await useFetch('/api/user')
const { data: posts } = await useFetch(() => `/api/users/${userId.value}/posts`)
```

## 7. Errors

- `app.config.errorHandler` receives every uncaught error from components, watchers, and handlers; it is the place to report to a tracker.
- `onErrorCaptured` in an ancestor catches errors from descendants' render, setup, lifecycle hooks, watchers, and event handlers, including a rejected promise returned from a handler. It does not see a `setTimeout` callback or a promise nobody returned. Return `false` to stop propagation, render a fallback, and do not re-render the content that failed.

```ts
const failed = ref(false)
onErrorCaptured((err, _instance, info) => {
  report(err, info)
  failed.value = true
  return false
})
```

## 8. Testing UI code

- Test what the user sees and does. With Vue Testing Library, query by role first (`getByRole('button', { name: 'Search' })`), then label text, then visible text; `getByTestId` is the last resort, and `wrapper.vm` internals from Vue Test Utils are not what a user interacts with.
- Drive the component with `user-event`, not `fireEvent` or `wrapper.trigger`, so focus, keyboard, and pointer sequences match a browser.
- Wait with `findBy*` (`await screen.findByText('3 results')`), never `waitFor(() => getBy...)`, and use `queryBy*` only to assert absence. A `waitFor` block holds one assertion and no side effect.
- Unit-test composables and domain objects directly with Vitest; a composable that uses lifecycle hooks is mounted inside a throwaway component. Behaviour that has needed repeated ad hoc fixes (an image refetched or not) gets a test that pins it.
- Cover critical flows with Playwright: locate by role or text, assert with web-first matchers (`await expect(locator).toBeVisible()`), never branch on an un-awaited `isVisible()`, and mock third parties.
- Vitest with jsdom or happy-dom simulates a browser; treat a layout or focus result as unverified until a browser-mode or Playwright test has seen it.

## 9. Accessibility

- Use the native element before adding ARIA: `<button>` for an action, `<a href>` for navigation, `<input>` with its `type`. A `<div @click>` has no role, no keyboard handling, and no focus. Do not change a native element's semantics with `role`.
- Every control has a label: `<label :for>` paired with the input's `id` (generate the id with `useId()` in 3.5). A placeholder is not a label.
- Every `<button>` in a form declares `type` so a non-submit button does not submit.
- Anything that responds to a click responds to Enter or Space and is reachable with Tab. A `role` added to an element is a promise to implement its keyboard behaviour.
- Never put `aria-hidden` or `role="presentation"` on a focusable element.
- Headings run in order without skipping levels; landmarks (`<main>`, `<nav>`) replace `<div class="main">`.
- An external link opened in a new tab carries `rel="noopener noreferrer"`, both words.

```vue
<!-- BAD -->
<div @click="save">Save</div>
<input placeholder="Email" v-model="email" />

<!-- GOOD -->
<button type="button" @click="save">Save</button>
<label :for="emailId">Email</label>
<input :id="emailId" type="email" v-model="email" />
```

## Checklist

- [ ] Is every component multi-word, one per file, named for what it is, with a `:key` on each `v-for` that is unique and stable, and no `v-if` sharing an element with `v-for`?
- [ ] Are props typed to their element and object shapes, and does any component take an id plus a name where the whole domain object would do?
- [ ] Does any component read its caller's context (route, parent) or branch on a mode throughout instead of being split?
- [ ] Is any prop mutated, or any destructured prop passed to `watch` or a composable by value instead of as a getter?
- [ ] Is every emitted event declared, and does any `defineModel({ default })` face a parent that can pass `undefined`?
- [ ] Does a `computed` perform a side effect, or does a watcher compute a value a `computed` should hold?
- [ ] Does a watcher that starts async work register cleanup, and are hooks and watchers registered synchronously in `setup`?
- [ ] Is a `ref` read without `.value` in script, or a large immutable structure held in a deep `ref`?
- [ ] Does a composable accept `MaybeRefOrGetter`, read it through `toValue`, return plain refs, and leave `onMounted(load)` to the caller?
- [ ] Is a domain question answered by a free helper or an inline check where an object with a predicate belongs?
- [ ] Is search or form state in a store or relayed through emitted events when a local composable would do, and is any store destructured without `storeToRefs`?
- [ ] Is shared state created at module scope in an SSR app, or a rollout decided by a hard-coded id list or modulo?
- [ ] Does any Nuxt `setup` call `$fetch` at the top level, reuse a `useFetch` key with different options, or pass a static URL where a getter is needed?
- [ ] Do the tests query by role or label, use `user-event` and `findBy*`, and cover composables and library-dependent code directly?
- [ ] Does every action use a `<button>` with a `type`, every navigation an `<a>`, every control a `<label>`, and every new-tab link `noopener noreferrer`?
