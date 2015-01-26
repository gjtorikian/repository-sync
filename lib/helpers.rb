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

  def master_branch?(payload)
    payload['ref'] == 'refs/heads/master'
  end

  def do_the_work
    Resque.enqueue(CloneJob, @after_sha, @destination_hostname, @destination_repo, @originating_hostname, @originating_repo)
  end
end
