# What to ask, by the kind of file changed

A file with nothing to ask gets nothing; do not invent a comment for it. Specs, factories, locale files, and comments count as much as production code: about a third of what the reviewer posts is there, and a review that only looks at the production code misses that third every time.

## Specs and factories

- A factory or a `let` with a fixed value where the value does not matter: the reviewer asks for a random one (a sample from the choices, a generated string) so the test cannot pass by coincidence. This is the reviewer's single most repeated comment.
- An id chosen by hand (`id: 999`, `contract_id: 1`): flaky and opaque; use a record that does not exist, or a random value.
- A `context` whose name says the opposite of what it sets up; a `describe` where a `context` belongs, or the reverse; `describe '#method'` as the unit for a method.
- A test that pins the implementation (stubs of internals, the exact query) rather than the result.
- A test added to a file whose subject the pull request did not change: why here, why now.
- The edge the change introduces and the failure path, when neither has a test.
- A test of what the framework guarantees (that a job was enqueued, that a validation the framework runs rejects a value): the reviewer asks for it to go, and for the application's own behaviour to be tested instead.

## Migrations and schema

- A table or column without a comment; a column that can be NOT NULL and is not; a unique index missing where the fact is unique; a foreign key column whose type does not match the referenced id (`bigint`); `t.references` with the singular name; a foreign key constraint always.
- A status column overwritten in place where a row per event would keep the history; meaning hung on `created_at` or `updated_at`; ordering by `created_at` where a timestamp of the domain fact belongs.
- Enum values as strings that mean something, not integers.
- A schema change mixed with application code in one pull request.

## Models

- A method that knows its caller: a name or a branch for one caller (`for_x`, `_for_admin`), a method that only one integration uses defined on a model everyone uses. The dependency points the wrong way; ask where it should live.
- A hand-rolled constant plus validation plus scope where `enum` gives all three; a scope that does not return a relation; `delete` where `destroy` runs the callbacks; `find_by` followed by a raise where `find` already raises.
- A line the behaviour does not need, because the framework already does it implicitly.
- `includes` where the intent is a join (`eager_load`), or the reverse.

## Controllers

- A new action or a new endpoint where an existing one with a parameter would do; a new form where the existing form could be reused; a new mechanism next to an existing one. "Couldn't this ride on the existing X?" is the reviewer's most frequent question on a controller.
- A `before_action` that sets an instance variable for one action: inline it in the action.
- A method extracted only to satisfy a line-count cop: inline it and disable the cop for that action.
- A branch on a record's state that should be a 404 (`RecordNotFound`).
- What is authorized where, and strong parameters.

## Views, helpers, and JavaScript

- Text in the template that belongs in the locale file: menu labels, button text, headings.
- A condition in the template whose reason is not visible: extract a helper whose name says why.
- A partial named `shared` or placed under a shared directory but used from one place; a partial that knows its caller.
- A helper that hand-rolls what a framework helper or the locale file already does.
- Client-side code that sets a state (selected, disabled) when there is nothing to set: why.
- A collection reduced to its first element: why only the first, and why can there be several.
- A shared class or selector reused for a new purpose, so the code runs where it was not meant to.

## Comments, documentation, locale text, and the pull request text

- A comment that says what the code does rather than why; a note copied from elsewhere that no longer matches; a sentence that cannot be understood in one reading. The reviewer says "I do not follow this sentence" plainly.
- A label or a message whose wording does not say what the action does.
- A commented-out block, a debug line, an unrelated change to whitespace or formatting: one nit for all of them.

## Libraries and shared code

- Application knowledge under `lib/` or in a gem-like directory: a class there that reads the application's models, constants, or settings. Library code should be movable to another repository as it is.

## Configuration and operations

- An environment or a mode the application does not have (a `staging` section where only production and development exist); a setting enabled in `test` without a reason; a tool's ignore file (`brakeman.ignore`, a linter's exclusion) grown by an entry the change should have made unnecessary.
- A schedule or a description with the wrong timezone; a secret in source; an exception swallowed; a log line where an alert belongs, or the reverse; a cache key that cannot be invalidated; cost.
