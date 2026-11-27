---
name: zebra
description: Look up the official rules of American football in Japan (the 公式規則 and 公式規則解説 of the Japan American Football Association, with its officiating standards) through the zebra HTTP API, which returns the articles and approved rulings that bear on a question. Use when a question is about what the rules say in Japan, such as a foul and its penalty, a definition, timing, scoring, a formation or motion rule, an approved ruling (A. R.), an article number like 7-3-8, or a rule term in Japanese (パス インターフェランス, ホールディング, 反則, 罰則). zebra finds and returns rule text and does not answer; read the articles, then answer and cite their numbers.
license: MIT
---

# zebra

zebra is an HTTP API over the official rules of American football in Japan: the rules, their approved rulings (A. R.) and the officiating standards of the current edition, one article at a time. It finds and returns text. The answer is yours to write from what it returns.

## Read the usage page first

```sh
curl -sS -H "CF-Access-Client-Id: $ZEBRA_ACCESS_CLIENT_ID" https://zebra.yamat47.workers.dev/
```

Every request carries the access token, as described under Access below. `GET /` returns how the API is used: the endpoints, the order to call them in, how search treats a term, and the edition it holds. Read it once before the first query of a session and follow it. This skill does not repeat it, so the usage page is the one place that changes when the API does.

The order it describes is short: search for one word, which returns the rulebook's own terms for it and the articles whose text uses it, then read the article it leads to, with its rulings and the articles it refers to. A second word narrows a search that finds too much. Read a long article to its end: the penalty and the rulings that decide a case are often there.

## Access

The API sits behind Cloudflare Access and answers only a request that carries the owner's service token. The token is a client id and a client secret, sent in two headers.

The client id is not a secret. It is in the environment variable `ZEBRA_ACCESS_CLIENT_ID`, and every request sends it:

```sh
curl -sS -H "CF-Access-Client-Id: $ZEBRA_ACCESS_CLIENT_ID" 'https://zebra.yamat47.workers.dev/rules/7-3-8'
```

Send that header on every request, the searches too: a request without it is answered by Access with a page of HTML and not by the API. Ask curl for the status as well (`-w '\n%{http_code}\n'`), so that such an answer is not read as a result. Japanese in a query has to be URL-encoded: `curl -sS -G --data-urlencode 'q=超過節' ...` does it, and a raw query is answered with an empty 400.

The client secret reaches the request in one of two ways.

- In a Claude Code cloud session whose environment holds it as a network secret for `zebra.yamat47.workers.dev`, the command above is complete. The session's proxy adds the `CF-Access-Client-Secret` header, and the secret never appears in the session.
- Anywhere else, the secret is in the environment variable `ZEBRA_ACCESS_CLIENT_SECRET`, and the request adds `-H "CF-Access-Client-Secret: $ZEBRA_ACCESS_CLIENT_SECRET"`.

A redirect to a login page (302) or a 401 means the request carried no valid token. Say so and stop: do not print the secret, do not ask for it in chat, and do not present an answer from memory as if it came from the rulebook.

## Using what comes back

- Responses are Markdown in Japanese; `?format=json` returns JSON. Keep the rulebook's own terms when you answer, in whatever language the question was asked.
- Cite the article or ruling behind every statement (`7-3-8`, `A. R. 7-3-8-Ⅳ`). A reader checks the rulebook by number.
- The text belongs to the association and may not be reproduced without its approval. Quote the passage an answer needs and no more. Do not copy articles into a file, a commit, an issue, a pull request or any public place.
- An everyday word is often not the rulebook's word: 延長戦 is 超過節 there, and ビデオ判定 is インスタント リプレー. The API fills in the common ones and says when it has, in the result. Such a mapping is the site's and not the rulebook's, so cite the article it leads to and not the mapping.
- When a search finds nothing, try the other words the question implies, and a shorter one, before concluding anything. A near term the API offers can be about something else, so read what it points to before relying on it.
- Say that the rulebook does not use a word only after those have failed. The rules of other bodies (the NCAA, the NFL) differ in places; do not fill a gap from them without saying which rules you are quoting.
