require 'open3'

class Cloner
  GITHUB_DOMAIN = 'github.com'.freeze

  DEFAULTS = {
    :tmpdir               => nil,
    :committers           => nil,
    :after_sha            => nil,
    :default_branch       => nil,
    :sync_method          => 'merge',
    :destination_hostname => GITHUB_DOMAIN,
    :destination_repo     => nil,
    :originating_hostname => GITHUB_DOMAIN,
    :originating_repo     => nil,
    :git                  => nil
  }

  attr_accessor :tmpdir, :committers, :after_sha, :destination_hostname, :destination_repo
  attr_accessor :originating_hostname, :originating_repo, :default_branch, :sync_method

  def initialize(options)
    logger.level = Logger::WARN if ENV['RACK_ENV'] == 'test'
    logger.info 'New Cloner instance initialized'

    DEFAULTS.each { |key,value| instance_variable_set("@#{key}", options[key] || value) }
    @tmpdir ||= Dir.mktmpdir('repository-sync')

    unless github_dotcom_dest?
      Octokit.configure do |c|
        c.api_endpoint = "https://#{destination_hostname}/api/v3/"
        c.web_endpoint = "https://#{destination_hostname}"
      end
    end

    git_init

    DEFAULTS.each { |key, _| logger.info "  * #{key}: #{instance_variable_get("@#{key}")}" }
  end

  def clone
    Bundler.with_clean_env do
      Dir.chdir "#{tmpdir}/#{destination_repo}" do
        add_remote
        fetch

        if @default_branch.nil?
          checkout
          apply_sync_method
          push
          create_pull_request
        else
          apply_sync_method
          submit_to_default_branch
        end

        delete_branch
        logger.info 'fin'
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
    @originating_token ||= (github_dotcom_origin? ? dotcom_token : ghe_token)
  end

  def destination_token
    @destination_token ||= (github_dotcom_dest? ? dotcom_token : ghe_token)
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
    @safe_destination_repo ||= destination_repo.tr('/-', '_').upcase
  end

  def commit_message
    @commit_message ||= ENV["#{safe_destination_repo}_COMMIT_MESSAGE"] || 'Sync changes from upstream repository'
  end

  def files
    @files ||= client.compare(destination_repo, 'master', branch_name)['files']
  end

  def url_with_token(remote = :destination)
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
    if files.count == 1
      "#{files.first['status'].capitalize} #{files.first['filename']}"
    else
      ENV["#{safe_destination_repo}_PR_TITLE"] || 'Sync changes from upstream repository'
    end
  end

  def pull_request_body
    return ENV["#{safe_destination_repo}_PR_BODY"] if ENV["#{safe_destination_repo}_PR_BODY"]
    body = ''
    %w(added removed unchanged).each do |type|
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
    logger.info "Running command #{args.join(' ')}"
    output = status = nil
    output, status = Open3.capture2e(*args)
    output = output.gsub(/#{dotcom_token}/, '<TOKEN>') if dotcom_token
    output = output.gsub(/#{ghe_token}/, '<TOKEN>') if ghe_token
    logger.info "Result: #{output}"
    if status != 0
      report_error(output)
      fail "Command `#{args.join(' ')}` failed: #{output}"
    end
    output
  end

  def report_error(command_output)
    return unless command_output =~ /Merge conflict|error/i
    body = "Hey, I'm really sorry about this, but there was a merge conflict when "
    body << "I tried to auto-sync the last time, from #{after_sha}:\n"
    body << "\n```\n"
    body << command_output
    body << "\n```\n"
    body << "You'll have to resolve this problem manually, I'm afraid.\n"
    body << "![I'm so sorry](http://media.giphy.com/media/NxKcqJI6MdIgo/giphy.gif)"
    body << "\n\n /cc #{committers.join(' ')}" unless committers.nil?
    client.create_issue originating_repo, 'Merge conflict detected', body
  end

  # Methods that perform sync actions, in order

  def git_init
    git.config('user.name',  ENV['MACHINE_USER_NAME'])
    git.config('user.email', ENV['MACHINE_USER_EMAIL'])
  end

  def add_remote
    logger.info "Adding remote for #{originating_repo} on #{originating_hostname}..."
    git.add_remote(remote_name, originating_url_with_token)
  end

  def fetch
    logger.info "Fetching #{originating_repo}..."
    git.remote(remote_name).fetch
  end

  def checkout
    logger.info "Checking out #{branch_name}"
    git.branch(branch_name).create
    git.checkout(branch_name)
  end

  def apply_sync_method
    if sync_method == "squash"
      squash
    elsif sync_method == "replace_contents"
      replace_contents
    elsif sync_method == "merge"
      merge
    else
      logger.warn "Invalid sync method #{sync_method}. Merging by default..."
      merge
    end
  end

  def merge
    logger.info "Merging #{originating_repo}/master into #{branch_name}..."
    run_command('git', 'merge', "#{remote_name}/master")
  end

  def squash
    logger.info "Squashing #{originating_repo}/master into #{branch_name}..."
    run_command('git', 'merge', '--squash', "#{remote_name}/master")
    git.commit(commit_message)
  end

  # Using HEAD here is likely the best thing since HEAD will be a pointer to
  # the head of the branch we checked out earlier and is likely more reliable
  # than manually trying to use "refs/heads/#{branch_name}"
  def replace_contents
    logger.info "Committing contents of #{originating_repo}/master into #{branch_name} directly..."
    commit_id = run_command('git', 'commit-tree', "#{remote_name}/master^{tree}", '-p', 'HEAD', '-m', commit_message)
    run_command('git', 'update-ref', 'HEAD', commit_id.chomp)
  end

  def push
    logger.info 'Pushing to origin...'
    run_command('git', 'push', 'origin', branch_name)
  end

  def submit_to_default_branch
    run_command('git', 'push', 'origin', 'master')
  end

  def create_pull_request
    return logger.warn 'No files have changed' if files.empty?

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

  def github_dotcom_dest?
    destination_hostname == GITHUB_DOMAIN
  end

  def github_dotcom_origin?
    originating_hostname == GITHUB_DOMAIN
  end
end
