---
name: rails-idioms
description: Background knowledge (not a command) on Ruby on Rails readability, object design, naming, and RSpec conventions, loaded automatically while writing or reviewing Rails code. Covers using what Rails gives you (delegate, Array.wrap, where.missing, render collection, enum scopes, route helpers, mattr_accessor, module_function, built-in validations), where logic lives (predicate methods, Law of Demeter chains, one class per file, lib/ versus app/, dependency direction, duck typing over is_a?, polymorphism over type switches, scopes versus class methods, no default_scope), thin controllers and logic-free views, naming (booleans, set_/update_/find_, must_ validators, _for/_by, newest_first scopes, helper prefixes, upsert), specs and factories (random factory values, no fixed ids, describe '.method' and '#method', literal expectations, no tests of framework guarantees), and RuboCop policy. Use when implementing or reviewing models, concerns, controllers, views, helpers, scopes, factories, or specs in a Rails app.
license: MIT
---

# Rails idioms

Background knowledge consulted while implementing or reviewing Rails code. Each rule is written so a reviewer can check it against a diff. Rules marked as a preference are house style, not Rails rules. Resource routing, the seven actions, and the case against service objects are in `dhh-rails-patterns`; this skill does not repeat them.

## 1. Use what Rails and Ruby already give you

Before writing a helper, a wrapper, or a custom pattern, check whether Rails or Ruby already has it. A hand-rolled version of a standard mechanism needs a stated reason.

- Forward a call with `delegate`, not a hand-written method. Use `allow_nil: true` where the wrapper would have used `&.`.
- Normalise a single value or an array with `Array.wrap(x)`, not `x = [x] unless x.is_a?(Array)`.
- Express "records without an associated record" with `where.missing(:association)`, not `where.not(id: Other.select(:fk))`.
- Render a list of partials with `render partial: 'item', collection: items` (or `render items`), not `items.map { |item| render 'item', item: item }`.
- Replace `each` with an accumulator array by `filter_map` or `map`. Filter with `compact` or `filter(&:present?)`, not `map(&:to_i).reject(&:zero?)`; most readers do not know that `nil.to_i == 0`.
- Declare an `enum` and use the scopes it generates instead of a constant list plus an `inclusion:` validation plus a hand-written `by_type` scope.
- Build URLs with route helpers and links with `link_to`. Hard-coded path strings cannot be found when routes change.
- Configure a module with `mattr_accessor`. Preference: define module-level functions with `module_function` rather than `class << self`.
- Use Ruby's `Singleton` module instead of a hand-rolled single instance.
- Use `validates :x, presence: true` when a custom `validate` method only checks `blank?`. In a plain Ruby model, validate values with `ActiveModel::Validations` (`validates ... inclusion:`) rather than raising `ArgumentError` from `initialize`.
- Do not add `validates :foo_id, presence: true` next to a required `belongs_to :foo`; `belongs_to` already validates presence.
- Do not include modules the class never uses (`ActiveModel::Validations::Callbacks` with no callbacks, and the like).
- Fix an irregular plural in `ActiveSupport::Inflector.inflections` instead of hard-coding `class_name:` on every association that hits it.
- Check `params.require` and `ActionController::ParameterMissing` before writing a parameter-validation helper, and write down why the default does not do the job when you still add one.
- Write `!x.nil?` or `x.nil?`, not `x != nil`.
- Preference: preload with `preload` or `eager_load`, which name the strategy, rather than `includes`.

```ruby
# BAD
def contract_start_at
  contract&.contract_start_at
end
scope :without_payment, -> { where.not(id: Payment.select(:order_id)) }
ids = [ids] unless ids.is_a?(Array)

# GOOD
delegate :contract_start_at, to: :contract, allow_nil: true
scope :without_payment, -> { where.missing(:payment) }
ids = Array.wrap(ids)
```

Do not read a column that exists on a model only because of a `joins`; read it through the association or declare `delegate`, so the reader can see where the value comes from.

## 2. Objects and where logic lives

### Put behaviour on the object that owns the fact

