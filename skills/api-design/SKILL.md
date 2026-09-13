---
name: api-design
description: Background knowledge (not a command) on HTTP API design and OpenAPI authoring, loaded while adding or reviewing endpoints that clients call through generated code. Covers REST resource naming and URL structure, PUT vs PATCH and JSON Merge Patch, idempotency key and retry-safe POST, 201 with Location and 202 for long-running work, pagination cursor and next token, filtering and sorting parameters, RFC 9457 problem details and error envelopes, 400 vs 422 and 403 vs 404, what counts as a breaking change, deprecated true with Deprecation and Sunset headers, versioning, OpenAPI 3.1 authoring (operationId, required, nullable, additionalProperties, readOnly, format, examples, security schemes), Spectral lint and schema diff in CI, and rate limiting. Use when adding or changing an endpoint, editing an OpenAPI document, reviewing a schema diff, or deciding how a client should call a server.
license: MIT
---

# API design

Background knowledge consulted while designing, implementing, or reviewing an HTTP API and its OpenAPI document. It is framework-neutral. `rails-safety` owns Strong Parameters, shaping response fields, and HTTP 200 on failure at the Rails level; `dhh-rails-patterns` owns resourceful routing in Rails.

## 1. Resources and URLs

Name paths after nouns. A collection is a plural noun and a member is `/orders/{order_id}`.

Nest a sub-resource only when the child cannot exist without its parent. Anything addressable on its own gets a top-level path. Stop at three levels of nesting; a deeper path means the child belongs at the top level.

Put no verbs in paths. Model a non-CRUD operation as a resource or a state transition: publishing a post is `POST /posts/{post_id}/publication`, cancelling an order creates a `cancellation`, a long computation is a `job` the client polls. One guideline family instead permits a custom method spelled `POST /orders/{order_id}:cancel` when no resource fits. Decide once per API, write the decision down, and apply it everywhere. In a Rails app the routing mechanics are in `dhh-rails-patterns`.

Name an endpoint after the resource it returns, not after what the client does with it. An endpoint that returns the path the client then navigates to is `/todos/{todo_id}/destination`, not `/todos/{todo_id}/redirect`.

```text
# BAD
POST /orders/search
GET  /orders/42/cancel
GET  /scores?scope=overall

# GOOD
GET  /orders?q=shoes
POST /orders/42/cancellation
GET  /scores/overall
GET  /lessons/{lesson_id}/score
```

Filtering, sorting, paging, and field selection are query parameters on the collection, never sub-resources.

Distinct resource scopes get distinct paths. An overall score and a per-lesson score are two resources, so `/scores/overall` and `/lessons/{lesson_id}/score` rather than one endpoint with a mode parameter. Each path then describes itself and each resource can change shape on its own. Preference: when a new consumer needs a different shape of an existing resource, add a separate endpoint instead of adding a mode parameter to the existing one, so later changes stay contained to one caller.

Give a resource that changes on its own schedule (banner images, feature flags) its own endpoint instead of bundling it into an unrelated response. Before adding an endpoint, check whether an existing one already serves the same kind of data and extend that one.

Put the endpoints of one feature under one namespace prefix (`/recommendations/...`) so they group together and do not collide with generic paths.

No trailing slash, no query string inside a path, and every `{param}` in the path is declared as a path parameter.

Segment casing is a decision point. Kebab-case (`/order-items`) is the default of most linters, one guideline family uses camelCase, and snake_case matches snake_case JSON bodies. Decide once per API, write the decision down, and apply it everywhere.

Whether a version or `api` segment appears in the path is a decision point. `/api/v1/orders` shows the surface and the version at a glance; the guidelines that favor evolution over versioning drop both and put a version, when one is needed, in a header or media type (section 7). Decide once per API, write the decision down, and apply it everywhere.

## 2. Methods and idempotency

