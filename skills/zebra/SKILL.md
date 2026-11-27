---
name: zebra
description: Look up the official rules of American football in Japan (the 公式規則 and 公式規則解説 of the Japan American Football Association, with its officiating standards) through the zebra HTTP API, which returns the articles and approved rulings that bear on a question. Use when a question is about what the rules say in Japan, such as a foul and its penalty, a definition, timing, scoring, a formation or motion rule, an approved ruling (A. R.), an article number like 7-3-8, or a rule term in Japanese (パス インターフェランス, ホールディング, 反則, 罰則). zebra finds and returns rule text and does not answer; read the articles, then answer and cite their numbers.
license: MIT
---

# zebra

zebra is an HTTP API over the official rules of American football in Japan: the rules, their approved rulings (A. R.) and the officiating standards of the current edition, one article at a time. It finds and returns text. The answer is yours to write from what it returns.

## Read the usage page first

```sh
curl -sS https://zebra.yamat47.workers.dev/
```

`GET /` returns how the API is used: the endpoints, the order to call them in, how search treats a term, and the edition it holds. Read it once before the first query of a session and follow it. This skill does not repeat it, so the usage page is the one place that changes when the API does.

The order it describes is short: look the word up in the rulebook's own vocabulary, search the text for one term, read the article with its rulings.

## Access

The API sits behind Cloudflare Access and answers only a request that carries the owner's service token.

- In a Claude Code cloud session whose environment holds the token as a network secret for `zebra.yamat47.workers.dev`, send the request as it is. The session's proxy adds the header, and the token never appears in the session.
- Anywhere else, the token is in the environment variable `ZEBRA_TOKEN` and goes in one header:

  ```sh
  curl -sS -H "X-Zebra-Token: $ZEBRA_TOKEN" 'https://zebra.yamat47.workers.dev/rules/7-3-8'
  ```

A redirect to a login page (302) or a 401 means the request carried no valid token. Say so and stop: do not print the token, do not ask for it in chat, and do not present an answer from memory as if it came from the rulebook.

## Using what comes back

- Responses are Markdown in Japanese; `?format=json` returns JSON. Keep the rulebook's own terms when you answer, in whatever language the question was asked.
- Cite the article or ruling behind every statement (`7-3-8`, `A. R. 7-3-8-Ⅳ`). A reader checks the rulebook by number.
- The text belongs to the association and may not be reproduced without its approval. Quote the passage an answer needs and no more. Do not copy articles into a file, a commit, an issue, a pull request or any public place.
- If the search finds nothing, look the word up in the vocabulary as the usage page says, and if that fails, say that the rulebook has no such term. The rules of other bodies (the NCAA, the NFL) differ in places; do not fill a gap from them without saying which rules you are quoting.