- Wrap a comparison against a domain constant or a timestamp in a predicate on the model (`contract.free_plan?`, `event.started?`) instead of `contract.plan == FREE_PLAN` or `event.start_at > Time.current` at the call site.
- Express a state transition as a named method (`todo.done!`) instead of `update!(status: 'done', completed_at: now)` repeated at each call site. Give a fixed, meaningful string such as a status value one constant.
- Replace a Law-of-Demeter chain in a view or serializer (`company.score&.overall&.to_f&.truncate(2)`, `user.profile_image_record&.image&.url`) with one method on the model.
- Extract a view condition such as `f.object.companies.present?` into a helper whose name states the business reason. A presentation rule that holds on every screen (a nil score renders gray) lives inside the helper, not in each view that calls it.
- A decision belongs to the model that has the data for it. A contract rule lives on the model that has contracts, and its parent only delegates and returns a safe default when the child is absent. A merge procedure belongs to `Approval`, not to a `Review` that might also be a rejection.
- Prefer `record.reminded_today?` to a helper `reminded_today?(record)`. Pass the domain object to an operation that acts on it, not an identifier dug out of it.
- Make a "should this field be updated?" decision on the owning model and let callers call the method unconditionally, instead of guarding the call from a collaborator.
- Data that does not depend on an instance is a constant or a class method; the instance method looks itself up (`Company.landing_pages` and `company.landing_page?`). Do not instantiate an object only to read a static list such as allowed file extensions.

```ruby
# BAD
if contract.plan == Contract::FREE_PLAN_NAME && event.start_at <= Time.current

# GOOD
if contract.free_plan? && event.started?
```

### Dependencies point one way

- A shared class must not know its callers. No `Message.from_provider_response(response)` constructor, no `User#copy_address_for_partner_sync`, no model method named for one use case (`record_admin_edit`) when the model does not care who calls it. The caller shapes the arguments and calls a plain interface.
- A method must not depend on a documented call order ("call after `update!`"). Make it correct whenever it is called, or restrict where it can be called from.
- Do not expose a parameter that the class's own specialisation fixes (a `CompanySearchField` does not take `api_endpoint`).
- A shared gem or database layer knows nothing about the applications that consume it: no consumer class names, STI type names, or product concepts in its comments or code.
- A model or service never references a controller. Raise a specific error (`Finder::NotFound`) and `rescue_from` it in the controller.
- A model does not know where its result is displayed. Name the scope for what it does (`id_ordered`) and let the caller decide it is the display order.
- Configure mocking at the call site or in test setup. Production code must not read a "mock this" flag in its constructor.

### Files, directories, and class shape

- Put code under `lib/` only when another application could use it unchanged, at gem granularity. Application logic and narrow domain concepts belong under `app/`, namespaced. External-service clients are library-like and belong in `lib/` or a shared client, with only the query specifics in the feature.
- One class or module per file. A class that is more than a few lines gets its own file and its own spec. Nest a class used by one parent under that parent's namespace, as deep as needed, so odd use from elsewhere stands out. Group a family of related classes under a namespace instead of long shared name prefixes.
- Do not copy a class to make a variant. Two classes described as "almost the same" have nothing forcing them to stay in sync; share the implementation. Extract on the second occurrence of a line or a client setup.
- A class that defines only class methods and never needs instances is a module. When callers must not call `new`, write `private_class_method :new`.
- Do not wrap a constant SQL string or other fixed value in a method that adds no behaviour; use a constant. Keep a constant list homogeneous: no `Settings` lookup mixed into a list of literals.
- A concern or module that works for one concrete case is not an abstraction. Make it general, keep the code inline, or at least name it for what it covers.
- Check behaviour, not class: duck typing over `is_a?`. When a `type` already maps to subclasses, implement the difference in each subclass instead of `respond_to?` or a type switch in the base class. Plan to replace a type switch with polymorphism once it grows with every variant.
- When a mixin depends on methods of the including class, declare them in the module with `raise NotImplementedError` so the contract is visible from the module's own file.

```ruby
# BAD
def display_text
  respond_to?(:options) ? options.join(', ') : value.to_s
end

# GOOD (in the base class)
def display_text
  value.to_s
end

# GOOD (in SelectField)
def display_text
  options.join(', ')
end
```

### Method signatures and dead code

- Use a keyword argument when the meaning of an argument is not obvious at the call site. `build(report, nil)` says nothing; `build(report, base_submission: nil)` does.
- Remove a parameter the method does not use or only passes through unchanged.
- Delete code that changes nothing: `x = self.x`, a `|| []` fallback on an attribute a presence validation already guarantees, a guard that skips a write when the value is unchanged, a class whose only job is to call another constructor.
- Keep one signature for the single-item and multi-item cases; do not require callers to pass unused mandatory parameters for one path.
- Handle the empty case first and return early instead of wrapping the main body in `if total.positive?`.
- When two branches differ only in where the data comes from, pick the source first (`source = base || draft`) and pass it through one builder.

### Scopes

- A `scope` is a reusable `where` or `order` named after the condition it applies (`pending_or_failed`, `id_ordered`). A business predicate that combines conditions and a point in time (`retryable`) is a class method built on those scopes.
- Extract a `where` chain that appears twice into a named scope.
- Do not put `order` in a `has_many` scope; it behaves like a default scope and is hard to override. Do not add `default_scope`. Define a named ordering scope and call it where the order matters.
- Make a caller's dependence on ordering explicit. If callers rely on `find_list(...).first` being the latest record, the method name or contract must promise the order.
- Do not add an ordering scope that has no product meaning; plain id order is enough.

