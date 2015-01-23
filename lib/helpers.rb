require 'fileutils'
require_relative './clone_job'

module Helpers
  def signatures_match?(payload_body, github_signature)
    return true if Sinatra::Base.development?
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload_body)
    Rack::Utils.secure_compare(signature, github_signature)
  end

  def process_payload(payload)
    @originating_repo = "#{payload['repository']['owner']['name']}/#{payload['repository']['name']}"
    @originating_hostname = payload['repository']['url'].match(%r{//(.+?)/})[1]
    @after_sha = payload['after']
  end

  def dotcom_token
    ENV['DOTCOM_MACHINE_USER_TOKEN']
  end

  def ghe_token
    ENV['GHE_MACHINE_USER_TOKEN']
  end

  def master_branch?(payload)
    payload['ref'] == 'refs/heads/master'
  end

  def do_the_work(is_public)
    in_tmpdir do |tmpdir|
      Resque.enqueue(CloneJob, tmpdir, @after_sha, dotcom_token, ghe_token, @destination_hostname, @destination_repo, @originating_hostname, @originating_repo, is_public)
    end
  end

  def in_tmpdir
    path = File.expand_path "#{Dir.tmpdir}/repository-sync/repos/#{Time.now.to_i}#{rand(1000)}/"
    FileUtils.mkdir_p path
    puts "Directory created at: #{path}"
    yield path
  ensure
    FileUtils.rm_rf(path) if File.exist?(path) && !Sinatra::Base.development?
  end
end
