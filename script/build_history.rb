require 'java'
require 'active_record'
require 'rosette/core'
require 'rosette/extractors/ruby-extractor'
require 'pry-nav'

java_import 'org.eclipse.jgit.diff.DiffEntry'
java_import 'org.eclipse.jgit.lib.Repository'
java_import 'org.eclipse.jgit.revwalk.RevCommit'
java_import 'org.eclipse.jgit.revwalk.RevSort'
java_import 'org.eclipse.jgit.revwalk.RevWalk'

ActiveRecord::Base.establish_connection(
  host: 'localhost',
  adapter: 'mysql2',
  database: 'rosette',
  port: 3306,
  username: 'root',
  password: 'suck3rf4c3!',
  encoding: 'utf8'
)

class Phrase < ActiveRecord::Base
end

repo = Rosette::Core::Repo.from_path('/Users/legrandfromage/workspace/forrager/.git')
extractor = Rosette::Extractors::FastGettextExtractor.new

rev_walker = RevWalk.new(repo.jgit_repo).tap do |walker|
  walker.markStart(repo.get_rev_commit('refs/heads/master'))
  walker.sort(RevSort::REVERSE)
end

rev_walker.each do |cur_rev|
  puts cur_rev.getName
  repo.rev_diff_with_parent(cur_rev).each do |entry|
    if File.extname(entry.getNewPath) == '.rb'
      object_id = entry.getId(DiffEntry::Side::NEW).toObjectId

      commit_id = cur_rev.getName
      file = entry.getNewPath
      code = Java::JavaLang::String.new(repo.read_object_bytes(object_id), 'utf-8').to_s

      begin
        extractor.extract_each_from(code) do |phrase|
          phrase = Phrase.where(
            key: phrase.key,
            meta_key: phrase.meta_key,
            file: file,
            commit_id: commit_id
          ).first_or_initialize
          phrase.save
        end
      rescue Java::OrgJrubyparserLexer::SyntaxException => e
        puts "Unable to parse #{file} at #{commit_id}"
      end
    end
  end
end

rev_walker.dispose