| Method | Promise | Success response |
|---|---|---|
| GET | Safe, no side effects, idempotent | 200 with the resource or collection |
| PUT | Full replacement; a field not sent is reset | 200 or 204, 201 when a client-named resource is created |
| PATCH | Partial update with JSON Merge Patch semantics | 200 with the updated resource |
| POST on a collection | Create; the server assigns the id | 201 with `Location` and the created resource |
| POST on an action resource | Execute; not idempotent unless made so | 200, 202, or 204 |
| DELETE | Remove; idempotent | 204; a repeat returns 204 or 404 and changes nothing |

JSON Merge Patch: an absent field is unchanged, `null` deletes the field, an array is replaced whole. A field that must hold a literal `null` cannot be set through it.

```json
{"note": "leave at the door", "coupon_code": null}
```

Choose the verb from the consumer's point of view, never from how the server stores the state. Adding a pin is `POST /orders/{order_id}/pin` and removing it is `DELETE /orders/{order_id}/pin`, even when the server stores the pin as a `pinned_at` column and removal writes `null`. The client sees only the OpenAPI document, so the document has to make sense without knowledge of storage.

Make every POST retry-safe. The mechanism is a decision point. An `Idempotency-Key` header (a client-generated UUID; the server stores the response for a stated period and replays it, rejects the same key with a different payload, and answers 409 to a concurrent duplicate) works for any operation. A natural unique key in the body with 409 on duplicate needs no storage but only fits resources that have one. `If-Match` with an ETag and 412 on mismatch protects updates but not creation. Decide once per API, write the decision down, and apply it everywhere.

For work that takes longer than a request should, answer 202 with a `Location` pointing at a status resource (`/jobs/{job_id}`) and a `Retry-After`. The status resource returns 200 with a state while in progress, never 204 or 404.

Against lost updates, return an `ETag` on GET and honor `If-Match` on PUT, PATCH, and DELETE with 412 when stale. Answer 428 when the API requires the precondition and it is missing.

## 3. Request and response shape

Top-level JSON is an object, never an array, so a collection can gain metadata (a cursor, a total) without a shape change.

Relate objects one way: embed the related object as a nested object, or reference it by `<type>_id` and offer an explicit `embed` or `include` parameter that expands it. Never ship both a flat `customer_name` and a `customer` object for the same fact. Group related fields into a nested object instead of flat siblings with a shared prefix; the schema then grows inside the object.

```json
{"success": true, "chat_session_id": "cs_1", "parts": [], "sent_at": "2026-09-13T09:00:00Z"}
```

```json
{"status": "completed", "chat_session": {"id": "cs_1", "messages": [{"parts": [], "sent_at": "2026-09-13T09:00:00Z"}]}}
```

The first body is the BAD form and the second the GOOD form. Arrays are plural and objects singular. Name a field by what it contains, not by a UI metaphor: `images`, not `image_gallery`. Fix typos in public names before release; afterwards the fix is a breaking rename.

Enums are strings, never integers. Declare each enum open or closed in the schema. For an open enum the description says new values can appear and the client maps an unknown value to a documented fallback branch. For a closed enum, adding a value is breaking (section 7).

Use a `status` enum instead of a boolean as soon as a third state is conceivable: `"status": "failed"` extends, `"success": false` does not. When a response exposes several booleans about one thing, state which combinations are possible; if `completed` and `pending` can both be true, restructure into one enum. Mutually exclusive options are one field with enumerated values, not several booleans. A boolean is never `null`, and an absent key never means something different from `false`; three states are an enum.

Timestamps travel as RFC 3339 in UTC with uppercase `T` and `Z`, never as epoch numbers. Pick one suffix (`_at` or `_time`) and use it on every timestamp. Name a timestamp after the event it records and confirm exactly which actions update it before exposing it. A framework-maintained `updated_at` changes on any write, so a "last activity" field is a dedicated `last_actioned_at`, not `updated_at`. A date without time uses `format: date` and the schema says so (section 8).

Ids are opaque to the client: no arithmetic, no ordering assumptions, stored as received. Whether they are strings or integers is a decision point. The guidelines say opaque strings, because the format can move to a UUID or ULID without a type change and sequential integers reveal volume; the house preference used the integer id rather than the UUID as the detail path parameter because it is shorter and matches the primary key. Decide once per API, write the decision down, and apply it everywhere.

