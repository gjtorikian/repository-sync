repository-sync
===============

Sync two repositories, one private, one public.

## Setup

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable there called "token" that establishes a private token.
This ensures that no one can trigger some arbitrary changes.

On your private repository, set a webhook up to hit the `/update_public` endpoint.
Pass in two parameters:

1. `public_repo`, the name of the public repository to update
2. `token`, a very secret token

On your public repository, set a webhook up to hit the `/update_private` endpoint.
Pass in two parameters:

1. `private_repo`, the name of the public repository to update
2. `token`, a very secret token
