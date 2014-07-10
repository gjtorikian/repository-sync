require 'git'

class CloneJob
  @queue = :default

  def self.perform(tmpdir, dotcom_token, ghe_token, destination_hostname, destination_repo, originating_hostname, originating_repo, is_public)
    @tmpdir = tmpdir

    @dotcom_token = dotcom_token
    @ghe_token = ghe_token

    @destination_hostname = destination_hostname
    @destination_repo = destination_repo

    @originating_repo = originating_repo
    @originating_hostname = originating_hostname

    @is_public = is_public

    clone_repo(@destination_hostname, @destination_repo)

    Dir.chdir "#{@tmpdir}/#{@destination_repo}" do
      setup_git
      branchname, message = update_repo(is_public)
      return message if branchname.nil?
      puts "Working on branch #{branchname}..."
      token = fetch_proper_token(@destination_hostname)
      client = Octokit::Client.new(:access_token => token)
      new_pr = client.create_pull_request(@destination_repo, "master", branchname, "Sync changes from upstream repository", ":zap::zap::zap:")
      puts "PR ##{new_pr[:number]} created!"
      sleep 2 # seems that the PR cannot be merged immediately after it's made?
      # don't merge PRs with empty changesets
      if client.pull_request(@destination_repo, new_pr[:number])[:changed_files] == 0
        client.close_pull_request(@destination_repo, new_pr[:number])
        puts "Closed PR ##{new_pr[:number]} (empty changeset)"
      else
        client.merge_pull_request(@destination_repo, new_pr[:number].to_i)
        puts "Merged PR ##{new_pr[:number]}"
      end
      client.delete_branch(@destination_repo, branchname)
      puts "Deleted branch #{branchname}"
    end
  end

  def self.update_repo(is_public)
    remotename = "otherrepo-#{Time.now.to_i}"
    branchname = "update-#{Time.now.to_i}"

    puts "Adding remote for #{@originating_repo} on #{@originating_hostname}..."
    @git_dir.add_remote(remotename, clone_url_with_token(@originating_hostname, @originating_repo))
    puts "Fetching #{@originating_repo}..."
    @git_dir.remote(remotename).fetch
    @git_dir.branch(branchname).checkout

    begin
      # lol can't `merge --squash` with the git lib.
      puts "Merging #{@originating_repo}/master..."
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

  def self.clone_repo(hostname, repo)
    server = hostname || "github.com"
    puts "Cloning #{repo} from #{server}..."
    @git_dir = Git.clone(clone_url_with_token(server, repo), "#{@tmpdir}/#{repo}")
    puts "Repository cloned!"
  end

  def self.setup_git
    puts "Configuring robot user..."
    @git_dir.config('user.name', 'Hubot')
    @git_dir.config('user.email', 'cwanstrath+hubot@gmail.com')
    puts "Configured!"
  end

  def self.print_blocking_output(command)
    while (line = command.gets) # intentionally blocking call
      print line
    end
  end

  def self.clone_url_with_token(server, repo)
    token = fetch_proper_token(server)
    "https://#{token}:x-oauth-basic@#{server}/#{repo}.git"
  end

  def self.fetch_proper_token(server)
    server == "github.com" ? @dotcom_token : @ghe_token
  end
end
