# frozen_string_literal: true

module Api
  module V1
    module Admin
      class UploadsController < BaseController
        OBJECT_TYPES = Photo::ALLOWED_CONTENT_TYPES.map { |type| [type, Photo] }.to_h.merge!(
          Track::MIME_TYPE => Track
        ).freeze

        def create
          if (klass = OBJECT_TYPES[uploaded_io.content_type]).nil?
            head(:unprocessable_entity)
            return
          end

          @model = create_model(klass)
          @success = enqueue_process.success?

          render status: :unprocessable_entity unless @success
        end

        private

        def create_model(klass)
          klass.new(
            name: File.basename(uploaded_io.original_filename, '.*'),
            rubric: Rubric.find(params.require(:rubric_id)),
            external_info: params[:external_info]
          )
        end

        def enqueue_process
          "::#{@model.class.to_s.pluralize}::EnqueueProcessService".constantize.call(
            model: @model,
            uploaded_io: uploaded_io
          )
        end

        def uploaded_io
          @uploaded_io ||= params.require(:content)
        end
      end
    end
  end
end
