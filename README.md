repository-sync
===============

Easily sync between two repositories, one private, one public.

## Setup

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable there called `REPOSITORY_SYNC_TOKEN` that establishes a private token. There are two reasons for this:
  * This token will be the acting user for Git changes (so make sure it has access to both repos).
  * This token ensures that no one can trigger some arbitrary changes by randomly sending a `POST`.

On your private repository, set a webhook up to hit the `/update_public` endpoint.
Pass in two parameters:

1. `dest_repo`, the name of the public repository to update
2. `token`, a very secret token

On your public repository, set a webhook up to hit the `/update_private` endpoint.
Pass in two parameters:

1. `dest_repo`, the name of the public repository to update
2. `token`, a very secret token

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.
