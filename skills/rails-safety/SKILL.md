---
name: rails-safety
description: Background knowledge (not a command) on Ruby on Rails correctness rules that keep code from breaking data, leaking data, or failing silently. Covers upsert_all, insert_all, update_all, update_columns and save(validate:false); nil.to_i, presence, allow_nil and validations; exceptions, rescue, retry_on, NotImplementedError and HTTP status on failure; Strong Parameters, SQL interpolation, HTTPS, sessions, before_action guards, authorization in the data layer, brakeman.ignore and prompt injection; find_each, N+1 evidence, job fan-out and batch scoping; cache keys; I18n for errors.add and labels, strftime and durations; rake tasks, Rails.env.local?, queues and staging; Gemfile pins, git gems, monkey patches and library choice. Use when implementing or reviewing models, controllers, jobs, rake tasks, Gemfile changes, caches, locale files, or any pull request that writes to the database in a Rails app.
license: MIT
---

# Rails safety rules

Background knowledge consulted while implementing or reviewing Rails code. Each rule is something a reviewer checks against a diff. Rules marked as a preference are house style rather than Rails behaviour. Controller shape and resource routing belong to `dhh-rails-patterns`.

## 1. Writes that bypass validations and callbacks

State the reason in the PR before using `upsert_all`, `insert_all`, `update_all`, `update_columns`, or `save(validate: false)`. These calls skip model validations, and some skip callbacks, so the trade-off between correctness and throughput has to be written down, including whether validations will be needed later.

Prefer validated writes (`save`, `update!`, `create!`) unless a measured performance need exists. When the loop is too slow, move it to a background job first and drop validations last. If the code calls `valid?` on every record anyway, call `save` instead of the bulk method.

```ruby
# BAD
source.profiles.update_all(university_id: target.id)

# GOOD
source.profiles.find_each { |profile| profile.update!(university_id: target.id) }
```

Choose which mechanism to bypass. `save(validate: false)` skips validations only; `update_columns` also skips callbacks. A comment that says "skip validation" above an `update_columns` call is a mismatch.

Treat `save(validate: false)` as a red flag. Find out why the record is invalid before shipping the bypass, even when the bypass ships as a stopgap.

A method named with `!` must delegate to bang methods. `destroy` can fail silently and return `false`, which breaks the promise the name makes. Do not put `&.` after `find_by!`; it already raises when nothing is found.

```ruby
# BAD
def unlink!(type)
  identities.find_by!(identity_type: type)&.destroy
end

# GOOD
def unlink!(type)
  identities.find_by!(identity_type: type).destroy!
end
```

Return the resulting object from a bang write method (`self` or the created record). The value returned by an `ActiveRecord::Base.transaction` block is not a reliable API.

In an ActiveModel form object, `save` and `save!` must call `valid?` or `invalid?`; declared validations that nothing invokes are dead code. Express every check as a validation so that `invalid?` alone decides the outcome.

Use `dependent: :destroy` rather than `:delete_all` or `:delete` unless a comment states the reason. Deletion should run validations and callbacks on the children.

Define `scope` only for lambdas that return an `ActiveRecord::Relation`. Anything that returns a single record or another value is a class method.

```ruby
# BAD
scope :latest, -> { order(version: :desc).first }

# GOOD
def self.latest
  order(version: :desc).first
end
```

Look a child record up through its parent association when the child id comes from a request. A mismatched parent and child pair then raises `RecordNotFound` instead of updating another parent's row.

```ruby
# BAD
answer = Answer.find(params[:id])

# GOOD
report = Report.find(params[:report_id])
answer = report.answers.find(params[:id])
```

Derive paired values from one object instead of accepting both as arguments. A method that takes an order and a separate `company_id` lets callers pass a combination that never existed.

Do not overwrite attributes of an already generated record on every re-evaluation. Once a todo or a deadline is created, leave it alone unless the code states a reason to rewrite it.

Build the conditions for a list query and its count query in one place. Two copies drift and the count stops matching the list.

