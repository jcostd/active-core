# lezioni private del mese: le scrive il maestro che le tiene
class Kiosk::PrivateLessonsController < Kiosk::BaseController
  include PrivateLessonEditing

  def index
    @month = PrivateLesson.current_month
    @private_lessons = PrivateLesson.in_month(@month).order(held_at: :desc)
  end

  def new
    @private_lesson = new_private_lesson
  end

  def create
    @private_lesson = PrivateLesson.new(private_lesson_params)

    if @private_lesson.save
      flash[:success] = "Privata di #{@private_lesson.teacher} registrata."
      redirect_to kiosk_private_lessons_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @private_lesson.update(private_lesson_params)
      flash[:success] = "Privata di #{@private_lesson.teacher} aggiornata."
      redirect_to kiosk_private_lessons_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @private_lesson.destroy!
    flash[:success] = "Privata di #{@private_lesson.teacher} cancellata."
    redirect_to kiosk_private_lessons_path, status: :see_other
  end

  private
    def private_lessons_home = kiosk_private_lessons_path
end
