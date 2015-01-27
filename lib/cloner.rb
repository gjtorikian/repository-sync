require "open3"

class Cloner

  DEFAULTS = {
    :tmpdir               => Dir.mktmpdir("repository-sync/repos/#{Time.now.to_i}#{rand(1000)}"),
    :after_sha            => nil,
    :destination_hostname => "github.com",
    :destination_repo     => nil,
    :originating_hostname => "github.com",
    :originating_repo     => nil,
    :squash               => true
  }

  attr_accessor :tmpdir, :after_sha, :destination_hostname, :destination_repo
  attr_accessor :originating_hostname, :originating_repo, :squash
  alias_method :squash?, :squash

  def initialize(options)
    DEFAULTS.each { |key,value| instance_variable_set("@#{key}", options[key] || value) }

    if destination_hostname != 'github.com'
      Octokit.configure do |c|
        c.api_endpoint = "https://#{destination_hostname}/api/v3/"
        c.web_endpoint = "https://#{destination_hostname}"
      end
    end

    git.config('user.name', ENV['MACHINE_USER_NAME'])
    git.config('user.email', ENV['MACHINE_USER_EMAIL'])

    logger.info "New Cloner instance initialized"
    DEFAULTS.each { |key,value| logger.info "  * #{key}: #{instance_variable_get("@#{key}")}" }
  end

  def clone
    Dir.chdir "#{tmpdir}/#{destination_repo}" do
      Bundler.with_clean_env do
        add_remote
        fetch
        merge
        push
        create_pull_request
        delete_branch
        logger.info "fin"
      end
    end
  rescue StandardError => e
    logger.warn e
    raise
  ensure
    FileUtils.rm_rf(tmpdir)
    logger.info "Cleaning up #{tmpdir}"
  end

  def originating_token
    @originating_token ||= (originating_hostname == 'github.com' ? dotcom_token : ghe_token)
  end

  def destination_token
    @destination_token ||= (destination_hostname == 'github.com' ? dotcom_token : ghe_token)
  end

  def dotcom_token
    ENV['DOTCOM_MACHINE_USER_TOKEN']
  end

  def ghe_token
    ENV['GHE_MACHINE_USER_TOKEN']
  end

  def remote_name
    @remote_name ||= "otherrepo-#{Time.now.to_i}"
  end

  def branch_name
    @branch_name ||= "update-#{Time.now.to_i}"
  end

  def safe_destination_repo
    @safe_destination_repo ||= destination_repo.tr('/-', '_')
  end

  def commit_message
    @commit_message ||= ENV["#{safe_destination_repo.upcase}_COMMIT_MESSAGE"] || 'Sync changes from upstream repository'
  end

  def files
    @files ||= client.compare(destination_repo, 'master', branch_name)['files']
  end

  def url_with_token(remote=:destination)
    token    = (remote == :destination) ? destination_token    : originating_token
    hostname = (remote == :destination) ? destination_hostname : originating_hostname
    repo     = (remote == :destination) ? destination_repo     : originating_repo
    "https://#{token}:x-oauth-basic@#{hostname}/#{repo}.git"
  end

  def originating_url_with_token
    @originating_url_with_token ||= url_with_token(:originating)
  end

  def destination_url_with_token
    @destination_url_with_token ||= url_with_token(:destination)
  end

  def pull_request_title
    ENV["#{safe_destination_repo.upcase}_PR_TITLE"] || 'Sync changes from upstream repository'
  end

  def pull_request_body
    return ENV["#{safe_destination_repo.upcase}_PR_BODY"] if ENV["#{safe_destination_repo.upcase}_PR_BODY"]
    body = ""
    ["added", "removed", "unchanged"].each do |type|
      filenames = files.select { |f| f['status'] == type }.map { |f| f['filename'] }
      body << "### #{type.capitalize} files: \n\n* #{filenames.join("\n* ")}\n\n" unless filenames.empty?
    end
    body
  end

  # Plumbing methods

  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def client
    @client ||= Octokit::Client.new(:access_token => destination_token)
  end

  def git
    @git ||= begin
      logger.info "Cloning #{destination_repo} from #{destination_hostname}..."
      Git.clone(destination_url_with_token, "#{tmpdir}/#{destination_repo}")
    end
  end

  def run_command(*args)
    logger.info "Running command #{args.join(" ")}"
    output = status = nil
    output, status = Open3.capture2e(*args)
    logger.info "Result: #{output}"
    if status != 0
      report_error(output)
      raise "Command `#{args.join(" ")}` failed: #{output}"
    end
    output
  end

  def report_error(command_output)
    logger.warn command_output
    return if Sinatra::Base.development?
    return unless command_output =~ /Merge conflict|error/i
    body = "Hey, I'm really sorry about this, but there was a merge conflict when "
    body << "I tried to auto-sync the last time, from #{after_sha}:\n"
    body << "\n```\n"
    body << command_output
    body << "\n```\n"
    body << "You'll have to resolve this problem manually, I'm afraid.\n"
    body << "![I'm so sorry](http://media.giphy.com/media/NxKcqJI6MdIgo/giphy.gif)"
    client.create_issue originating_repo, "Merge conflict detected", body
  end

  # Methods that perform sync actions, in order

  def add_remote
    logger.info "Adding remote for #{originating_repo} on #{originating_hostname}..."
    git.add_remote(remote_name, originating_url_with_token)
  end

  def fetch
    logger.info "Fetching #{originating_repo}..."
    git.remote(remote_name).fetch
  end

  def merge
    logger.info "Checking out #{branch_name}"
    git.branch(branch_name).checkout

    logger.info "Merging #{originating_repo}/master into #{branch_name}..."
    if squash?
      logger.info "Squashing!"
      output = run_command('git', 'merge', '--squash', "#{remote_name}/master")
      git.commit(commit_message)
    else
      logger.info "Not squashing"
      output = run_command('git', 'merge', "#{remote_name}/master")
    end
  end

  def push
    logger.info "Pushing to origin..."
    run_command('git', 'push', 'origin', branch_name)
  end

  def create_pull_request
    return logger.warn "No files have changed" if files.empty?

    pr = client.create_pull_request(
      destination_repo,
      'master',
      branch_name,
      pull_request_title,
      pull_request_body
    )

    logger.info "Pull request ##{pr[:number]} created."
    sleep 2 # seems that the PR cannot be merged immediately after it's made?

    client.merge_pull_request(destination_repo, pr[:number].to_i)
    logger.info "Merged PR ##{pr[:number]}"
  end

  def delete_branch
    logger.info "Deleting #{destination_repo}/#{branch_name}"
    client.delete_branch(destination_repo, branch_name)
  end
end