```ruby
# BAD
has_many :cultures, -> { order(:position) }
scope :retryable, -> { where(status: %w[pending failed]).where(next_retry_at: ..Time.current) }

# GOOD
has_many :cultures
scope :by_position, -> { order(:position) }
scope :pending_or_failed, -> { where(status: %w[pending failed]) }
def self.retryable(at = Time.current)
  pending_or_failed.where(next_retry_at: ..at)
end
```

### Preferences

- A stateless operation whose instance is never passed around is a module with `.call`, not a class the caller instantiates.
- A domain value object uses `ActiveModel::Model` and `ActiveModel::Attributes` with validations rather than a hand-rolled `initialize` with instance variables. Let the validations decide whether processing continues.
- An operation class exposes an ActiveRecord-like class-method interface (`SubmissionEditing.create(submission:, editor:, params:)`) and hides `new` when the instance is not reused. Do not guard construction inside `initialize`; a `.create` factory returns nil or an invalid object for bad input.
- Do not set instance variables in `before_action`. Load records inside the action, through a shared private finder when several actions need it. A helper that depends on an ivar set by another `before_action` documents that contract.
- Do not extract tiny private methods to satisfy a method-length cop. Keep a complex action inline and disable the cop for that action.
- Accept data supplied only at construction time in `initialize`; a separate `add_*` method suggests later additions that never happen.
- Return a structured object from a domain method rather than a raw Hash unless the Hash form is required.

## 3. Controllers and views

- Controllers stay thin. Translating request values into model values (`"google"` into `GoogleIdentity`), request-level defences (session consistency, abuse checks, rate limits), and parameter filtering happen in the controller. URL normalisation and other logic the controller does not own goes to a model or library.
- A view decides only the shape of the output. No business decisions, availability judgements, nil-branching on domain state, `reject`/`first(10)` filtering, cache lookups, or `order`/`where` query building in a template. Filter where the collection is loaded; call a named scope from the view when it needs an ordered collection.
- For a variant of an existing flow (a resubmission), reuse the existing `new` and `create` actions and change only how the initial values are populated. A parallel action that re-implements saving duplicates vetted logic.
- Return only the fields the consuming surface needs. An endpoint that copies every attribute of an existing schema couples every consumer to every field.
- Do not use JavaScript for what HTML alone expresses; omit `selected:` instead of clearing a default option with a script.
- A partial rendered from one place sits next to its caller, not under `shared/`.
- Rely on `module:` for nested controller namespaces and omit `controller:` when the module path already resolves it.
- Preference: once an endpoint grows, hand-built JSON hashes move from the controller into a view file. Feature-specific authorisation checks live in a concern included where needed, not in `ApplicationController`.

Resource routing per action and the seven standard actions follow `dhh-rails-patterns`.

## 4. Naming

- A boolean method or column states unambiguously what is true and about what. `triggered?`, `completed`, and `pending` fail this; `todo_required?` passes. Follow the prefix convention the schema already uses.
- `set_` assigns in memory, `update_` persists, `find_` looks up without side effects. A method that assigns an instance variable is not `find_`; a method that saves is not `set_`.
- A custom validation method reads as a sentence about the concrete rule: `open_count_must_not_exceed_delivered_count`, not `counts_are_consistent` or `credential_id_length`. Match the phrasing of neighbouring validators.
- Add `_for` or `_by` when the single argument is an actor: `watched_by(user)`, `video_ids_for(user:)`.
- Suffix `-able` only when the word means something. `Eventable` on a delegated type tells the reader nothing about what the thing is.
- Name an ordering scope for its key or meaning (`newest_first`, `by_display_order`), never `ordered`.
- No view vocabulary in model names. `cta_event_select_options` returning a Relation becomes `company_active_events`; `viewable_on_company_detail_page` becomes a domain predicate, and page differences live in controllers, views, or helpers.
- A name predicts the return type. In Rails `*_options` means option pairs for a select.
- Helper methods share one global namespace; give them a domain prefix (`promotion_event_image_url`, not `build_image_url`).
- Use one domain term across code, comments, and the words users see. If the check uses `company_id`, say "company", not "partner". Do not introduce a term the schema does not use. After a rename, sweep for the old name and decide deliberately what stays.
- Paired operations get symmetric names that state their scope (`partial_refresh` and `full_refresh`). Pick the verb that fits every call site: `reset` for returning to zero, not `initialize`.
- Name a flag for the mechanism it controls (`skip_email_matching_validation`), not for the caller (`admin`).
- Keep a constant group consistently prefixed (`PUBLICATION_LOCATION_*`); a lone unprefixed member reads as a mistake.
- Do not abbreviate (`promotion_contract`, not `pc`), and avoid context-dependent words such as `base` or words with an established different meaning (`query_string` for a search term).
- When a class's responsibility changes, rename the class and file, or record the rename as a follow-up. A file fixed to one variant carries the variant in its name.
- `upsert` is the ActiveRecord bulk method; a method that updates or creates one record is `update_from_...` or `create_or_update_...`. An instance method named `destroy` deletes the receiver; when it deletes something else, name the target.
- A method whose ordering callers rely on says so (`find_sorted_list`). A fallback attribute is named as one (`default_redirect_path`) and read through one getter that applies the fallback.
- Name a function that mutates state as a command, not as a getter-like noun. Name a method from the receiver's point of view: an assistant receives a message, it does not `send_message`.
- Name a time field by what it records (`message_sent_at`), never `timestamp`.

