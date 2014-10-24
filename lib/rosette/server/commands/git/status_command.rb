# encoding: UTF-8

module Rosette
  module Server
    module Commands

      # A show is really just a diff with your parent
      class StatusCommand < GitCommand
        include WithRepoName
        include WithRef

        def execute
          locales = get_repo(repo_name).locales.map(&:code)

          datastore.commit_log_status(repo_name, commit_id).tap do |status|
            if status
              status[:locales] = fill_in_missing_locales(locales, status)
            end
          end
        end

        def fill_in_missing_locales(locales, status)
          locales.map do |locale|
            found_locale = status[:locales].find do |status_locale|
              status_locale[:locale] == locale
            end

            if found_locale
              found_locale
            else
              {
                locale: locale,
                percent_translated: 0.0,
                translated_count: 0
              }
            end
          end
        end
      end

    end
  end
end
