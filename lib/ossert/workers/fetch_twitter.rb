# frozen_string_literal: true

module Ossert
  module Workers
    # Sidekiq worker for fetching metrics from Twitter API
    class FetchTwitter
      include ::Sidekiq::Worker
      DEFER_TOKEN_DELTA = 15.seconds

      sidekiq_options queue: :twitter,
                      unique: :until_executing,
                      retry: 3

      sidekiq_retry_in do |_count, exception|
        case exception
        when Ossert::Twitter::TokensRotator::DeferedTokenError
          exception.defer_time - Time.now
       else
          raise
        end
      end

      def perform(project_name)
        Ossert.init
        project = Ossert::Project.load_by_name(project_name)

        Ossert::Fetch::Twitter.new(project, credentials).process

      rescue ::Twitter::Error::TooManyRequests => exception
        defer_time = exception.rate_limit.reset_at + DEFER_TOKEN_DELTA
        Ossert::Twitter::TokensRotator.defer_token(access_token, defer_time)
        raise exception
      end

      private

      def credentials
        access_token = Ossert::Twitter::TokensRotator.next_token
        Ossert::Twitter::Credentials.consumer_key.merge(access_token)
      end
    end
  end
end
