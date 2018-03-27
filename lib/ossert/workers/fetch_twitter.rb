# frozen_string_literal: true

module Ossert
  module Workers
    # Sidekiq worker for fetching metrics from Twitter API
    class FetchTwitter
      include ::Sidekiq::Worker
      RATE_LIMIT_ERROR_RETRY_DELTA = 15.seconds

      sidekiq_options queue: :twitter,
                      unique: :until_executing,
                      retry: 3

      sidekiq_retry_in do |_count, exception|
        case exception
        when ::Twitter::Error::TooManyRequests
          (exception.rate_limit.reset_at - Time.now) + RATE_LIMIT_ERROR_RETRY_DELTA
        else
          raise
        end
      end

      def perform(project_name)
        Ossert.init
        project = Ossert::Project.load_by_name(project_name)

        Ossert::Fetch::Twitter.new(project).process
      end
    end
  end
end
