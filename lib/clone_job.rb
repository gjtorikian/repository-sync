require 'git'
require 'octokit'
require_relative 'cloner'

class CloneJob
  @queue = :default

  def self.perform(committers, after_sha, destination_hostname, destination_repo, originating_hostname, originating_repo, default_branch, sync_method)
    cloner = Cloner.new({
      :committers           => committers,
      :after_sha            => after_sha,
      :destination_hostname => destination_hostname,
      :destination_repo     => destination_repo,
      :originating_hostname => originating_hostname,
      :originating_repo     => originating_repo,
      :default_branch       => default_branch,
      :sync_method          => sync_method
    })

    cloner.clone
  end
end
