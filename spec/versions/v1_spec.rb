require 'spec_helper'
require 'pry'

describe Rosette::Server::V1 do
  include Rack::Test::Methods

  let(:repo) { TmpRepo.new }
  let(:repo_name) { 'pretty-cool-repo' }
  let(:ref) { repo.git("log -1 --pretty=%H").chomp }
  let(:yaml_path) { 'test.yml' }
  let(:locales) { %w(en-US de-DE es) }
  let(:bogus_ref) { 'bogusref' }

  let(:configuration) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_locales(locales)
        repo_config.set_path(File.join(repo.working_dir, '/.git'))

        repo_config.add_extractor('yaml/rails') do |ext|
          ext.set_conditions do |cond|
            cond.match_file_extension('.yml').and(
              cond.match_path(yaml_path)
            )
          end
        end
      end
    end
  end

  def app
    Rosette::Server::V1
  end

  before do
    Rosette::Server::V1.set_configuration(configuration)
    repo.create_file(yaml_path) do |f|
      f.write("en:\n  test: Here is a test string\n") # FIXME use YamlStore
    end
    repo.add_all
    repo.commit("here is a commit message")

    # Can't fetch b/c there is no origin...probably a better way to do this
    allow_any_instance_of(Rosette::Core::Commands::FetchCommand).to receive(:execute) { double('execute') }
  end

  shared_examples 'a malformed request' do
    subject { get(path, params) }

    it 'returns a 400' do
      expect(subject.status).to eq(400)
    end
  end

  describe 'GET /v1/extractors/list' do
    subject { JSON.parse(get('/v1/extractors/list').body) }

    it 'returns a list of configured extractors' do
      expect(subject[repo_name]).to be_instance_of(Array)
      expect(subject[repo_name].first).to match(/RailsExtractor/)
    end
  end

  describe 'Git commands' do


    before do

    end

    describe 'GET /v1/git/commit' do
      let(:path) { '/v1/git/commit' }
      let(:params) { { repo_name: repo_name, ref: bogus_ref } }

      it_should_behave_like 'a malformed request'

      context 'with required parameters present' do
        let(:params) { { repo_name: repo_name, ref: ref } }

        it 'stores the phrase for that commit' do
          get(path, params)
          phrase = phrase_model.first
          expect(phrase_model.count).to eq(1)
          expect(phrase.commit_id).to eq(ref)
          expect(phrase.key).to eq("Here is a test string")
        end
      end
    end

    describe 'GET /v1/git/show' do
      let(:path) { '/v1/git/show' }
      let(:params) { { repo_name: repo_name, ref: bogus_ref } }

      it_should_behave_like 'a malformed request'

      context 'with required parameters present' do
        let(:params) { { repo_name: repo_name, ref: ref } }

        before do
          get('/v1/git/commit', params)
        end

        subject { JSON.parse(get(path, params).body) }

        it 'contains keys for added, deleted and modified strings' do
          expect(subject).to include('added', 'removed', 'modified')
        end

        it 'lists the phrases added in the commit' do
          expect(subject['added'].first['key']).to eq('Here is a test string')
        end
      end

    end

    describe 'GET /v1/git/status' do
      let(:path) { '/v1/git/status' }
      let(:params) { { repo_name: repo_name, ref: bogus_ref } }

      it_should_behave_like 'a malformed request'

      subject { JSON.parse(get(path, params).body) }

      context 'with required parameters present' do
        let(:params) { { repo_name: repo_name, ref: ref } }

        it 'gives the translation progress for a given commit' do
          # binding.pry
        end
      end

    end

  end

  describe 'Translations commands' do
    describe 'GET /v1/translations/add_or_update' do
      let(:path) { '/v1/translations/add_or_update' }

      let(:locale) { 'de-DE' }
      let(:key) { 'Here is a test string' }
      let(:meta_key) { 'test' }
      let(:translation) { 'Some German' }
      let(:params) do
        {
          repo_name: repo_name,
          ref: ref,
          locale: locale,
          key: key,
          meta_key: meta_key,
          translation: translation
        }
      end


      subject { JSON.parse(get(path, params).body) }

      before do
        get('/v1/git/commit', { repo_name: repo_name, ref: ref } )
      end

      context 'with both key and meta_key not present' do
        let(:meta_key) { nil }
        let(:key) { nil }

        it 'raises an error' do
          expect { subject }.to raise_error(Rosette::DataStores::Errors::PhraseNotFoundError)
        end
      end

      context 'when the locale is not supported by the server' do
        let(:unsupported_locale) { 'en-PI' }
        let(:locale) { unsupported_locale }

        it 'raises an error' do
          expect(subject['error']).to match(/doesn't support the \'#{locale}\' locale/)
        end
      end

      context 'when a key is present and a meta_key is not' do
        it 'does something cool' do
          subject
        end
      end

      context 'when a meta_key is present and a key is not' do

      end
    end
  end

  def phrase_model
    Rosette::DataStores::InMemoryDataStore::Phrase
  end


end
