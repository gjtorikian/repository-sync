require 'spec_helper'

describe 'CloneJob' do
  before do
    ResqueSpec.reset!
  end

  after do
    FileUtils.rm_rf('spec/fixtures/working')
  end

  let(:dotcom_token) { 'dotcom_token' }
  let(:ghe_token) { 'ghe_token' }

  let(:destination_repo) { 'gjtorikian/destination_repo' }
  let(:originating_repo) { 'gjtorikian/originating_repo' }

  let(:dotcom_server) { 'github.com' }
  let(:ghe_server) { 'someserver.com' }

  let(:git_dir) { Git.clone(temp_repo, 'spec/fixtures/working') }

  it 'uses the right clone url' do
    CloneJob.instance_variable_set(:@dotcom_token, dotcom_token)
    CloneJob.instance_variable_set(:@ghe_token, ghe_token)

    token = CloneJob.clone_url_with_token(dotcom_server, originating_repo)
    expect(token).to eql('https://dotcom_token:x-oauth-basic@github.com/gjtorikian/originating_repo.git')

    token = CloneJob.clone_url_with_token(ghe_server, destination_repo)
    expect(token).to eql('https://ghe_token:x-oauth-basic@someserver.com/gjtorikian/destination_repo.git')
  end

  it 'sets up the machine user' do
    CloneJob.instance_variable_set(:@git_dir, git_dir)
    with_env('MACHINE_USER_NAME', 'Hubot') do
      CloneJob.setup_git
      expect(CloneJob.instance_variable_get(:@git_dir).config['user.name']).to eql('Hubot')
    end
    with_env('MACHINE_USER_EMAIL', 'hubot@email') do
      CloneJob.setup_git
      expect(CloneJob.instance_variable_get(:@git_dir).config['user.email']).to eql('hubot@email')
    end
  end

  it 'sets up Octokit' do
    CloneJob.instance_variable_set(:@dotcom_token, dotcom_token)
    CloneJob.instance_variable_set(:@ghe_token, ghe_token)

    CloneJob.instance_variable_set(:@destination_hostname, dotcom_server)
    client = CloneJob.setup_octokit
    expect(client.api_endpoint).to eql('https://api.github.com/')
    expect(client.access_token).to eql(dotcom_token)

    CloneJob.instance_variable_set(:@destination_hostname, ghe_server)
    client = CloneJob.setup_octokit
    expect(client.api_endpoint).to eql('https://someserver.com/api/v3/')
    expect(client.access_token).to eql(ghe_token)
  end

  describe 'api actions' do
    let(:compare_no_files) { JSON.parse fixture('compare_no_files.json') }
    let(:compare_some_files) { JSON.parse fixture('compare_some_files.json') }
    # octokit returns a Sawyer hash with symbolized keys
    let(:create_pr) { JSON.parse(fixture('create_pr.json')).inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} }

    before do
      CloneJob.instance_variable_set(:@dotcom_token, dotcom_token)
      CloneJob.instance_variable_set(:@destination_hostname, dotcom_server)
      CloneJob.instance_variable_set(:@client, CloneJob.setup_octokit)
      CloneJob.instance_variable_set(:@destination_repo, 'wherever')
    end

    it 'compares and merges and empty files' do
      expect(CloneJob.instance_variable_get(:@client)).to \
            receive(:compare).and_return(compare_no_files)
      expect { CloneJob.check_and_merge('somebranch') }.to \
            output("Not creating a PR, no files have changed!\n").to_stdout
    end

    it 'compares and merges and files with the default text' do
      expect(CloneJob.instance_variable_get(:@client)).to \
            receive(:compare).and_return(compare_some_files)
      expect(CloneJob.instance_variable_get(:@client)).to \
            receive(:create_pull_request).with('wherever', \
                                               'master', 'somebranch', \
                                               'Sync changes from upstream repository', \
                                               "\n\n### Added files: \n\n* file1.txt\n* file3.txt\n\n### Removed files: \n\n* file2.txt")
        .and_return(create_pr)

      expect(CloneJob.instance_variable_get(:@client)).to \
            receive(:merge_pull_request).with('wherever', 1347)

      CloneJob.check_and_merge('somebranch')
    end

    it 'compares and merges and files with the custom text' do
      with_env('wherever_PR_TITLE', 'Hey now') do
        expect(CloneJob.instance_variable_get(:@client)).to \
        receive(:compare).and_return(compare_some_files)

        expect(CloneJob.instance_variable_get(:@client)).to \
        receive(:create_pull_request).with('wherever', \
                                           'master', 'somebranch', \
                                           'Hey now', \
                                           "\n\n### Added files: \n\n* file1.txt\n* file3.txt\n\n### Removed files: \n\n* file2.txt")
          .and_return(create_pr)

        expect(CloneJob.instance_variable_get(:@client)).to \
          receive(:merge_pull_request).with('wherever', 1347)

        CloneJob.check_and_merge('somebranch')
      end

      with_env('wherever_PR_BODY', 'Great job or whatever') do
        expect(CloneJob.instance_variable_get(:@client)).to \
        receive(:compare).and_return(compare_some_files)

        expect(CloneJob.instance_variable_get(:@client)).to \
        receive(:create_pull_request).with('wherever', \
                                           'master', 'somebranch', \
                                           'Sync changes from upstream repository', \
                                           'Great job or whatever')
          .and_return(create_pr)

        expect(CloneJob.instance_variable_get(:@client)).to \
        receive(:merge_pull_request).with('wherever', 1347)

        CloneJob.check_and_merge('somebranch')
      end
    end
  end
end
