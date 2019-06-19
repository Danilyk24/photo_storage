class Photo < ApplicationRecord
  JPEG_IMAGE = 'image/jpeg'.freeze
  PNG_IMAGE = 'image/png'.freeze

  ALLOWED_CONTENT_TYPES = [
    JPEG_IMAGE,
    PNG_IMAGE
  ].freeze

  belongs_to :rubric, inverse_of: :photos
  belongs_to :yandex_token, class_name: 'Yandex::Token',
                            inverse_of: :photos,
                            foreign_key: :yandex_token_id,
                            optional: true

  validates :name, :original_filename, presence: true, length: {maximum: 512}
  validates :width, :height, :size, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :content_type, presence: true, inclusion: ALLOWED_CONTENT_TYPES

  validates :md5, :sha256, presence: true
  validates :md5, length: {is: 32}
  validates :sha256, length: {is: 64}
  validates :sha256, uniqueness: {scope: :md5}

  validate :upload_status

  strip_attributes only: %i[name description content_type]

  before_validation :read_file_attributes
  before_validation { self.original_timestamp ||= Time.current }

  scope :uploaded, -> { where.not(storage_filename: nil) }
  scope :pending, -> { where.not(local_filename: nil) }

  after_commit :remove_file, unless: :persisted?

  def local_file?
    local_filename.present? && File.exist?(tmp_local_filename)
  end

  def tmp_local_filename
    Rails.root.join('tmp', 'files', local_filename)
  end

  private

  def read_file_attributes
    return unless local_file?

    self.md5 ||= Digest::MD5.file(tmp_local_filename).to_s
    self.sha256 ||= Digest::SHA256.file(tmp_local_filename).to_s

    self.size = File.size(tmp_local_filename) if size.zero?
  end

  def remove_file
    FileUtils.rm_f(tmp_local_filename) if local_file?
  end

  def upload_status
    errors.add(:local_filename, :wrong_value) if [storage_filename, local_filename].compact.size != 1
  end
end
