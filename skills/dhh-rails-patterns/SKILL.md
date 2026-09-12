---
name: dhh-rails-patterns
description: Background knowledge (not a command) on the DHH / 37signals style of Rails implementation, loaded automatically while writing Rails code. Covers no service objects, RESTful controllers limited to the seven actions, splitting models with concerns, database constraints first, and request specs. Use when implementing or reviewing models, controllers, routes, migrations, or specs in a Rails app that follows "vanilla Rails".
license: MIT
---

# DHH / 37signals Rails patterns

Background knowledge Claude consults on its own while implementing Rails code.

## Core principle

> "Vanilla Rails is plenty." Use what Rails ships with to the fullest and keep outside dependencies to a minimum.

---

## 1. Service objects: do not use them

Business logic lives in **model methods**. When a model grows, split it with **concerns**.

```ruby
# BAD
CloseCardService.new(card, user: current_user).call

# GOOD
card.close(user: current_user)
```

---

## 2. Controllers: the seven actions only

`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`

A custom action becomes a **new controller**.

```ruby
# BAD
resources :posts do
  member { post :publish }
end

# GOOD
resources :posts do
  resource :publication, only: [:create, :destroy]
end
```

---

## 3. Concerns: split by domain concern

```ruby
class Post < ApplicationRecord
  include Taggable      # everything about tags
  include Publishable   # everything about publishing
  include Trashable     # everything about the trash
end
```

Each concern gathers its own associations, scopes, callbacks, and methods.

---

## 4. Patterns not used

| Not used | Use instead |
|---|---|
| Service objects | Model methods + concerns |
| Query objects | Scopes |
| Form objects | Models + `accepts_nested_attributes` |
| Decorators / presenters | Helper methods |

---

## 5. Database first

```ruby
# Migration
add_column :posts, :title, :string, null: false, comment: 'Title'

# Model (only when a user-facing error message is needed)
validates :title, presence: true
```

---

## 6. Tests

- Prefer request specs.
- Avoid `allow_any_instance_of`.
- Favor integration tests.

---

## Checklist (while implementing)

- [ ] Service object? Move it into a model method.
- [ ] Custom action? Make it a new controller.
- [ ] Boolean state column? Consider a separate record instead.
- [ ] Business logic in a controller? Move it to the model.
- [ ] Shared behavior? Extract a concern.
- [ ] Are the database constraints in place?