## 2. Nil, coercion, and defaults

`to_i` never returns `nil`, so `value.to_i || default` never falls back. `nil.to_i` and `"".to_i` are both `0`, and a blank page-size parameter turns into an unbounded query.

```ruby
# BAD
per = params[:per].to_i || DEFAULT_PER

# GOOD
per = params[:per].to_i
per = DEFAULT_PER unless per.positive?
```

Do not call `to_i` on a value that goes straight into a JSON response. The output is the same for a real number, and for `nil` it silently becomes `0`.

Use `Object#presence` when the value can be an empty string. `""` is truthy in Ruby, so `value || default` never falls through.

```ruby
# BAD
names = company.alias_names || ""

# GOOD
names = company.alias_names.presence || ""
```

Add a length validation to every free-text attribute accepted from a client, and constrain client values on the server (length, format) rather than only normalising them.

Put `allow_nil: true` inside the `inclusion:` hash, not at the top level of `validates`. A top-level `allow_nil` also skips the presence check in the same call.

```ruby
# BAD
validates :status, presence: true, inclusion: { in: STATUSES }, allow_nil: true

# GOOD
validates :status, presence: true, inclusion: { in: STATUSES, allow_nil: true }
```

Reject unexpected values of an enum-like argument instead of letting them fall through to a default branch. An unknown `target_state` that quietly runs the default branch is a bug nobody sees. For Rails enums, `enum :status, STATUSES, validate: true` turns an unknown value into a validation error instead of an `ArgumentError`. Preference: raise `TypeError` or `ArgumentError` for malformed input and default only when the value is absent.

Replace a type ternary with a frozen mapping and `Hash#fetch`. The ternary silently misroutes the third type; `fetch` raises.

```ruby
# BAD
fields = type == :standard ? STANDARD_FIELDS : RAMP_FIELDS

# GOOD
FIELDS_BY_TYPE = { standard: STANDARD_FIELDS, ramp: RAMP_FIELDS }.freeze
fields = FIELDS_BY_TYPE.fetch(type)
```

Do not add a validation the framework already performs. An enum column already rejects `nil` and unknown values, so a presence check "just in case" adds noise.

Add a numericality validation to count columns: allow `nil`, otherwise require a non-negative integer. When a column is meaningful for only one value of a type column, validate that it is `nil` in the other states.

Make a constructor keyword required when `nil` never makes sense for it. A default of `nil` advertises an option that is never valid.

When a new value joins a shared enum or column, confirm every consumer handles it, not only the writer.

## 3. Errors and failure paths

Do not hand-roll retry loops inside a job. The job framework already retries on exception; a custom loop hides failures from it.

```ruby
# BAD
rescue StandardError
  attempts += 1
  retry if attempts <= MAX_ATTEMPTS

# GOOD
retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5
```

Define a specific exception class for a domain failure instead of raising or rescuing `ArgumentError` or `RuntimeError`. A broad rescue also swallows unrelated programming errors that raise the same class, and a named class lets specs and rescue clauses target one case. Preference: name the class after the condition (`InactiveGraduateYearError`, `FeatureDisabledError` carrying the feature name) and map it to an HTTP status in one place such as `ApplicationController`.

End every `case` on a type or state discriminator with `else raise NotImplementedError`. Spell out each expected branch, including the success case, so an unknown value fails loudly instead of being treated as success. Preference: avoid a catch-all `else` that does real work.

```ruby
# GOOD (a bare `else import_manual(step)` would treat any new kind as manual)
case step.kind
when "upload" then import_upload(step)
when "manual" then import_manual(step)
else raise NotImplementedError, "unknown step kind: #{step.kind}"
end
```

Abstract methods on a base class raise `NotImplementedError` instead of returning `nil`. A silent default lets a subclass inherit "no deadline" by accident; a subclass that really has no value sets `nil` explicitly. The same applies to a polymorphic implementation that must never be called for a given type: raise rather than return `false`.

