module Photos
  class MainPhotoService
    include ::Interactor

    delegate :photo, to: :context
    delegate :rubric, to: :photo

    def call
      return if rubric.main_photo_id.present?

      apply_main_photo_for(rubric)
    end

    private

    def apply_main_photo_for(current_rubric)
      with_lock(current_rubric.id) do
        current_rubric.reload
        current_rubric.update!(main_photo: photo) unless current_rubric.main_photo_id.present?
      end

      return unless current_rubric.rubric_id.present? && current_rubric.rubric.main_photo_id.nil?

      apply_main_photo_for(current_rubric.rubric)
    end

    def with_lock(id, &block)
      RedisMutex.with_lock("rubric_update:#{id}", block: 30.seconds, expire: 3.minutes, &block)
    end
  end
end