Money never travels as a bare float and always carries a currency. Whether the amount is a decimal string or an integer in minor units is a decision point. Decide once per API, write the decision down, and apply it everywhere.

The response carries the fields the consuming surface needs and no more; shaping every field that leaves a Rails server is in `rails-safety`. Preference: return the underlying data (`deadline_at`) and let the client derive presentation (a "due today" badge), but compute business judgements (whether a rejected version exists) on the server and return them as a field. When such a judgement is awkward to express, the data model no longer matches the business; revisit it before shipping the field.

Preference: request fields stay required until a real partial-update use case exists, because optional fields blur the generated types and multiply the cases both sides handle. This applies before release; after release a new input has to be optional (section 7).

Field case is a decision point. snake_case matches most database columns and one major guideline; lowerCamelCase matches the client languages and another. Decide once per API, write the decision down, and apply it everywhere.

An envelope for single resources is a decision point. One specification wraps every body in `{"data": ...}` so metadata and errors have a fixed place; most guidelines return the bare object and reserve wrapping for collections. Decide once per API, write the decision down, and apply it everywhere.

Null versus absent is a decision point. One school never sends `null`, omits the field, and accepts `null` only in a merge patch as delete. Another requires optional and nullable to mean the same thing, so a field is either optional and non-nullable or required and nullable. A third allows optional and nullable together only where `{"f": null}` and `{}` legitimately differ, which is PATCH. Decide once per API, write the decision down, and apply it everywhere.

## 4. Pagination

Paginate every list that can grow before it is released. Adding pagination later changes the response shape and is breaking.

Prefer a cursor to an offset, and state the trade-off in the design. Offset lets the client jump to page N and is supported by more frameworks, but it skips or duplicates items under concurrent writes and slows on deep pages. A cursor is stable and fast but forward-only. Whether offset is offered at all is part of the same decision.

Tokens are opaque and URL-safe, never assembled by the client, and carry no authorization; the server re-checks access on every page. The response carries a `next_cursor` or a `next` link that is absent on the last page, not `null`. A total count is opt-in (a `Prefer: return=total-count` header or an `include_total=true` parameter) because counting is expensive.

```json
{"items": [{"id": "ord_1"}, {"id": "ord_2"}], "next_cursor": "eyJpZCI6Im9yZF8yIn0"}
```

## 5. Filtering, sorting, and field selection

Filters, sorting, and field selection are documented parameters with stated semantics: `status=open`, `created_after=2026-01-01T00:00:00Z`, `sort=-created_at`, `fields=id,title`. Send a variable number of values as one array parameter (`keyword[]=a&keyword[]=b` or `keyword=a,b`), never as `keyword1`, `keyword2`, `keyword3`. Every array parameter declares its serialization.

```yaml
- name: status
  in: query
  style: form
  explode: true
  schema:
    type: array
    items:
      type: string
      enum: [open, closed]
```

Preference: the client sends raw user input and the server interprets it. Splitting a search string into keywords on the client spreads the search semantics over two systems.

An invalid filter value or unknown sort key is 400 (or 422, per the section 6 decision), never an empty 200.

Document implicit authorization filtering: a list that returns only the caller's own records says so in its description.

Removing a field from an existing view or from the default field set is breaking.

## 6. Errors

Return `application/problem+json` (RFC 9457) for every 4xx and 5xx, or one documented envelope for the whole API. Either way the body carries a stable machine-readable `type` or `code` that clients branch on, a human `title` and `detail` that clients never parse, and for validation an `errors` list with a `pointer` (JSON Pointer) for each invalid field. The `status` in the body equals the HTTP status.

```json
{
  "type": "/problems/validation-error",
  "title": "Request body is invalid",
  "status": 400,
  "errors": [
    {"detail": "must be a positive integer", "pointer": "/quantity"}
  ]
}
```

