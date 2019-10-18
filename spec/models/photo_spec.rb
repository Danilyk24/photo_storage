# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Photo do
  describe 'structure' do
    it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false, limit: 512) }
    it { is_expected.to have_db_column(:description).of_type(:text) }

    it { is_expected.to have_db_column(:rubric_id).of_type(:integer).with_options(null: false, foreign_key: true) }
    it { is_expected.to have_db_column(:yandex_token_id).of_type(:integer).with_options(null: true, foreign_key: true) }

    it { is_expected.to have_db_column(:storage_filename).of_type(:text) }
    it { is_expected.to have_db_column(:local_filename).of_type(:text) }

    it { is_expected.to have_db_column(:exif).of_type(:jsonb) }
    it { is_expected.to have_db_column(:lat_long).of_type(:point) }
    it { is_expected.to have_db_column(:original_filename).of_type(:string).with_options(null: false, limit: 512) }
    it { is_expected.to have_db_column(:original_timestamp).of_type(:datetime).with_options(null: true) }
    it { is_expected.to have_db_column(:size).of_type(:integer).with_options(null: false, default: 0) }
    it { is_expected.to have_db_column(:content_type).of_type(:string).with_options(null: false, limit: 30) }
    it { is_expected.to have_db_column(:width).of_type(:integer).with_options(null: false, default: 0) }
    it { is_expected.to have_db_column(:height).of_type(:integer).with_options(null: false, default: 0) }
    it { is_expected.to have_db_column(:views).of_type(:integer).with_options(null: false, default: 0) }

    it { is_expected.to have_db_column(:external_info).of_type(:text) }

    it do
      is_expected.to have_db_column(:tz).of_type(:string).with_options(
        null: false,
        default: Rails.application.config.time_zone,
        limit: 50
      )
    end

    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }

    it { is_expected.to have_db_column(:md5).of_type(:string).with_options(null: false, limit: 32) }
    it { is_expected.to have_db_column(:sha256).of_type(:string).with_options(null: false, limit: 64) }

    it { is_expected.to have_db_index(:rubric_id) }
    it { is_expected.to have_db_index(:yandex_token_id) }
    it { is_expected.to have_db_index([:md5, :sha256]).unique }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:rubric).inverse_of(:photos).counter_cache(true) }
    it { is_expected.to belong_to(:yandex_token).inverse_of(:photos).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(512) }

    it { is_expected.to validate_presence_of(:original_filename) }
    it { is_expected.to validate_length_of(:original_filename).is_at_most(512) }

    it { is_expected.to validate_presence_of(:width) }
    it { is_expected.to validate_numericality_of(:width).is_greater_than_or_equal_to(0).only_integer }

    it { is_expected.to validate_presence_of(:height) }
    it { is_expected.to validate_numericality_of(:height).is_greater_than_or_equal_to(0).only_integer }

    it { is_expected.to validate_presence_of(:size) }
    it { is_expected.to validate_numericality_of(:size).is_greater_than_or_equal_to(0).only_integer }

    it { is_expected.to validate_presence_of(:content_type) }
    it { is_expected.to validate_inclusion_of(:content_type).in_array(described_class::ALLOWED_CONTENT_TYPES) }

    it { is_expected.to validate_presence_of(:md5) }
    it { is_expected.to validate_length_of(:md5).is_equal_to(32) }

    it { is_expected.to validate_presence_of(:sha256) }
    it { is_expected.to validate_length_of(:sha256).is_equal_to(64) }

    it { is_expected.to validate_inclusion_of(:tz).in_array(Rails.application.config.photo_timezones) }
  end

  describe 'token presence validation' do
    context 'when photo is not uploaded' do
      subject { build :photo, :fake, local_filename: 'test', yandex_token: nil }

      it { is_expected.to be_valid }
    end

    context 'when photo is uploaded' do
      context 'and token is not assigned' do
        subject { build :photo, :fake, storage_filename: 'test', yandex_token: nil }

        it do
          is_expected.not_to be_valid
          expect(subject.errors).to include(:yandex_token)
        end
      end

      context 'and token is assigned' do
        let(:token) { create :'yandex/token' }
        subject { build :photo, :fake, storage_filename: 'test', yandex_token: token }

        it { is_expected.to be_valid }
      end
    end
  end

  describe 'upload status validation' do
    context 'when both attributes present' do
      subject { build :photo, storage_filename: 'zozo', local_filename: 'test' }

      it do
        is_expected.not_to be_valid
        expect(subject.errors).to include(:local_filename)
      end
    end

    context 'when storage_filename presents' do
      let(:token) { create :'yandex/token' }

      subject { build :photo, :fake, storage_filename: 'zozo', local_filename: nil, yandex_token: token }

      it { is_expected.to be_valid }
    end

    context 'when local_filename presents' do
      subject { build :photo, :fake, storage_filename: nil, local_filename: 'test' }

      it { is_expected.to be_valid }
    end

    context 'when both attributes empty' do
      subject { build :photo, :fake, storage_filename: nil, local_filename: nil }

      it do
        is_expected.not_to be_valid
        expect(subject.errors).to include(:local_filename)
      end
    end
  end

  describe 'strip attributes' do
    it { is_expected.to strip_attribute(:name) }
    it { is_expected.to strip_attribute(:description) }
    it { is_expected.to strip_attribute(:content_type) }
  end

  describe 'scopes' do
    let(:token) { create :'yandex/token' }
    let!(:uploaded) { create_list :photo, 2, :fake, storage_filename: 'test', yandex_token: token }
    let!(:pending) { create_list :photo, 2, :fake, local_filename: 'zozo' }

    describe '#uploaded' do
      it { expect(described_class.uploaded).to match_array(uploaded) }
    end

    describe '#pending' do
      it { expect(described_class.pending).to match_array(pending) }
    end
  end

  describe '#local_file?' do
    subject { photo.local_file? }

    context 'when local_filename is empty' do
      let(:token) { create :'yandex/token' }
      let(:photo) { create :photo, :fake, local_filename: nil, storage_filename: 'zozo', yandex_token: token }

      it { is_expected.to eq(false) }
    end

    context 'when local_filename is not empty' do
      let(:photo) { create :photo, :fake, local_filename: 'test.txt' }

      context 'and file exists' do
        before do
          FileUtils.mkdir_p(Rails.root.join('tmp', 'files'))
          FileUtils.cp 'spec/fixtures/test.txt', Rails.root.join('tmp', 'files', 'test.txt')
        end

        after do
          FileUtils.rm_f Rails.root.join('tmp', 'files', 'test.txt')
        end

        it { is_expected.to eq(true) }
      end

      context 'and file does not exist' do
        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#tmp_local_filename' do
    let(:photo) { create :photo, :fake, local_filename: 'test' }

    it do
      expect(photo.tmp_local_filename).to eq(Rails.root.join('tmp', 'files', 'test'))
    end
  end

  describe 'local file removing' do
    let(:tmp_file) { Rails.root.join('tmp', 'files', 'cats.jpg') }
    let(:photo) { create :photo, local_filename: 'cats.jpg' }

    before do
      FileUtils.mkdir_p(Rails.root.join('tmp', 'files'))
      FileUtils.cp('spec/fixtures/cats.jpg', tmp_file)
    end

    after { FileUtils.rm_f(tmp_file) }

    context 'when update' do
      before { photo.update!(name: 'test1') }

      it do
        expect(File.exist?(tmp_file)).to eq(true)
      end
    end

    context 'when destroy' do
      subject { photo.destroy }

      context 'and local_file is not empty' do
        before { subject }

        it do
          expect(File.exist?(tmp_file)).to eq(false)
        end
      end

      context 'and local_file is not exist' do
        let(:photo) { create :photo, :fake, local_filename: 'cats1.jpg' }

        it do
          expect { subject }.not_to raise_error
        end
      end
    end
  end

  describe 'remote file removing' do
    before do
      allow(Photos::RemoveFileJob).to receive(:perform_async)
    end

    let(:token) { create :'yandex/token' }
    let(:photo) { create :photo, :fake, local_filename: nil, storage_filename: 'zozo', yandex_token: token }

    it do
      expect { photo.destroy }.not_to raise_error
      expect(Photos::RemoveFileJob).to have_received(:perform_async).with(token.id, 'zozo')
    end
  end

  describe 'file attrs loading' do
    context 'when local file' do
      let(:photo) { build :photo, local_filename: 'test.txt' }
      let(:tmp_file) { Rails.root.join('tmp', 'files', 'test.txt') }

      before do
        FileUtils.mkdir_p(Rails.root.join('tmp', 'files'))
        FileUtils.cp 'spec/fixtures/test.txt', tmp_file
      end

      after do
        FileUtils.rm_f(tmp_file)
      end

      it do
        expect { photo.save! }.
          to change { photo.md5 }.from(nil).to(String).
          and change { photo.sha256 }.from(nil).to(String).
          and change { photo.size }.from(0).to(File.size(tmp_file))
      end
    end

    context 'when remote file' do
      let(:token) { create :'yandex/token' }
      let(:photo) { build :photo, :fake, storage_filename: 'test.txt', yandex_token: token }

      let(:initial_md5) { photo.md5 }
      let(:initial_sha) { photo.sha256 }

      before do
        initial_md5
        initial_sha
      end

      it do
        expect { photo.save! }.not_to(change { photo.size })
        expect(photo.md5).to eq(initial_md5)
        expect(photo.sha256).to eq(initial_sha)
      end
    end
  end

  it_behaves_like 'model with counter', :photo

  describe 'position in cart' do
    before { allow(Cart::PhotoService).to receive(:call!) }

    let(:rubric) { create :rubric }
    let(:photo) { create :photo, :fake, local_filename: 'test', rubric: rubric }

    context 'when try to change name' do
      before do
        photo.name = photo.name + 'test'
        photo.save!
      end

      it do
        expect(Cart::PhotoService).not_to have_received(:call!)
      end
    end

    context 'when rubric changed' do
      let(:new_rubric) { create :rubric }

      before do
        photo.rubric = new_rubric
        photo.save!
      end

      it do
        expect(photo.rubric).to eq(new_rubric)
        expect(::Cart::PhotoService).
          to have_received(:call!).with(photo: photo, remove: true).once
      end
    end

    context 'when photo destroyed' do
      before { photo.destroy }

      it do
        expect(photo).not_to be_persisted
        expect(::Cart::PhotoService).
          to have_received(:call!).with(photo: photo, remove: true).once
      end
    end

    context 'when try to change rubric for a new photo' do
      let(:photo) { build :photo, :fake, local_filename: 'test', rubric: rubric }
      let(:new_rubric) { create :rubric }

      before do
        photo.rubric = new_rubric
        photo.save!
      end

      it do
        expect(photo.rubric).to eq(new_rubric)
        expect(Cart::PhotoService).not_to have_received(:call!)
      end
    end
  end

  describe 'rubric changing' do
    let(:old_rubric) { create :rubric }
    let(:new_rubric) { create :rubric }

    context 'when photo is persisted' do
      let(:photo) { create :photo, :fake, local_filename: 'test', rubric: old_rubric }

      before do
        Rubric.where(id: old_rubric.id).update_all(main_photo_id: photo.id)
      end

      it do
        expect { photo.update!(rubric: new_rubric) }.to change { old_rubric.reload.main_photo }.from(photo).to(nil)
      end
    end

    context 'when photo is not persisted' do
      let(:photo) { build :photo, :fake, local_filename: 'test', rubric: old_rubric }

      subject do
        photo.rubric = new_rubric
        photo.save!
      end

      it do
        expect(::Photos::ChangeMainPhotoService).not_to receive(:call!)

        expect { subject }.to change { photo.rubric }.from(old_rubric).to(new_rubric)
      end
    end
  end
end
