require 'active_record'
require 'rosette/core'

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

def print_progress(count, total, percentage, stage)
  stage_text = case stage
    when :finding_objects
      "Finding objects"
    when :finding_commit_ids
      "Finding commit ids"
  end

  STDOUT.write("\r#{stage_text}: #{count}/#{total}, #{percentage}%")
end

repo = Rosette::Core::Repo.from_path('/Users/legrandfromage/workspace/forrager/.git')
commit = repo.get_rev_commit("refs/heads/master")

factory = Rosette::Core::SnapshotFactory.new(repo, commit)
factory.filter_by_extensions(['.rb'])

progress_reporter = Rosette::Core::StagedProgressReporter.new
  .set_step(1)
  .on_progress { |*args| print_progress(*args) }
  .on_stage_finished { |*args| print_progress(*args) }
  .on_stage_changed do |old_stage, new_stage|
    STDOUT.write("\n")
  end
  .on_complete do
    STDOUT.write("\n")
  end

phrases = factory.take(progress_reporter).each_pair.flat_map do |file, sha|
  Phrase.where(file: file, commit_id: sha).map(&:key)
end

puts phrases
