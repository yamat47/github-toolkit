# Access to the zebra API

The API sits behind Cloudflare Access and answers only a request that carries the owner's service token. The token is a client id and a client secret, sent in two headers.

## The client id

The client id is not a secret. It is in the environment variable `ZEBRA_ACCESS_CLIENT_ID`, and every request sends it, the searches too:

```sh
curl -sS -w '\n%{http_code}\n' -H "CF-Access-Client-Id: $ZEBRA_ACCESS_CLIENT_ID" 'https://zebra.yamat47.workers.dev/rules/7-3-8'
```

If the variable is empty, the skill is not set up where you are running. Say so and stop.

## The client secret

The secret reaches the request in one of two ways.

- In a Claude Code cloud session whose environment holds it as a network secret for `zebra.yamat47.workers.dev`, the command above is complete. The session's proxy adds the `CF-Access-Client-Secret` header, and the secret never appears in the session.
- Anywhere else, the secret is in the environment variable `ZEBRA_ACCESS_CLIENT_SECRET`, and the request adds `-H "CF-Access-Client-Secret: $ZEBRA_ACCESS_CLIENT_SECRET"`.

Do not print the secret, and do not ask the user to paste it into the conversation.

## What a failed request looks like

| Answer | What it means |
| --- | --- |
| 302 to a login page, or a page of HTML | Access answered and not the API: the request carried no client id, or not both parts of the token. |
| 401 | The token was not accepted: a wrong client id, or a secret that is missing or wrong. |
| An empty 400 | The layer in front of the API refused the request, usually a query with Japanese that was not URL-encoded. Use `curl -sS -G --data-urlencode 'q=...'`. |
| 400 or 404 with a message in Japanese | The API answered: the message says what is wrong with the request. |

A request that fails in one of the first two ways after both parts of the token are in place is not something to work around. Tell the user that the rulebook could not be reached, and stop.