No stack traces, SQL, class names, or internal identifiers in any error body.

Document every 4xx the operation can return, and only those. A GET has no 422; a create documents its validation error and its 409 when a unique key exists; a guarded endpoint documents 401. Copied error sections make the document lie about the endpoint. A failed operation is never 200; the Rails mechanics are in `rails-safety`.

A bulk operation either answers 207 with a status per item or rejects the whole batch; state which.

400 versus 422 for semantic validation is a decision point. One guideline uses 400 for every client-side input error and calls 422 not recommended; many APIs use 400 for malformed syntax and 422 for a well-formed body that violates a rule. Decide once per API, write the decision down, and apply it everywhere.

403 versus 404 when hiding existence is a decision point. Checking permission first and answering 403 tells the caller that access can be requested; answering 404 hides whether the record exists, which the HTTP specification permits. Decide once per API, write the decision down, and apply it everywhere.

## 7. Compatibility and change

Breaking changes:

- removing or renaming an operation, field, parameter, header, or enum value
- changing a type or format, a URL, or a resource name
- adding a required input, or making an optional input required
- tightening input validation
- making a response field optional or nullable, or removing it
- adding a value to a closed response enum
- changing a default or the meaning of an existing field
- introducing pagination on an existing list
- changing authentication or removing a security requirement

Compatible changes:

- a new endpoint
- a new optional input with a stated default
- a new response field
- a new value on an enum declared open
- loosening input validation, or making a required input optional

Additive-only evolution is the default. Clients are tolerant readers: they ignore unknown fields, map unknown values of open enums to a fallback, and treat an unknown status code by its class. Servers are strict: unknown input is rejected with 400 and documented as such.

Deprecate before removing. Mark the operation, parameter, or schema `deprecated: true` and put the replacement and the sunset date in its description; send `Deprecation` and `Sunset` headers on its responses; monitor usage of every deprecated operation; state the grace period in the API's policy. Before deleting an endpoint, check access logs and look for callers the author does not know about, such as a mobile app. Switching callers to the new endpoint and deleting the old one are separate pull requests.

```yaml
get:
  operationId: listLegacyOrders
  deprecated: true
  summary: List orders (legacy shape)
  description: Replaced by listOrders. Sunset on 2027-03-31.
```

Versioning is a decision point, taken once before the first release. A path segment (`/v1/`) is visible and cacheable, but every breaking change opens a whole new surface that clients migrate to at once. A date-named header pinned per account gives fine-grained upgrades on top of additive evolution, at the cost of server-side transformation layers per version. A media-type version works per resource, but browsers and tooling handle it poorly. Decide once per API, write the decision down, and apply it everywhere.

Run a schema diff tool in CI against the last released document and fail on a breaking change. When an OpenAPI change forces the regenerated client to change, say so in the pull request so the consumer's follow-up is planned. A very large OpenAPI change is split so each pull request covers one endpoint or one reviewable piece.

The shape of a released API is expensive to change. Review grouping, nesting, names, and types before release with that cost in mind.

## 8. OpenAPI authoring

Design first: the OpenAPI document is the source of truth, and clients are generated from it rather than typed by hand. Shared schemas, parameters, and responses live in `components` and are used through `$ref`.

Every operation has a unique, URL-safe `operationId` written like a method name (`createOrder`), because it becomes the generated client's method name. Every operation has a `summary`, a `description`, at least one tag, a 2xx response, its 4xx responses, and a security requirement.

```yaml
post:
  operationId: createOrder
  summary: Create an order
  tags: [orders]
  security:
    - bearerAuth: []
  responses:
    "201": {$ref: "#/components/responses/OrderCreated"}
    "400": {$ref: "#/components/responses/Problem"}
    "401": {$ref: "#/components/responses/Problem"}
```

Schemas list `required` explicitly and every listed property exists; an omitted `required` generates all-optional client types. OpenAPI 3.1 has no `nullable` keyword: write `type: [string, "null"]`. Set `format` on every number (`int32`, `int64`, `double`, `decimal`) and every formatted string (`date`, `date-time`, `uuid`). When a date or time travels as a string, the schema states the exact format. Mark server-generated fields `readOnly` so the same schema serves request and response.

