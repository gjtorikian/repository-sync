require 'git'
require 'octokit'
require_relative "cloner"

class CloneJob
  @queue = :default

  def self.perform(tmpdir, after_sha, dotcom_token, ghe_token, destination_hostname, destination_repo, originating_hostname, originating_repo, is_public)

    cloner = Cloner.new({
      :tmpdir               => tmpdir,
      :after_sha            => after_sha,
      :dotcom_token         => dotcom_token,
      :ghe_token            => ghe_token,
      :destination_hostname => destination_hostname,
      :destination_repo     => destination_repo,
      :originating_hostname => originating_hostname,
      :originating_repo     => originating_repo,
      :public               => is_public
    })

    cloner.clone
  end
end
