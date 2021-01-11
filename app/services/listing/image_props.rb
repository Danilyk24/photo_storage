# frozen_string_literal: true

module Listing
  class ImageProps
    attr_reader :model

    def initialize(model)
      @model = model
    end

    def image_size(size = :thumb, apply_rotation: false)
      actual_size = (@image_size ||= {})[size] ||= calc_image_size(size)

      if turned? && apply_rotation
        actual_size.reverse
      else
        actual_size
      end
    end

    def css_transform
      transforms = []

      transforms += Array.wrap(effects)
      transforms << "rotate(#{rotated * 90}deg)" if rotated

      transforms.join(' ').presence
    end

    def turned?
      rotated.to_i.odd?
    end

    private

    delegate :max_thumb_width, :photo_sizes, to: 'Rails.application.config'
    delegate :width, :height, :rotated, :effects, to: :model

    def actual_width_for(width)
      width > max_thumb_width ? max_thumb_width : width
    end

    def calc_image_size(size)
      thumb_width = thumb_width(size)

      [
        actual_width_for(thumb_width),
        height * thumb_width / width
      ].tap do |result|
        if turned?
          result.reverse!

          result[1] = result.first**2 / result.last
        end
      end
    end

    def thumb_width(size)
      result = photo_sizes.fetch(size)
      result = result.call(model) if result.respond_to?(:call)

      # we can scale up only thumbs
      if size != :thumb
        result = width if result > width
        result = actual_width_for(result)
      end

      result
    end
  end
end
