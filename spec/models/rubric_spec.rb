require 'rails_helper'

RSpec.describe Rubric do
  describe 'structure' do
    it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false, limit: 100) }
    it { is_expected.to have_db_column(:description).of_type(:text) }

    it { is_expected.to have_db_column(:rubric_id).of_type(:integer).with_options(null: true, foreign_key: true) }
    it { is_expected.to have_db_column(:main_photo_id).of_type(:integer).with_options(null: true, foreign_key: true) }

    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }

    it { is_expected.to have_db_column(:rubrics_count).of_type(:integer).with_options(null: false, default: 0) }
    it { is_expected.to have_db_column(:photos_count).of_type(:integer).with_options(null: false, default: 0) }

    it { is_expected.to have_db_index(:rubric_id) }
    it { is_expected.to have_db_index(:main_photo_id) }

    it { is_expected.to have_db_column(:ord).of_type(:integer) }
    it { is_expected.to have_db_column(:external_info).of_type(:text) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:rubric).inverse_of(:rubrics).optional.counter_cache(true) }
    it { is_expected.to belong_to(:main_photo).optional.class_name('Photo') }
    it { is_expected.to have_many(:rubrics).inverse_of(:rubric).dependent(:destroy) }
    it { is_expected.to have_many(:photos).inverse_of(:rubric).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe 'strip attributes' do
    it { is_expected.to strip_attribute(:name) }
    it { is_expected.to strip_attribute(:description) }
  end

  describe 'scopes' do
    let!(:rubric1) { create :rubric, photos_count: 0 }
    let!(:rubric2) { create :rubric, photos_count: 0 }
    let!(:rubric3) { create :rubric, photos_count: 5, rubric: rubric1, ord: 1 }
    let!(:rubric4) { create :rubric, rubric: rubric2, ord: 2 }

    describe '#with_photos' do
      let!(:rubric5) { create :rubric, photos_count: 1, rubric: rubric3, ord: 2 }

      it { expect(described_class.with_photos).to match_array([rubric1, rubric3, rubric5]) }
      it { expect(rubric1.rubrics.with_photos).to match_array([rubric3]) }
    end

    describe '#default_order' do
      it do
        expect(described_class.default_order).to eq([rubric2, rubric1, rubric3, rubric4])
      end
    end

    describe '#by_first_photo' do
      context 'when all rubrics without photo' do
        # should sort by id
        it do
          expect(described_class.by_first_photo).to eq([rubric4, rubric3, rubric2, rubric1])
        end
      end

      context 'when some rubrics have photo' do
        let!(:photo1) { create :photo, :fake, rubric: rubric1, local_filename: 'test', original_timestamp: nil }

        let!(:photo2) do
          create :photo, :fake, rubric: rubric2, local_filename: 'test', original_timestamp: Date.yesterday
        end

        let!(:photo3) do
          create :photo, :fake, rubric: rubric2, local_filename: 'test', original_timestamp: Date.today
        end

        let!(:photo4) do
          create :photo, :fake, rubric: rubric4, local_filename: 'test', original_timestamp: 2.days.ago
        end

        let!(:photo5) { create :photo, :fake, rubric: rubric4, local_filename: 'test', original_timestamp: nil }

        it do
          expect(described_class.by_first_photo).to eq([rubric2, rubric4, rubric3, rubric1])
        end
      end
    end
  end
end
