# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ReadinessController, type: :request do
  context 'when everything is ok' do
    before { get api_v1_readiness_url }

    it do
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('OK')
    end
  end

  context 'when redis is unreachable' do
    before do
      allow(RedisClassy.redis).to receive(:ping).and_raise('boom!')
    end

    it do
      expect { get api_v1_readiness_url }.to raise_error('boom!')
    end
  end

  context 'when pg is unreachabled' do
    before do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise('boom!')
    end

    it do
      expect { get api_v1_readiness_url }.to raise_error('boom!')
    end
  end
end
