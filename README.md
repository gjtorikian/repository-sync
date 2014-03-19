repository-sync
===============

Sync two repositories, one private, one public.

## Setup

On your private repository, set a webhook up to hit a specific URL. Pass in
two parameters:

1. `public_repo`, the name of the public repository to update
2. `token`, a very secret token

On your public repository, set a webhook up to hit a specific URL. Pass in
two parameters:

1. `private_repo`, the name of the public repository to update
2. `token`, a very secret token

Deploy this code to Heroku (or some other server you own). Set an environment
variable there that matches the private token. This ensures that no one can
trigger some arbitrary changes.
