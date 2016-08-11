repository-sync
===============

repository-sync is a tool designed to keep two repositories—one private, one public—entirely in sync. Private commits are [*squashed*](http://jamescooke.info/git-to-squash-or-not-to-squash.html) into a single commit to avoid leaking information. Similarly, every public commit is brought over to the private repository, so that none of the history is lost.

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

On your private repository, set a webhook to point to the `/sync?sync_method=squash` endpoint.
Pass in one more parameter, `dest_repo`, the name of the public repository to update. It might look like:

```
http://repository-sync.someserver.com/sync?sync_method=squash&dest_repo=ourorg/public
```

Don't forget to fill out the **Secret** field with your secret token!

On your public repository, set a webhook to point to the `/sync?sync_method=merge` endpoint.
Pass in just one parameter, `dest_repo`, the name of the private repository to update. It might look like:

```
http://repository-sync.someserver.com/sync?dest_repo=ourorg/private
```

Don't forget to fill out the **Secret** field with your secret token!

You'll notice these two endpoints are practically the same. They are! The only difference is the value of the `sync_method` parameter. When hitting an endpoint with the `sync_method=squash` path parameter, this tool will perform a `--squash merge` to hide the commit history.

There is a third, *highly experimental*, sync method. `sync_method=replace_contents` will completely remove the public repository contents and replace them with the contents of the private repository. Its use is not recommended.

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

On your private repository, set a webhook to point to the `/sync` endpoint.
Pass in just one parameter, `dest_repo`, the name of the public repository to update. It might look like `http://repository-sync.someserver.com/sync?sync_method=squash&dest_repo=ourorg/public`. Don't forget to fill out the **Secret** field with your secret token!

On your public repository, set a webhook to point to the `/sync` endpoint.
Pass in two parameters:

* `dest_repo`, the name of the private repository to update
* `destination_hostname`, the hostname of your GitHub Enterprise installation

It might look like:

```
http://repository-sync.someserver.com/sync?dest_repo=ourorg/private&destination_hostname=our.ghe.io
```

Don't forget to fill out the **Secret** field with your secret token!

You'll notice these two endpoints are practically the same. They are! The only difference is
that, when hitting an endpoint with the `squash` path parameter, this tool will perform a `--squash merge` to hide the commit history.

### Between a GitHub Enterprise repository and a GitHub Enterprise repository

First, deploy this code to Heroku (or some other server you own).

Next, you'll need to set a few environment variables:

| Option | Description
| :----- | :----------
| `SECRET_TOKEN` | **Required**. This establishes a private token to secure your payloads. This token is used to [verify that the payload came from GitHub](https://developer.github.com/webhooks/securing/).
| `GHE_MACHINE_USER_TOKEN` | **Required**.  This is [the access token the server will act as](https://help.github.com/articles/creating-an-access-token-for-command-line-use) when syncing between the repositories, generated on your GitHub Enterprise instance.
| `MACHINE_USER_EMAIL` | **Required**. The Git email address of your machine user.
| `MACHINE_USER_NAME` | **Required**. The Git author name of your machine user.

On your private repository, set a webhook to point to the `/sync` endpoint.
Pass in two parameters:

* `dest_repo`, the name of the public repository to update
* `destination_hostname`, the hostname of your GitHub Enterprise installation

It might look like:

```
http://repository-sync.someserver.com/sync?sync_method=squash&dest_repo=ourorg/public&destination_hostname=our.ghe.io
```

Don't forget to fill out the **Secret** field with your secret token!

On your public repository, set a webhook to point to the `/sync` endpoint.
Pass in two parameters:

* `dest_repo`, the name of the private repository to update
* `destination_hostname`, the hostname of your GitHub Enterprise installation

It might look like:

```
http://repository-sync.someserver.com/sync?dest_repo=ourorg/private&destination_hostname=our.ghe.io
```

Don't forget to fill out the **Secret** field with your secret token!

## Customizing messaging

Believe it or not, there are a few more environment variables you can set! These determine the text used by repository-sync when creating commit messages and pull requests. They are also dependent on the name of the destination repository. All of these values are optional.

For the examples below, we'll assuming repository-sync is committing into a repository called `gjtorikian/this-test`. Because environment variables cannot use the `/` or `-` characters, you must substitute those characters in the repository name as `_`. The repository name should also be capitalized. Using our example repository, that would mean a prefix of `GJTORIKIAN_THIS_TEST`.

* `#{safe_destination_repo}_COMMIT_MESSAGE`: This determines the commit message to use when committing into your public repository. Example: `GJTORIKIAN_THIS_TEST_COMMIT_MESSAGE`.

* `#{safe_destination_repo}_PR_TITLE`: This determines the title of the PR that's opened into either repository. Example: `GJTORIKIAN_THIS_TEST_PR_TITLE`. The default string is `'Sync changes from upstream repository'`.

* `#{safe_destination_repo}_PR_BODY`: This determines the body text of the PR that's opened into either repository. Example: `GJTORIKIAN_THIS_TEST_PR_BODY`. The default string is a listing of the added, modified, and removed files in the PR.

## Removing the PR creation

If, instead of a new pull request, you'd like repository-sync to just merge straight into a branch, pass in the `default_branch` option to the webhook URL. For example, it might look like:

```
http://repository-sync.someserver.com/sync?dest_repo=ourorg/public&default_branch=master
```
