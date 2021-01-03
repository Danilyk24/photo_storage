# frozen_string_literal: true

module Rubrics
  # finds photos for the rubric
  #
  # only_with_geo_tags
  # limit
  # offset
  #
  # returns relation
  class PhotosFinder
    def initialize(rubric_id, opts = {})
      @rubric_id = rubric_id
      @only_with_geo_tags = opts.fetch(:only_with_geo_tags, false)

      @limit = opts.fetch(:limit, 0)
      @offset = opts.fetch(:offset, 0)

      @columns = opts.fetch(:columns, Photo.arel_table[Arel.star])
    end

    def call
      scope = photos_scope

      scope.limit!(@limit) if @limit.positive?
      scope.offset!(@offset) if @offset.positive?

      scope.preload(:yandex_token).order(:rn)
    end

    def self.call(rubric_id, opts = {})
      new(rubric_id, opts).call
    end

    private

    def base_scope
      Photo.where(rubric_id: @rubric_id).uploaded.tap do |scope|
        scope.where!(Photo.arel_table[:lat_long].not_eq(nil)) if @only_with_geo_tags
      end
    end

    def photos_scope
      table_name = Photo.quoted_table_name

      base_scope.select \
        @columns,
        <<~SQL.squish
          ROW_NUMBER() OVER (
            ORDER BY #{table_name}.original_timestamp AT TIME ZONE #{table_name}.tz NULLS FIRST,
                     #{table_name}.id
          ) rn
        SQL
    end
  end
end