```yaml
Order:
  type: object
  required: [id, placed_at, coupon_code]
  properties:
    id: {type: string, readOnly: true}
    placed_at: {type: string, format: date-time}
    coupon_code: {type: [string, "null"]}
    total_minor_units: {type: integer, format: int64}
```

Examples validate against their schema (the linters check this). A description matches what the endpoint returns: a field documented as an absolute URL does not return a relative path or a blob identifier. A description carries the contract, not the release plan ("in v1 only the name is editable" goes stale); an explicit TODO is the only note of that kind that belongs there.

Declare security schemes in `components.securitySchemes` and require them per operation. Adding an authentication guard to an endpoint adds a documented 401 response in the same change.

Lint the document with Spectral or Redocly in CI using the recommended ruleset plus the house decisions (path casing, plural segments, problem details on 4xx).

`additionalProperties` is a decision point. The guidelines that favor evolution leave object schemas open (the default) so a tolerant client keeps working when a field is added, and use `additionalProperties` with a value schema only for maps. The house preference set `additionalProperties: false` on response schemas so response validation in automated tests catches unexpected fields; some client generators also emit closed types regardless. Both agree that `additionalProperties: true` as a substitute for documenting known fields is wrong. Decide once per API, write the decision down, and apply it everywhere.

## 9. Security basics

Every endpoint is authenticated unless documented as public. Authorization is checked at the object level (this caller can read this record) and at the property level (this caller can see and write these fields), not only at the endpoint level.

Scopes are named by resource and access (`orders.read`, `orders.write`) and listed on each operation's security requirement. Do not declare an OAuth scheme when only a bearer token is accepted.

Rate-limited endpoints answer 429 with `Retry-After`, or with `RateLimit` headers that tell the client the remaining quota. Clients back off with jitter.

Nothing internal leaves the server: no stack traces or table names in errors, no authorization in cursors, no volume-revealing sequence in ids the API commits to as opaque.

## Checklist

- [ ] Is the change additive only, with no removed or renamed field, parameter, enum value, or operation, and no changed type, format, or default?
- [ ] Did an input become required or a constraint tighten, or did a response field become optional or nullable, or a closed enum gain a value?
- [ ] Is every path a plural noun, at most three levels deep, without verbs, and does a non-CRUD action appear as a resource or state transition?
- [ ] Is the verb chosen from the consumer's view (PUT replace, PATCH merge, POST create with 201 and Location, DELETE 204), and is every POST retry-safe?
- [ ] Is the top-level body an object, is every growing list paginated with an opaque cursor and an absent next token on the last page, and is the total count opt-in?
- [ ] Are timestamps RFC 3339 UTC with one suffix, ids opaque, money carrying a currency, enums strings declared open or closed, and booleans never null?
- [ ] Does a status enum replace a boolean where a third state is conceivable, and are related fields grouped into a nested object?
- [ ] Are errors problem details or the documented envelope with a stable code and a pointer per invalid field, with no internals, and is every 4xx the operation can return documented and no other?
- [ ] Do 400 versus 422 and 403 versus 404 follow the API's written decision?
- [ ] Does every operation have a unique URL-safe operationId, summary, description, tag, 2xx and 4xx responses, a security requirement, and validating examples?
- [ ] Are schemas in components with explicit required lists, nullability as a type array, formats on numbers and formatted strings, and readOnly on server-generated fields?
- [ ] Do descriptions match what the endpoint returns, and does a new authentication guard come with a documented 401?
- [ ] For a deprecation, are deprecated true, migration text, Deprecation and Sunset headers, and usage monitoring in place, and were access logs checked before a removal?
- [ ] Do the lint and the schema diff pass in CI, and does the pull request say when the regenerated client will change?
- [ ] Is authorization checked per object and per property, and does a rate-limited endpoint answer 429 with Retry-After or RateLimit headers?
