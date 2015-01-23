require 'spec_helper'

describe 'Main app' do
  let(:helpers) { TestHelper.new }
  let(:valid_sig) { 'sha1=3bcfd6f22fedc50ae777313cd6f0a9f0ae8e315b' }
  let(:incoming) { fixture('incoming.json') }

  it 'serves the index' do
    get '/'
    expect(last_response.body).to eql('I think you misunderstand how to use this.')
  end

  it 'serves nothing for any other page' do
    get '/test'
    expect(last_response.status).to eql(404)
  end

  describe 'signature verification' do
    it 'does not work if tokens do not match' do
      with_env('SECRET_TOKEN', 'notarealtoken') do
        expect(helpers.signatures_match?(incoming, valid_sig)).to eql(false)
      end
    end
    it 'does work if tokens match' do
      with_env('SECRET_TOKEN', 'sosecret') do
        expect(helpers.signatures_match?(incoming, valid_sig)).to eql(true)
      end
    end
  end

  describe 'payload processing' do
    let(:payload) { JSON.parse(incoming) }

    it 'processes a simple payload' do
      helpers.process_payload(payload)
      expect(helpers.instance_variable_get(:@originating_repo)).to eql('baxterthehacker/public-repo')
      expect(helpers.instance_variable_get(:@originating_hostname)).to eql('github.com')
    end
  end
end
