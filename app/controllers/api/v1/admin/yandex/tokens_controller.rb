# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Yandex
        class TokensController < BaseController
          # dumb api for my NAS :-)
          def index
            @resources = ::Yandex::ResourceFinder.call.each_with_object([]) do |token, memo|
              resource = {token: token}

              memo << resource.merge(type: :photos) if token.photos_present
              memo << resource.merge(type: :other) if token.other_present
            end
          end
        end
      end
    end
  end
end
