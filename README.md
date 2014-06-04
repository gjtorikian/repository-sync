repository-sync
===============

Easily sync between two repositories, one private, one public.

## Setup

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable on that server called `SECRET_TOKEN`, which establishes a private token. This token is used to verify that the payload came from GitHub.
3. Set another environment variable on that server called `MACHINE_USER_TOKEN`. This is the access token the server will act as when performing the Git operations.

On your private repository, set a webhook up to hit the `/update_public` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update.

On your public repository, set a webhook up to hit the `/update_private` endpoint.
Pass in just one parameter, `dest_repo`, the name of the private repository to update.

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.