Keep the original exception when logging and re-raising. A bare `raise` inside `rescue` re-raises the current exception with its backtrace; raising a new exception with only the message loses the stack trace.

```ruby
# BAD
rescue StandardError => e
  Rails.logger.error(e.message)
  raise ImportError, e.message

# GOOD
rescue StandardError => e
  Rails.logger.error(e.message)
  raise
```

A failed service must not produce HTTP 200. When a controller calls a bang method or a bulk operation and then renders success or `head :no_content` unconditionally, the client sees success when nothing happened. Raise, or branch on the result, and keep the failure handling visible near the call rather than in a distant layer.

Match a controller's `rescue_from` coverage to what the called object raises. Check that `ArgumentError` from a constructor, or a custom error from a service, is either handled or already mapped by the framework to the intended status.

Make a `rescue` fallback explicit about which failure it handles. A catch-all that returns a default "because the value may be nil" hides whether the `nil` came from validation or from an unexpected exception.

Log a warning every time a temporary compatibility fallback runs. The log going quiet is what allows the fallback to be deleted; old queued jobs can hit it long after the deploy.

Include the record id in exception messages about invalid state.

```ruby
# BAD
raise InvalidStateError, "report must be draft, but was #{report.review_status}"

# GOOD
raise InvalidStateError, "report must be draft, but was #{report.review_status} (report_id=#{report.id})"
```

A validation method only adds to `errors`. Raise `ActiveRecord::RecordInvalid` after `invalid?` returns true, never inside the validation itself.

Preference: when a record does not belong to the current user or is in a state that forbids the action, raise `ActiveRecord::RecordNotFound` (404) instead of redirecting with an alert. Preference: let a finder raise not-found itself, as `find` does, instead of returning `nil` for the controller to check.

Preference: make unlink and removal operations idempotent. When the record is already gone, the desired end state holds, so return normally instead of raising.

## 4. Request boundary and security

Use Strong Parameters for every parameter a controller reads, including simple `id`, `page`, and `per` values. Never reassign or shadow `params`; pick another local name.

```ruby
# BAD
params = list_params
@orders = Order.page(params[:page])

# GOOD
@orders = Order.page(list_params[:page])
def list_params
  params.permit(:page, :per)
end
```

Constrain path parameter formats in the router (`constraints: { id: /\d+/ }`) instead of parsing ids defensively inside the action.

Shape every field that leaves the server. An API response that passes query results through as-is leaks whatever the query returns, and the leak grows with every schema change. This applies to `pluck` results returned as a response body.

Build dynamic SQL with hash conditions, bind parameters, or Arel, never by interpolating values into a SQL string.

```ruby
# BAD
where("large_category IN (#{categories.map { |c| "'#{c}'" }.join(',')})")

# GOOD
where(large_category: categories)
```

Use HTTPS for redirect targets and generated URLs. "It is development mode" is not a reason for plain HTTP; development can run over HTTPS too.

Preference: store a user id in the session, not an email address, and be able to point to the line that writes any session value the code reads.

Apply a controller guard (`before_action`) to all actions by default. Restrict it with `only:` when necessary and put a comment next to it saying why. This is a house preference, not a Rails rule. Exercise the negative case of every guard by hand or in a spec: a guard that returns 404 for users outside a domain has to be tested with such a user.

Put consent and authorization checks that gate personal data inside the model or data-access layer so every caller gets them. A check that lives in one caller (a CSV export) is forgotten in the next one (a detail page), and personal data leaks.

```ruby
# BAD (each caller remembers the consent check)
watch_time = consented?(user) ? WatchLog.total_for(user) : nil

# GOOD (the data layer refuses)
def self.total_for(user)
  return nil unless user.consented_to?(:watch_logs)
  where(user:).sum(:seconds)
end
```

Do not add a new `brakeman.ignore` entry for code that duplicates an already vetted path. Fold the change into the existing form or query so the suppression is unnecessary.

