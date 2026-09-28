# kiosk e segreteria scrivono le private allo stesso modo: chi salva firma la nota, la regola del mese la decide il modello
module PrivateLessonEditing
  extend ActiveSupport::Concern

  included do
    before_action :set_private_lesson, only: %i[ edit update destroy ]
    before_action :require_editable, only: %i[ edit update destroy ]
  end

  private
    def set_private_lesson
      @private_lesson = PrivateLesson.find(params[:id])
    end

    def require_editable
      return if @private_lesson.editable_by?(current_user)

      flash[:error] = "Il mese di questa privata è chiuso: può correggerla solo un amministratore."
      redirect_to private_lessons_home, status: :see_other
    end

    # proposta: il quarto d'ora appena iniziato, un'ora di lezione
    def new_private_lesson
      now = Time.current
      PrivateLesson.new(held_at: now.change(min: now.min / 15 * 15), duration_minutes: 60)
    end

    def private_lesson_params
      params.expect(private_lesson: [ :teacher, :held_at, :duration_minutes, :note, athletes: [] ]).merge(recorded_by: current_user)
    end
end
