# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::Yandex::VerificationCodesController, type: :request do
  describe '#show' do
    before do
      allow(::Yandex::CreateOrUpdateTokenJob).to receive(:perform_async)
    end

    context 'when code presents' do
      before { get admin_yandex_verification_code_url(code: '999') }

      it do
        expect(::Yandex::CreateOrUpdateTokenJob).to have_received(:perform_async)
        expect(response).to redirect_to(admin_yandex_tokens_path)
        expect(flash[:notice]).to eq I18n.t('admin.yandex.token_performed')
      end
    end

    context 'when without code' do
      let(:request) { get admin_yandex_verification_code_url(code1: '999') }

      it do
        expect { request }.to raise_error(ActionController::ParameterMissing)
      end
    end
  end
end
