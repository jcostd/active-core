# le private del mese viste dalla segreteria: tracciabilità, e correzioni dei mesi chiusi per l'admin
class PrivateLessonsController < ApplicationController
  include Filterable, SafeDateParsing, PrivateLessonEditing

  layout "modal", only: %i[ new create edit update ]

  def index
    @month    = parse_month_param(params[:month]).beginning_of_month
    @editable = PrivateLesson.editable_by?(current_user, @month)

    month_lessons    = PrivateLesson.in_month(@month)
    @teachers        = month_lessons.distinct.order(:teacher).pluck(:teacher)
    @private_lessons = month_lessons.apply_filters(filter_params).to_a
  end

  def new
    @private_lesson = new_private_lesson
  end

  def create
    @private_lesson = PrivateLesson.new(private_lesson_params)

    if @private_lesson.save
      turbo_refresh_or_redirect_to month_path(@private_lesson), notice: "Privata di #{@private_lesson.teacher} registrata."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @private_lesson.update(private_lesson_params)
      turbo_refresh_or_redirect_to month_path(@private_lesson), notice: "Privata di #{@private_lesson.teacher} aggiornata."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @private_lesson.destroy!
    turbo_refresh_or_redirect_to month_path(@private_lesson), notice: "Privata di #{@private_lesson.teacher} cancellata."
  end

  private
    def private_lessons_home = private_lessons_path

    def month_path(private_lesson) = private_lessons_path(month: private_lesson.held_at.strftime("%Y-%m"))

    def filter_params
      params.permit(:query, :sort, :teacher)
    end
end
