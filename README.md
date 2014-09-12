repository-sync
===============

Easily sync between two repositories, one private, one public.

## Setup

### Between two GitHub.com repositories

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable on that server called `SECRET_TOKEN`, which establishes a private token. This token is used to [verify that the payload came from GitHub](https://developer.github.com/webhooks/securing/).
3. Set another environment variable on that server called `DOTCOM_MACHINE_USER_TOKEN`. This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories.

On your private repository, set a webhook to point to the `/update_public` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update. It might look like `http://repository-sync.someserver.com?dest_repo=ourorg/public`. Don't forget to fill out the **Secret** field with your secret token!

On your public repository, set a webhook to point to the `/update_private` endpoint.
Pass in just one parameter, `dest_repo`, the name of the private repository to update. It might look like `http://repository-sync.someserver.com?dest_repo=ourorg/private`. Don't forget to fill out the **Secret** field with your secret token!

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.

### Between a GitHub.com repository and a GitHub Enterprise repository

1. Deploy this code to Heroku (or some other server you own).
2. Set an environment variable on that server called `SECRET_TOKEN`, which establishes a private token. This token is used to [verify that the payload came from GitHub](https://developer.github.com/webhooks/securing/).
3. Set another environment variable on that server called `DOTCOM_MACHINE_USER_TOKEN`. This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories.
3. Set another environment variable on that server called `GHE_MACHINE_USER_TOKEN`. This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories.

On your private repository, set a webhook to point to the `/update_public` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update. It might look like `http://repository-sync.someserver.com?dest_repo=ourorg/public`. Don't forget to fill out the **Secret** field with your secret token!

On your public repository, set a webhook to point to the `/update_private` endpoint.
Pass in two parameters:

* `dest_repo`, the name of the private repository to update
* `hostname`, the hostname of your GitHub Enterprise installation

It might look like `http://repository-sync.someserver.com?dest_repo=ourorg/private&hostname=our.ghe.io`. Don't forget to fill out the **Secret** field with your secret token! 

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.
