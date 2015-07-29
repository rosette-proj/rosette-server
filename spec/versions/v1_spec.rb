# encoding: UTF-8

require 'spec_helper'

include Rosette::Core
include Rosette::Core::Commands

describe Rosette::Server::ApiV1 do
  include Rack::Test::Methods

  let(:version) { 'v1' }
  let(:repo_name) { 'my_repo' }
  let(:ref) { 'master' }

  # NOTE:
  # Creating an instance of the API on each test run reeeeeally slows down the
  # test suite. Best guess it's because of Grape's internal metaprogramming
  # spaghetti mess. Since none of the tests/endpoints change the state of the
  # system, it should be safe to set global $app and $config variables here.

  let(:app) do
    $app ||= Rosette::Server::ApiV1.new(configuration)
  end

  let(:configuration) do
    $config ||= Rosette.build_config do |config|
      config.use_error_reporter(BufferedErrorReporter.new)
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_locales(%w(es ko-KR))
      end
    end
  end

  def expect_command(klass, endpoint)
    expect(endpoint).to(
      receive(:validate_and_execute)
        .with(kind_of(klass))
        .and_wrap_original do |m, command|
          yield command if block_given?
          m.call(command)
        end
    )
  end

  let(:body) { JSON.parse(last_response.body) }
  let(:status) { last_response.status }

  def visit
    get(path, params)
  end

  def make_phrase(key, meta_key)
    Rosette::Core::Phrase.new(key, meta_key)
  end

  shared_examples 'an invalid command' do
    it 'renders a 400 when command is invalid' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(command_klass, endpoint) do |command|
          expect(command).to receive(:valid?).and_return(false)
        end
      end

      visit
      expect(status).to eq(400)
    end

    it 'renders a 500 after encountering an unexpected error' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(command_klass, endpoint) do |command|
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_raise(RuntimeError, 'oops!')
        end
      end

      visit
      expect(status).to eq(500)

      expect(configuration.error_reporter.errors_found?).to eq(true)
      error = configuration.error_reporter.errors.first
      expect(error[:error]).to be_a(RuntimeError)
      expect(error[:error].message).to eq('oops!')
    end
  end

  after(:each) do
    Grape::Endpoint.before_each(nil)
  end

  describe '/alive.json' do
    let(:params) { {} }
    let(:path) { "#{version}/alive.json" }
    let(:body) { last_response.body }  # override

    it "always returns a simple plaintext 'true'" do
      visit
      expect(status).to eq(200)
      expect(body).to eq('true')
    end
  end

  describe '/locales.json' do
    let(:params) { { repo_name: repo_name } }
    let(:path) { "#{version}/locales.json" }

    it 'returns a list of the locales the repo supports' do
      visit
      expect(status).to eq(200)

      expect(body).to eq([
        { 'language' => 'es', 'territory' => nil, 'code' => 'es' },
        { 'language' => 'ko', 'territory' => 'KR', 'code' => 'ko-KR' }
      ])
    end

    it 'renders a 500 if an error is raised' do
      expect(configuration).to receive(:get_repo).and_raise(RuntimeError)
      visit
      expect(status).to eq(500)
      expect(body).to include('error')
    end
  end

  describe '/git/commit.json' do
    let(:params) { { repo_name: repo_name, ref: ref } }
    let(:path) { "#{version}/git/commit.json" }

    it 'fetches, commits, and shows' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(FetchCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute)
        end

        expect_command(CommitCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute)
        end

        expect_command(ShowCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_return(
            'added' => %w(a b c), 'removed' => %w(d), 'modified' => %w(e f g h)
          )
        end
      end

      visit
      expect(status).to eq(200)

      expect(body).to eq(
        'added' => 3, 'removed' => 1, 'modified' => 4
      )
    end

    describe 'error conditions' do
      let(:command_klass) { FetchCommand }
      it_behaves_like 'an invalid command'
    end
  end

  describe '/git/show.json' do
    let(:params) { { repo_name: repo_name, ref: ref } }
    let(:path) { "#{version}/git/show.json" }

    it 'executes an instance of ShowCommand' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(ShowCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_return(
            'added' => [make_phrase('foo', 'bar')],
            'removed' => [make_phrase('baz', 'boo'), make_phrase('biz', 'bat')]
          )
        end
      end

      visit
      expect(status).to eq(200)

      expect(body.keys).to eq(%w(added removed))
      expect(body['added'].size).to eq(1)
      expect(body['added'].first['key']).to eq('foo')
      expect(body['removed'].size).to eq(2)
      expect(body['removed'].first['key']).to eq('baz')
      expect(body['removed'].last['key']).to eq('biz')
    end

    describe 'error conditions' do
      let(:command_klass) { ShowCommand }
      it_behaves_like 'an invalid command'
    end
  end

  describe '/git/status.json' do
    let(:params) { { repo_name: repo_name, ref: ref } }
    let(:path) { "#{version}/git/status.json" }

    before(:each) do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(StatusCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_return(status_response)
        end
      end
    end

    context 'with a normal status' do
      let(:status_response) { { status: 'foo' } }

      it 'executes an instance of StatusCommand' do
        visit
        expect(status).to eq(200)
        expect(body).to eq('status' => 'foo')
      end
    end

    context 'with a nil status' do
      let(:status_response) { nil }

      it 'renders a 500 if the status is nil' do
        visit
        expect(status).to eq(500)
        expect(body).to include('error')
      end
    end
  end

  describe '/git/diff.json' do
    let(:params) do
      { repo_name: repo_name, head_ref: 'my_branch', diff_point_ref: ref }
    end

    let(:path) { "#{version}/git/diff.json" }

    it 'executes an instance of DiffCommand' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(DiffCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.head_commit_str).to eq('my_branch')
          expect(command.diff_point_commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_return(
            'added' => [make_phrase('foo', 'bar')],
            'removed' => [make_phrase('baz', 'boo'), make_phrase('biz', 'bat')]
          )
        end
      end

      visit
      expect(status).to eq(200)

      expect(body.keys).to eq(%w(added removed))
      expect(body['added'].size).to eq(1)
      expect(body['added'].first['key']).to eq('foo')
      expect(body['removed'].size).to eq(2)
      expect(body['removed'].first['key']).to eq('baz')
      expect(body['removed'].last['key']).to eq('biz')
    end

    describe 'error conditions' do
      let(:command_klass) { DiffCommand }
      it_behaves_like 'an invalid command'
    end
  end

  describe '/git/snapshot.json' do
    let(:params) do
      { repo_name: repo_name, ref: ref }
    end

    let(:path) { "#{version}/git/snapshot.json" }

    it 'executes an instance of SnapshotCommand' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(SnapshotCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_return(
            [make_phrase('foo', 'bar')]
          )
        end
      end

      visit
      expect(status).to eq(200)

      expect(body.first['key']).to eq('foo')
      expect(body.first['meta_key']).to eq('bar')
    end

    describe 'error conditions' do
      let(:command_klass) { SnapshotCommand }
      it_behaves_like 'an invalid command'
    end
  end

  describe '/git/repo_snapshot.json' do
    let(:params) do
      { repo_name: repo_name, ref: ref }
    end

    let(:path) { "#{version}/git/repo_snapshot.json" }

    it 'executes an instance of RepoSnapshotCommand' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(RepoSnapshotCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute).and_return('foo' => 'bar')
        end
      end

      visit
      expect(status).to eq(200)
      expect(body).to eq('foo' => 'bar')
    end

    describe 'error conditions' do
      let(:command_klass) { RepoSnapshotCommand }
      it_behaves_like 'an invalid command'
    end
  end

  describe '/translations/export.json' do
    let(:params) do
      { repo_name: repo_name, ref: ref, locale: 'es', serializer: 'fake' }
    end

    let(:path) { "#{version}/translations/export.json" }

    it 'executes an instance of ExportCommand' do
      Grape::Endpoint.before_each do |endpoint|
        expect_command(ExportCommand, endpoint) do |command|
          expect(command.repo_name).to eq(repo_name)
          expect(command.commit_str).to eq(ref)
          expect(command.locale).to eq('es')
          expect(command.serializer).to eq('fake')
          expect(command).to receive(:valid?).and_return(true)
          expect(command).to receive(:execute)
        end
      end

      visit
      expect(status).to eq(200)
    end

    describe 'error conditions' do
      let(:command_klass) { ExportCommand }
      it_behaves_like 'an invalid command'
    end
  end

  end
end
