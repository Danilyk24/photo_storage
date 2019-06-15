class Rubric < ApplicationRecord
  belongs_to :rubric, optional: true, inverse_of: :rubrics
  has_many :rubrics, dependent: :destroy, inverse_of: :rubric
  has_many :photos, dependent: :destroy, inverse_of: :rubric

  validates :name, presence: true, length: {maximum: 100}

  strip_attributes only: %i[name description]
end
