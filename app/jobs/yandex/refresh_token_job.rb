module Yandex
  class RefreshTokenJob
    include Sidekiq::Worker

    def perform(token_id)
      token = Token.find(token_id)

      RedisMutex.with_lock("yandex_token:#{token_id}:refresh", block: 30.seconds, expire: 10.minutes) do
        RefreshTokenService.call!(token: token)
        RefreshQuotaService.call!(token: token)
      end
    end
  end
end
