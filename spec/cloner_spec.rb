require 'spec_helper'

describe 'Cloner' do

  let(:cloner) { Cloner.new({
      :dotcom_token     => "dotcom_token",
      :ghe_token        => "ghe_token",
      :destination_repo => "gjtorikian/destination_repo",
      :originating_repo => "gjtorikian/originating_repo",
      :ghe_server       => "someserver.com",
      :git              => Git.clone( fixture_path("gjtorikian/destination_repo"), "#{tmpdir}/gjtorikian/destination_repo"),
      :tmpdir           => tmpdir
  })}

  before do
    setup_tmpdir
    cloner.logger.level = Logger::WARN
  end

  it "sets the token" do
    expect(cloner.token).to eql("dotcom_token")
  end

  it "knows to use the ghe token" do
    cloner.destination_hostname = "someserver.com"
    expect(cloner.token).to eql("ghe_token")
  end

  it "creates the remote name" do
    expect(cloner.remote_name).to match(/otherrepo-[\d]+/)
  end

  it "creates the branch name" do
    expect(cloner.branch_name).to match(/update-[\d]+/)
  end

  it "creates the safe repo name" do
    expect(cloner.safe_destination_repo).to eql("gjtorikian_destination_repo")
  end

  it "defaults to the default commit message" do
    expect(cloner.commit_message).to eql("Sync changes from upstream repository")
  end

  it "uses a user-supplied commit message" do
    with_env "GJTORIKIAN_DESTINATION_REPO_COMMIT_MESSAGE", "Some message" do
      expect(cloner.commit_message).to eql("Some message")
    end
  end

  it "knows the changed files" do
    url = "https://api.github.com/repos/gjtorikian/destination_repo/compare/master...#{cloner.branch_name}"
    stub_request(:get, url).
    to_return(:status => 200, :body => fixture("compare_some_files.json"), :headers => { 'Content-Type' => 'application/json' })
    expect(cloner.files.count).to eql(3)
  end

  it "generates the clone url with token" do
    expected = "https://dotcom_token:x-oauth-basic@github.com/gjtorikian/originating_repo.git"
    expect(cloner.clone_url_with_token).to eql(expected)
  end

  it "defaults to the default pull request title" do
    expect(cloner.pull_request_title).to eql("Sync changes from upstream repository")
  end

  it "respects user supplied pull-request titles" do
    with_env "GJTORIKIAN_DESTINATION_REPO_PR_TITLE", "Some title" do
      expect(cloner.pull_request_title).to eql("Some title")
    end
  end

  it "geneates the pull request body" do
    url = "https://api.github.com/repos/gjtorikian/destination_repo/compare/master...#{cloner.branch_name}"
    stub_request(:get, url).
    to_return(:status => 200, :body => fixture("compare_some_files.json"), :headers => { 'Content-Type' => 'application/json' })

    expected = "### Added files: \n\n* file1.txt\n* file3.txt\n\n### Removed files: \n\n* file2.txt\n\n"
    expect(cloner.pull_request_body).to eql(expected)
  end

  it "respects user-supplied pull-request bodies" do
    with_env "GJTORIKIAN_DESTINATION_REPO_PR_BODY", "Some body" do
      expect(cloner.pull_request_body).to eql("Some body")
    end
  end

  it "initializes octokit" do
    expect(cloner.client.class).to eql(Octokit::Client)
    expect(cloner.client.api_endpoint).to eql('https://api.github.com/')
    expect(cloner.client.access_token).to eql("dotcom_token")
  end

  it "clones the repo" do
    expect(cloner.git.class).to eql(Git::Base)
    expect(Dir.exists?("#{tmpdir}/gjtorikian/destination_repo")).to eql(true)
  end

  it "runs a command" do
    expect(cloner.run_command("echo", "foo")).to eql("foo\n")
  end

  it "reports errors" do
    stub = stub_request(:post, "https://api.github.com/repos/gjtorikian/originating_repo/issues").
    with(:body => "{\"labels\":[],\"title\":\"Merge conflict detected\",\"body\":\"Hey, I'm really sorry about this, but there was a merge conflict when I tried to auto-sync the last time, from :\\n\\n```\\nfoo\\nMerge error\\nbar\\n```\\nYou'll have to resolve this problem manually, I'm afraid.\\n![I'm so sorry](http://media.giphy.com/media/NxKcqJI6MdIgo/giphy.gif)\"}").
    to_return( :status => 204)

    output = "foo\nMerge error\nbar"

    cloner.report_error(output)
    expect(stub).to have_been_requested
  end

  it "doesn't report non-errors" do
    cloner.report_error("asdf")
    expect(WebMock).not_to have_requested(:post, "github.com")
  end

  it "adds the remote" do
    expect(cloner.git.remotes.count).to eql(1)
    cloner.add_remote
    expect(cloner.git.remotes.count).to eql(2)
  end

  it "fetches the repo" do
    cloner.instance_variable_set("@clone_url_with_token", fixture_path("/gjtorikian/originating_repo"))
    cloner.add_remote
    cloner.fetch
  end

  it "merges the changes" do
    cloner.instance_variable_set("@clone_url_with_token", fixture_path("/gjtorikian/originating_repo"))
    cloner.git
    cloner.add_remote
    cloner.fetch
    commits = cloner.git.log.count
    output = cloner.merge
    expect(output).to match(/1 file changed, 1 insertion/)
    expect(output).to match(/create mode 100644 file2.md/)
    expect(cloner.git.log.count).to eql(commits + 2)
  end

  it "squashes the changes when public" do
    cloner.instance_variable_set("@clone_url_with_token", fixture_path("/gjtorikian/originating_repo"))
    cloner.public = true
    cloner.git
    cloner.add_remote
    cloner.fetch
    commits = cloner.git.log.count
    output = cloner.merge
    expect(output).to match(/1 file changed, 1 insertion/)
    expect(output).to match(/create mode 100644 file2.md/)
    expect(cloner.git.log.count).to eql(commits + 1) # Ensure the squash
  end

  it "creates a pull request" do
    url = "https://api.github.com/repos/gjtorikian/destination_repo/compare/master...#{cloner.branch_name}"
    stub_request(:get, url).
    to_return(:status => 200, :body => fixture("compare_some_files.json"), :headers => { 'Content-Type' => 'application/json' })

    cloner.instance_variable_set("@clone_url_with_token", fixture_path("/gjtorikian/originating_repo"))

    stub = stub_request(:post, "https://api.github.com/repos/gjtorikian/destination_repo/pulls").
    to_return( :status => 204, :body => fixture("create_pr.json"), :headers => { 'Content-Type' => 'application/json' })

    stub2 = stub_request(:put, "https://api.github.com/repos/gjtorikian/destination_repo/pulls/1347/merge").
    to_return(:status => 200)

    cloner.git
    cloner.add_remote
    cloner.fetch
    cloner.merge
    cloner.create_pull_request
    expect(stub).to have_been_requested
  end

  it "merges the pull request" do
    url = "https://api.github.com/repos/gjtorikian/destination_repo/compare/master...#{cloner.branch_name}"
    stub_request(:get, url).
    to_return(:status => 200, :body => fixture("compare_some_files.json"), :headers => { 'Content-Type' => 'application/json' })

    stub_request(:post, "https://api.github.com/repos/gjtorikian/destination_repo/pulls").
    to_return( :status => 204, :body => fixture("create_pr.json"), :headers => { 'Content-Type' => 'application/json' })

    cloner.instance_variable_set("@clone_url_with_token", fixture_path("/gjtorikian/originating_repo"))

    stub = stub_request(:put, "https://api.github.com/repos/gjtorikian/destination_repo/pulls/1347/merge").
    to_return(:status => 200)

    cloner.git
    cloner.add_remote
    cloner.fetch
    cloner.merge
    cloner.create_pull_request
    expect(stub).to have_been_requested
  end

  it "deletes the branch" do
    stub = stub_request(:delete, "https://api.github.com/repos/gjtorikian/destination_repo/git/refs/heads/#{cloner.branch_name}").
    to_return(:status => 200)

    cloner.delete_branch
    expect(stub).to have_been_requested
  end
end
