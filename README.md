repository-sync
===============

Easily sync between two repositories, one private, one public.

## Setup

### Between two GitHub.com repositories

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable on that server called `SECRET_TOKEN`, which establishes a private token. This token is used to verify that the payload came from GitHub.
3. Set another environment variable on that server called `DOTCOM_MACHINE_USER_TOKEN`. This is the access token the server will act as when performing the Git operations.

On your private repository, set a webhook up to hit the `/update_public` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update.

On your public repository, set a webhook up to hit the `/update_private` endpoint.
Pass in just one parameter, `dest_repo`, the name of the private repository to update.

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.

### Between a GitHub.com repository and a GitHub Enterprise repository

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable on that server called `SECRET_TOKEN`, which establishes a private token. This token is used to verify that the payload came from GitHub.
3. Set another environment variable on that server called `DOTCOM_MACHINE_USER_TOKEN`. This is the access token the server will act as when performing the Git operations on GitHub.com.
3. Set another environment variable on that server called `GHE_MACHINE_USER_TOKEN`. This is the access token the server will act as when performing the Git operations on GitHub Enterprise.

On your private repository, set a webhook up to hit the `/update_public` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update.

On your public repository, set a webhook up to hit the `/update_private` endpoint.
Pass in two parameters:

* `dest_repo`, the name of the private repository to update
* `hostname`, the hostname of your GitHub Enterprise installation

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.
