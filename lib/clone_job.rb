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
      branchname, message = update_repo
      return message if branchname.nil?

      puts "Working on branch #{branchname}..."

      @client = setup_octokit

      check_and_merge(branchname)
      delete_branch(branchname)
    end
  end

  def self.update_repo
    remotename = "otherrepo-#{Time.now.to_i}"
    branchname = "update-#{Time.now.to_i}"

    puts "Adding remote for #{@originating_repo} on #{@originating_hostname}..."
    @git_dir.add_remote(remotename, clone_url_with_token(@originating_hostname, @originating_repo))
    puts "Fetching #{@originating_repo}..."
    @git_dir.remote(remotename).fetch
    @git_dir.branch(branchname).checkout

    begin
      # lol can't `merge --squash` with the Ruby Git lib.
      public_note = @is_public ? '(is public)' : ''
      puts "Merging #{@originating_repo}/master into #{remotename} #{public_note}..."
      if @is_public
        merge_command = IO.popen(['git', 'merge', '--squash', "#{remotename}/master"])
        sleep 2
        @git_dir.commit('Sync changes from upstream repository')
      else
        merge_command = IO.popen(['git', 'merge', "#{remotename}/master"])
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

    # not sure why push isn't working here via the Ruby Git lib.
    puts 'Pushing to origin...'
    merge_command = IO.popen(['git', 'push', 'origin', branchname])
    print_blocking_output(merge_command)
    branchname
  end

  def self.clone_repo(hostname, repo)
    server = hostname || 'github.com'
    puts "Cloning #{repo} from #{server}..."
    @git_dir = Git.clone(clone_url_with_token(server, repo), "#{@tmpdir}/#{repo}")
    puts 'Repository cloned!'
  end

  def self.setup_git
    puts 'Configuring robot user...'
    @git_dir.config('user.name', ENV['MACHINE_USER_NAME'])
    @git_dir.config('user.email', ENV['MACHINE_USER_EMAIL'])
    puts 'Configured!'
  end

  def self.print_blocking_output(command)
    while (line = command.gets) # intentionally blocking call
      print line
      if line.match(/Merge conflict/) || line.match(/error/)
        print 'Opening issue...'
        @client.create_issue(@originating_repo, 'Merge conflict detected', "Hey, I'm really sorry about this, but there was a merge conflict when I tried to auto-sync the last time. You'll have to resolve this problem manually, I'm afraid. \n\n![I'm so sorry](http://media.giphy.com/media/NxKcqJI6MdIgo/giphy.gif)")
      end
    end
  end

  def self.setup_octokit
    token = fetch_proper_token(@destination_hostname)
    unless @destination_hostname == 'github.com'
      Octokit.configure do |c|
        c.api_endpoint = "https://#{@destination_hostname}/api/v3/"
        c.web_endpoint = "https://#{@destination_hostname}"
      end
    end
    puts "Using API endpoint #{Octokit.api_endpoint}..."
    Octokit::Client.new(:access_token => token)
  end

  def self.check_and_merge(branchname)
    # don't create PRs with empty changesets
    if @client.compare(@destination_repo, 'master', branchname)['files'].empty?
      puts 'Not creating a PR, no files have changed!'
    else
      new_pr = @client.create_pull_request(@destination_repo, 'master', branchname, \
                                           'Sync changes from upstream repository', \
                                           ':zap::zap::zap:')
      puts "PR ##{new_pr[:number]} created!"
      sleep 2 # seems that the PR cannot be merged immediately after it's made?
      @client.merge_pull_request(@destination_repo, new_pr[:number].to_i)
      puts "Merged PR ##{new_pr[:number]}"
    end
  end

  def self.delete_branch(branchname)
    @client.delete_branch(@destination_repo, branchname)
    puts "Deleted branch #{branchname}"
  end

  def self.clone_url_with_token(server, repo)
    token = fetch_proper_token(server)
    "https://#{token}:x-oauth-basic@#{server}/#{repo}.git"
  end

  def self.fetch_proper_token(server)
    server == 'github.com' ? @dotcom_token : @ghe_token
  end
end