Leave a TODO about prompt injection defences wherever user text is forwarded to an LLM, if the PR does not solve it.

Control feature switches from outside the code (an environment variable or a request header), never with `Rails.env` checks or a hard-coded list of user ids. Toggling behaviour must not require a deploy, and the switch must be testable in any environment.

In Haml, write developer notes with `-#`, which produces nothing. A line starting with `/` renders an HTML comment that ships to the browser.

## 5. Performance with evidence

Iterate over a result set that can grow with `find_each` instead of `each`. Data patches follow the same rule; be aware of memory when chaining `select` or `to_a` on large collections. Select the attributes you need instead of materialising whole records; a bare `to_a` degrades silently every time a column is added.

In a batch that processes many records, load small lookup tables (prefectures, categories) once before the loop instead of querying them per record, and measure the total runtime.

An N+1 fix ships with before and after query counts or logs. When the local dataset is too small to show the difference, seed more data in a console. Any performance PR includes measurements.

Do not add artificial jitter or scheduled delays when fanning out jobs. Call `perform_later` and let bounded worker concurrency spread execution. Preference: fan out into one job per record rather than one job over a list of ids, weighing the extra DB load that more parallel workers cause.

```ruby
# BAD
partners.each { |p| EvaluateJob.set(wait: rand(0..300).seconds).perform_later(p.id) }

# GOOD
partners.find_each { |p| EvaluateJob.perform_later(p.id) }
```

Scope periodic batch jobs to rows that need the work (partners with an active contract), not every row in the table.

Flag code that loads a whole table and filters or ranks it in Ruby (`pluck(:domain).any? { ... }`, a full id list fed into an `IN` clause, in-memory sorting) as a scaling risk. Runtime grows with table size; ship it only with a note saying so and confirm monitoring will show it.

Decide sync versus async from the real order of magnitude of the data. Thousands of rows run fine synchronously; record the intent to go async when the volume changes.

Memoize a value fetched repeatedly from an external source (public keys, remote config) with `@value ||=`, and check that a claimed memoization stores the value somewhere. Building the object twice with a memo-looking method name is complexity with no effect.

After releasing a change that adds data to an API response, watch the endpoint's latency in production. Extra joins per record regress in ways tests do not show.

## 6. Caches

Namespace cache keys with the model and the purpose so two caches can never collide on the same raw string, and include a component that changes on deploy (release SHA or a code digest) so a logic change never serves stale results. Relying on developers to bump the key by hand fails exactly when the logic changes.

```ruby
# BAD
Rails.cache.fetch(keyword, expires_in: 1.day) { JobCategory.name_like(keyword).to_a }

# GOOD
Rails.cache.fetch(["job_category", "name_like", RELEASE_SHA, keyword], expires_in: 1.day) do
  JobCategory.name_like(keyword).to_a
end
```

## 7. I18n and time

Call `errors.add(:attribute, :symbol)` and put the message in the locale file. A literal message is hard to assert in specs, cannot be branched on by error type, and gives the model a dependency on localisation.

```ruby
# BAD
errors.add(:base, "Set a password before unlinking this account")

# GOOD
errors.add(:base, :password_required_before_unlink)
```

Labels, enum display names, flash messages, placeholders, aria labels, button captions, and any display text that appears in model code live in locale files. Do not pass copy that never varies as a component argument.

Format dates for external systems with an explicit `strftime("%Y-%m-%d")`. `Date#to_s` does not state the intent and breaks if its default format changes.

Format a duration as a duration. Converting seconds to a `Time` and calling `strftime` wraps at 24 hours and misrepresents the value.

```ruby
# BAD
Time.at(total_seconds).utc.strftime("%H:%M:%S")

# GOOD
hours, rest = total_seconds.divmod(3600)
minutes, seconds = rest.divmod(60)
format("%d:%02d:%02d", hours, minutes, seconds)
```

Preference: display date-typed attributes as a date only. A period boundary carries no time, and showing one implies precision the data does not have.

## 8. Environments, jobs, and tasks

