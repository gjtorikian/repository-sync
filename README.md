repository-sync
===============

Easily sync between two repositories, one private, one public.

[![Build Status](https://travis-ci.org/gjtorikian/repository-sync.svg?branch=master)](https://travis-ci.org/gjtorikian/repository-sync)

## Setup

### Between two GitHub.com repositories

First, deploy this code to Heroku (or some other server you own).

Next, you'll need to set a few environment variables:

| Option | Description
| :----- | :----------
| `SECRET_TOKEN` | **Required**. This establishes a private token to secure your payloads. This token is used to [verify that the payload came from GitHub](https://developer.github.com/webhooks/securing/).
| `DOTCOM_MACHINE_USER_TOKEN` | **Required**.  This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories.
| `MACHINE_USER_EMAIL` | **Required**. The Git email address of your machine user.
| `MACHINE_USER_NAME` | **Required**. The Git author name of your machine user.


On your private repository, set a webhook to point to the `/update_public` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update. It might look like `http://repository-sync.someserver.com?dest_repo=ourorg/public`. Don't forget to fill out the **Secret** field with your secret token!

On your public repository, set a webhook to point to the `/update_private` endpoint.
Pass in just one parameter, `dest_repo`, the name of the private repository to update. It might look like `http://repository-sync.someserver.com?dest_repo=ourorg/private`. Don't forget to fill out the **Secret** field with your secret token!

You'll notice these two are practically the same. They are! The only difference is
that, whilst updating a public repository, this tool will `--squash merge` to hide
the commit history.

### Between a GitHub.com repository and a GitHub Enterprise repository

First, deploy this code to Heroku (or some other server you own).

Next, you'll need to set a few environment variables:

| Option | Description
| :----- | :----------
| `SECRET_TOKEN` | **Required**. This establishes a private token to secure your payloads. This token is used to [verify that the payload came from GitHub](https://developer.github.com/webhooks/securing/).
| `DOTCOM_MACHINE_USER_TOKEN` | **Required**.  This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories.
| `GHE_MACHINE_USER_TOKEN` | **Required**.  This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories, generated on your GitHub Enterprise instance.
| `MACHINE_USER_EMAIL` | **Required**. The Git email address of your machine user.
| `MACHINE_USER_NAME` | **Required**. The Git author name of your machine user.

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
