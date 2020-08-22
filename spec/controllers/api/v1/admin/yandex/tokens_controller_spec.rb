# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Admin::Yandex::TokensController, type: :request do
  let(:json) { JSON.parse(response.body) }
  let!(:token) { create :'yandex/token', dir: '/test', other_dir: '/other', access_token: API_ACCESS_TOKEN }

  describe '#index' do
    context 'when without resources' do
      before { get api_v1_admin_yandex_tokens_url }

      it do
        expect(response).to have_http_status(:ok)
        expect(json).to be_empty
      end
    end

    context 'when photos' do
      before do
        create :photo, yandex_token: token, storage_filename: 'test'

        get api_v1_admin_yandex_tokens_url
      end

      it do
        expect(response).to have_http_status(:ok)

        expect(json).to eq(
          [
            {
              'id' => token.id,
              'login' => token.login,
              'type' => 'photos'
            }
          ]
        )
      end
    end

    context 'when photos and tracks' do
      before do
        create :photo, yandex_token: token, storage_filename: 'test'
        create :track, yandex_token: token, storage_filename: 'test'

        get api_v1_admin_yandex_tokens_url
      end

      let(:response_tokens) do
        [
          {
            'id' => token.id,
            'login' => token.login,
            'type' => 'photos'
          },
          {
            'id' => token.id,
            'login' => token.login,
            'type' => 'other'
          }
        ]
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(json).to match_array(response_tokens)
      end
    end

    context 'when multiple tokens' do
      let!(:another_token) { create :'yandex/token' }
      let(:response_tokens) do
        [
          {
            'id' => token.id,
            'login' => token.login,
            'type' => 'photos'
          },
          {
            'id' => token.id,
            'login' => token.login,
            'type' => 'other'
          },
          {
            'id' => another_token.id,
            'login' => another_token.login,
            'type' => 'photos'
          }
        ]
      end

      before do
        create :photo, yandex_token: token, storage_filename: 'test'
        create :photo, yandex_token: another_token, storage_filename: 'test'

        create :track, yandex_token: token, storage_filename: 'test'

        get api_v1_admin_yandex_tokens_url
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(json).to match_array(response_tokens)
      end
    end
  end

  describe '#show' do
    around do |example|
      Sidekiq::Testing.fake! { example.run }
    end

    after { Sidekiq::Worker.clear_all }

    context 'when wrong resource' do
      it do
        expect { get api_v1_admin_yandex_token_url(id: token.id, resource: :wrong) }.
          to raise_error(Yandex::BackupInfoService::WrongResourceError)
      end
    end

    context 'when enqueue' do
      it do
        expect { get api_v1_admin_yandex_token_url(id: token.id, resource: :photos) }.
          to change { Yandex::BackupInfoJob.jobs.size }.by(1)

        expect(response).to have_http_status(:accepted)
        expect(response.body).to be_empty
      end
    end

    context 'when job already enqueued' do
      before { RedisClassy.redis.set("backup_info:#{token.id}:photos", nil) }

      it do
        expect { get api_v1_admin_yandex_token_url(id: token.id, resource: :photos) }.
          not_to(change { Yandex::BackupInfoJob.jobs.size })

        expect(response).to have_http_status(:accepted)
        expect(response.body).to be_empty
      end
    end

    context 'when job finished' do
      before { RedisClassy.redis.set("backup_info:#{token.id}:photos", 'value') }

      it do
        expect { get api_v1_admin_yandex_token_url(id: token.id, resource: :photos) }.
          not_to(change { Yandex::BackupInfoJob.jobs.size })

        expect(response).to have_http_status(:ok)
        expect(json['info']).to eq('value')
      end
    end

    context 'when wrong token' do
      it do
        expect { get api_v1_admin_yandex_token_url(id: token.id * 2, resource: :photos) }.
          to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when without resource param' do
      it do
        expect { get api_v1_admin_yandex_token_url(id: token.id) }.
          to raise_error(ActionController::ParameterMissing)
      end
    end
  end
end