Preference: there is no `staging` Rails environment. Staging boots in production mode and differs only through environment variables, so a `staging:` block in `config/*.yml` is dead configuration. Infrastructure variables named `env` carry a note saying they are not `RAILS_ENV`.

Guard development-only rake tasks so they cannot run outside local environments.

```ruby
task seed_demo: :environment do
  abort "development only" unless Rails.env.local?
  # ...
end
```

Put side effects such as reading a CSV inside the `task` block. Code at namespace level runs when the file is loaded, which is deploy time, not when the task is invoked.

Validate rake task arguments (dates, ranges) before acting on them.

Add a dedicated job queue only when the job's characteristics differ from the others and the reason is stated. "To avoid contention" is not a reason until queueing delay is a measured problem; ask whether a priority setting is what is actually needed.

## 9. Dependencies

Pin gems with a pessimistic patch-level constraint (`~> 3.0.7`), not an exact version, so patch releases keep flowing through Dependabot. Do not add any version constraint without a comment next to it saying why; when the reason is gone, remove the constraint at the next bump.

```ruby
# BAD
gem "carrierwave", "3.0.7"

# GOOD
gem "carrierwave", "~> 3.0.7" # 3.1.0 regresses the S3 HEAD request
```

Never merge a Gemfile that points a gem at a branch or a commit SHA. A ref pin is a verification aid; restore the released tag before approving, and mark the PR as blocked until then. Reference git-sourced gems by release tag as soon as upstream tags releases. A bot PR that moves an existing ref pin from one SHA to another is reviewed with `review-dependency-bump`.

When a shared library changes in a way consumers must receive, bump its version in the same PR. Consumers pin the version, so without the bump the change never arrives or the mismatch breaks them.

When a dependency bump breaks the test suite, find the incompatible companion library and bump it in the same PR. On a Dependabot or Renovate PR the companion goes through the bot rather than a hand edit to its branch (`review-dependency-bump` has the procedure); a hand-made companion bump carries a comment recording cause, fix, and verification.

Make a monkey patch raise when the patched gem's version differs from the one it was written against. A silent patch on a newer version breaks in unexpected places.

```ruby
expected = Gem::Version.new("0.19.4")
actual = Gem.loaded_specs.fetch("some_gem").version
raise "some_gem patch was written for #{expected}, got #{actual}" unless actual == expected
```

Reach for an existing library before hand-rolling reference data such as public holidays or structured formats such as XML, and compare the alternatives in the proposal.

## Checklist

- [ ] Does every `upsert_all`, `insert_all`, `update_all`, `update_columns`, or `save(validate: false)` come with a stated reason, and was a background job considered first?
- [ ] Does every bang method delegate to bang methods, with no `&.` after `find_by!`?
- [ ] Are children looked up through the parent association when their id comes from a request?
- [ ] Is there a `to_i || default`, a `value || ""`, or a top-level `allow_nil` that never does what it looks like?
- [ ] Does every `case` on a discriminator, and every abstract method, raise on the unexpected path?
- [ ] Can this action return HTTP 200 while the write failed, and does `rescue_from` cover what the service raises?
- [ ] Is a hand-rolled retry loop duplicating `retry_on`?
- [ ] Does every parameter pass through Strong Parameters, and is `params` never reassigned?
- [ ] Is every field in the response chosen explicitly, and is no SQL built by string interpolation?
- [ ] Do consent and authorization checks live in the data layer so every caller gets them?
- [ ] Does a loop over a growing table use `find_each`, preload its lookups, and does the N+1 fix show query counts?
- [ ] Are cache keys namespaced and do they change on deploy?
- [ ] Do `errors.add` calls use symbols, and do labels, flash messages, and date formats go through locale files and `strftime`?
- [ ] Are dev-only tasks guarded with `Rails.env.local?`, with side effects inside the `task` block?
- [ ] Is every Gemfile pin `~>` at patch level with a comment, with no branch or SHA reference left in?