## 5. Specs and factories

- Every factory attribute gets a random value: `[true, false].sample` or `Faker::Boolean.boolean` for booleans, `Model.statuses.keys.sample` for enums, a random time rather than `Time.zone.now`. Fix a value in a factory only with a comment saying why, and set the value the spec needs in the spec itself.
- Never hard-code record ids in factories or specs, and never create records with explicit ids. Derive a non-existent id from created records. When fixing a flaky test, ask why the fragile element was there before removing it.
- `describe '.method'` for class methods and scopes, `describe '#method'` for instance methods. `context` describes the arrangement only; a context title never names the method under test. A "does not exist" context does not include an "exists" shared context.
- Expectations are literal values. Do not compute the expected value with the implementation's constant or `strftime` call; write `'2025-03-01'`.
- Every new domain predicate on a model gets a spec. Start testing view or JavaScript behaviour once it grows beyond trivial.
- A bug fix ships with a test that fails on the code before the fix and passes after it, and the PR names that test. Without it the fix is a claim.
- Test only scenarios the application can produce. A setup that never happens in production verifies nothing.
- Do not test what the framework guarantees: that a `delegated_type` record responds to its columns, or that `perform_later` enqueues. Assert the application outcome instead, such as a request spec checking the job was enqueued.
- Do not define a factory for a materialized view. Populate the underlying tables and refresh the view in the setup.
- Do not include helper modules into request specs without a reason; the controller already has them.
- Keep a test description in sync with what it asserts.
- Preference: request specs over feature specs, and no specs for migration files.

```ruby
# BAD
factory :order do
  status { :pending }
  paid { true }
  company_id { 999 }
end

# GOOD
factory :order do
  status { Order.statuses.keys.sample }
  paid { [true, false].sample }
  company
end
```

## 6. Tooling

- Settle a recurring style debate by adopting the relevant RuboCop extension; whoever adds it picks the setting. Style points such as symbol keys belong to the linter, not to review comments.
- A deferred offence goes into `.rubocop_todo.yml`, never silently ignored.
- Do not add linter configuration that restates the default; check what `NewCops: enable` already turns on.
- Run linters on generated files too, and hook RuboCop into the generator instead of excluding generated paths.
- A red lint run blocks merge. Paste the failing output when asking for help.

## Checklist

- [ ] Does any hand-written method do what `delegate`, `Array.wrap`, `where.missing`, `render collection:`, `enum`, a route helper, or `mattr_accessor` already does?
- [ ] Is a comparison, timestamp check, or association chain in a view or caller that a model predicate or method should own?
- [ ] Does any class know how one caller uses it (caller-specific constructor, use-case method, controller reference, display-order name)?
- [ ] Does a file hold more than one class, or does `lib/` hold application logic?
- [ ] Is there an `is_a?`, `respond_to?`, or type switch where a subclass method would do?
- [ ] Does a mixin call methods of the host class without declaring them with `raise NotImplementedError`?
- [ ] Is every parameter used, every argument's meaning clear at the call site, and every line behaviour-changing?
- [ ] Is a business predicate written as a `scope`, or does an association or `default_scope` carry an `order`?
- [ ] Does a template filter, cache, branch on domain state, or build a query?
- [ ] Does a new action re-implement saving that an existing action already does?
- [ ] Does every boolean name state what is true, and does every `set_`, `update_`, `find_`, `upsert`, `destroy`, or `*_options` name match what the method does?
- [ ] Are validators named `..._must_...`, ordering scopes named for their key, helpers prefixed, and domain terms consistent with the schema?
- [ ] Does every factory attribute take a random value, with no fixed ids anywhere in the specs?
- [ ] Are class methods under `describe '.method'`, instance methods under `describe '#method'`, and expectations literal?
- [ ] Does any spec test a framework guarantee, a scenario production cannot produce, or a migration?
