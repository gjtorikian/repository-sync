require 'git'

class CloneJob
  @queue = :default

  def self.perform(tmpdir, token, destination_repo, originating_repo, is_public)
    clone_repo(destination_repo, token, tmpdir)
    Dir.chdir "#{tmpdir}/#{destination_repo}" do
      setup_git
      branchname, message = update_repo(originating_repo, is_public, token)
      return message if branchname.nil?
      puts "Working on branch #{branchname}"
      client = Octokit::Client.new(:access_token => token)
      new_pr = client.create_pull_request(destination_repo, "master", branchname, "Sync changes from upstream repository", ":zap::zap::zap:")
      puts "PR ##{new_pr[:number]} created"
      client.merge_pull_request(destination_repo, new_pr[:number].to_i)
      puts "Merged PR ##{new_pr[:number]}"
      client.delete_branch(destination_repo, branchname)
      puts "Deleted branch #{branchname}"
    end
  end

  def self.update_repo(originating_repo, is_public, token)
    remotename = "otherrepo-#{Time.now.to_i}"
    branchname = "update-#{Time.now.to_i}"

    @git_dir.add_remote(remotename, clone_url_with_token(token, originating_repo))
    puts "Fetching #{originating_repo}..."
    @git_dir.remote(remotename).fetch
    @git_dir.branch(branchname).checkout

    begin
      # lol can't `merge --squash` with the git lib.
      puts "Merging #{originating_repo}/master..."
      if is_public
        merge_command = IO.popen(["git", "merge", "--squash", "#{remotename}/master"])
        sleep 2
        @git_dir.commit('Sync changes from upstream repository')
      else
        merge_command = IO.popen(["git", "merge", "#{remotename}/master"])
        sleep 2
      end
    rescue Git::GitExecuteError => e
      if e.message =~ /nothing to commit/
        return nil, "#{e.message}"
      else
        raise
      end
    end

    print_blocking_output(merge_command)

    # not sure why push isn't working here
    puts "Pushing to origin..."
    merge_command = IO.popen(["git", "push", "origin", branchname])
    print_blocking_output(merge_command)
    branchname
  end

  def self.clone_repo(destination_repo, token, tmpdir)
    puts "Cloning #{destination_repo}..."
    @git_dir = Git.clone(clone_url_with_token(token, destination_repo), "#{tmpdir}/#{destination_repo}")
  end

  def self.setup_git
   @git_dir.config('user.name', 'Hubot')
   @git_dir.config('user.email', 'cwanstrath+hubot@gmail.com')
  end

  def self.print_blocking_output(command)
    while (line = command.gets) # intentionally blocking call
      print line
    end
  end

  def self.clone_url_with_token(token, repo)
    "https://#{token}:x-oauth-basic@github.com/#{repo}.git"
  end
end
