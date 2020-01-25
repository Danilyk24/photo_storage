# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yandex::BackupInfoService do
  let(:backup_secret) { 'very_secret' }

  before do
    allow(Rails.application.credentials).to receive(:backup_secret).and_return(backup_secret)
  end

  let(:token) do
    create :'yandex/token', dir: '/test',
                            other_dir: '/other',
                            access_token: API_ACCESS_TOKEN,
                            login: 'test@ya.ru'
  end

  let(:decoded_string) do
    src = Base64.decode64(encoded_string)

    decryptor = OpenSSL::Cipher::AES256.new(:CBC).decrypt.tap do |cipher|
      cipher.key = Digest::SHA256.digest(backup_secret)
      cipher.iv = Digest::MD5.digest(token.login)
    end

    decryptor.update(src) + decryptor.final
  end

  context 'when without backup secret' do
    let(:backup_secret) { nil }

    it do
      expect { described_class.new(token, :photos) }.to raise_error(/backup secret/)
    end
  end

  context 'when wrong resource' do
    it do
      expect { described_class.new(token, :wrong) }.
        to raise_error(described_class::WrongResourceError, 'wrong resource passed: "wrong"')
    end
  end

  context 'when photos' do
    subject(:encoded_string) do
      VCR.use_cassette('yandex_download_url_photos') { described_class.new(token, :photos).call }
    end

    it do
      expect(encoded_string).not_to be_empty

      expect(decoded_string).to include('https://downloader.disk.yandex.ru/zip/', 'test.zip', token.access_token)
    end
  end

  context 'when other' do
    subject(:encoded_string) do
      VCR.use_cassette('yandex_download_url_other') { described_class.new(token, 'other').call }
    end

    it do
      expect(encoded_string).not_to be_empty

      expect(decoded_string).to include('https://downloader.disk.yandex.ru/zip/', 'other.zip', token.access_token)
    end
  end

  context 'when path is blank' do
    let(:token) { create :'yandex/token', dir: nil }

    it do
      expect { described_class.new(token, :photos) }.
        to raise_error("no dir for photos for token #{token.id}")
    end
  end
end
