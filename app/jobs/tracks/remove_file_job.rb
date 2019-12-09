# frozen_string_literal: true

module Tracks
  class RemoveFileJob
    include Sidekiq::Worker

    def perform(yandex_token_id, storage_filename)
      token = ::Yandex::Token.find(yandex_token_id)

      Tracks::RemoveService.call!(
        storage_filename: storage_filename,
        yandex_token: token
      )
    end
  end
end
