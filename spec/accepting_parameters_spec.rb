require 'spec_helper'

describe 'endpoints' do
  let(:helpers) { TestHelper.new }
  let(:incoming) { fixture('incoming.json') }
  let(:non_master_payload) { incoming.sub('refs/heads/master', 'refs/heads/gh-pages') }

  before do
    allow_any_instance_of(app).to receive(:signatures_match?).and_return(true)
    ResqueSpec.reset!
  end

  describe 'updating public repositories' do
    it 'does nothing without a body' do
      expect(app).to_not receive(:process_payload)
      post '/update_public'
      expect(last_response.status).to eql(500)
      expect(last_response.body).to eql('Missing body payload!')
    end

    it 'does nothing without the right params' do
      expect(app).to_not receive(:process_payload)
      post '/update_public', incoming
      expect(last_response.status).to eql(500)
      expect(last_response.body).to eql('Missing `dest_repo` argument')
    end

    it 'does nothing if payload is not for master' do
      expect(app).to_not receive(:process_payload)
      post '/update_public?dest_repo=gjtorikian/fake', non_master_payload
      expect(last_response.status).to eql(202)
      expect(last_response.body).to eql('Payload was not for master, was for refs/heads/gh-pages, aborting.')
    end

    it 'can work' do
      post '/update_public?dest_repo=gjtorikian/fake', incoming
      expect(last_response.status).to eql(200)
      expect(CloneJob).to have_queue_size_of(1)
    end
  end

  describe 'updating a private repository' do
    it 'does nothing without a body' do
      expect(app).to_not receive(:process_payload)
      post '/update_private'
      expect(last_response.status).to eql(500)
      expect(last_response.body).to eql('Missing body payload!')
    end

    it 'does nothing without the right params' do
      expect(app).to_not receive(:process_payload)
      post '/update_private', incoming
      expect(last_response.status).to eql(500)
      expect(last_response.body).to eql('Missing `dest_repo` argument')
    end

    it 'does nothing if payload is not for master' do
      expect(app).to_not receive(:process_payload)
      post '/update_private?dest_repo=gjtorikian/fake', non_master_payload
      expect(last_response.status).to eql(202)
      expect(last_response.body).to eql('Payload was not for master, was for refs/heads/gh-pages, aborting.')
    end

    it 'can work' do
      post '/update_private?dest_repo=gjtorikian/fake', incoming
      expect(last_response.status).to eql(200)
      expect(CloneJob).to have_queue_size_of(1)
    end
  end
end
