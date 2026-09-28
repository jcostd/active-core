require "test_helper"

# il maestro scrive la privata al kiosk: nomi liberi, nessun legame con soci o utenti
class KioskPrivateLessonsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:kiosk)) }

  test "the kiosk home leads to the private lessons" do
    get kiosk_root_path
    assert_select "a[href=?]", kiosk_private_lessons_path, text: /Lezioni private/
  end

  test "writing a one to many private lesson" do
    get new_kiosk_private_lesson_path
    assert_response :success
    assert_select "input[name='private_lesson[duration_minutes]'][value='60'][checked]"

    assert_difference -> { PrivateLesson.count } do
      post kiosk_private_lessons_path, params: { private_lesson: lesson_params(athletes: [ "luca bianchi", "", "Ospite Esterno" ]) }
    end
    assert_redirected_to kiosk_private_lessons_path
    assert_equal "Privata di Marco Rossi registrata.", flash[:success]

    lesson = PrivateLesson.last
    assert_equal [ "Marco Rossi", [ "Luca Bianchi", "Ospite Esterno" ], 45, users(:kiosk) ],
                 [ lesson.teacher, lesson.athletes, lesson.duration_minutes, lesson.recorded_by ]

    follow_redirect!
    assert_select "#private_lessons #{dom(lesson)}", text: /Marco Rossi.*Luca Bianchi.*Ospite Esterno/m
  end

  test "without athletes the form comes back with the error" do
    assert_no_difference -> { PrivateLesson.count } do
      post kiosk_private_lessons_path, params: { private_lesson: lesson_params(athletes: [ "" ]) }
    end
    assert_response :unprocessable_entity
    assert_select ".alert", text: /Atleti deve contenere almeno un nome/
    assert_select "input[name='private_lesson[teacher]'][value='marco rossi']", true, "quello che ha scritto resta"
  end

  test "names already written are suggested" do
    write(teacher: "Giulia Esterna", athletes: [ "Anna Verdi" ])

    get new_kiosk_private_lesson_path
    assert_select "datalist#teacher_names option[value='Giulia Esterna']"
    assert_select "datalist#athlete_names option[value='Anna Verdi']"
  end

  test "the list shows this month only" do
    current = write(note: "Recupero")
    old = write(teacher: "Vecchia", held_at: 1.month.ago, by: users(:admin))

    get kiosk_private_lessons_path
    assert_select "#private_lessons #{dom(current)}", text: /Recupero/
    assert_select dom(old), count: 0
  end

  test "an empty month says what to do" do
    get kiosk_private_lessons_path
    assert_select "#private_lessons", text: /Nessuna privata questo mese/
  end

  test "correcting a lesson of this month" do
    lesson = write

    get edit_kiosk_private_lesson_path(lesson)
    assert_select "input[name='private_lesson[athletes][]'][value='Luca']"

    patch kiosk_private_lesson_path(lesson), params: { private_lesson: { athletes: [ "Luca", "Sara" ], duration_minutes: 90 } }
    assert_redirected_to kiosk_private_lessons_path
    assert_equal [ [ "Luca", "Sara" ], 90 ], [ lesson.reload.athletes, lesson.duration_minutes ]
  end

  test "deleting a lesson of this month" do
    lesson = write

    assert_difference -> { PrivateLesson.count }, -1 do
      delete kiosk_private_lesson_path(lesson)
    end
    assert_redirected_to kiosk_private_lessons_path
    assert_equal "Privata di Marco cancellata.", flash[:success]
  end

  test "closed months are out of reach" do
    lesson = write(held_at: 1.month.ago, by: users(:admin))

    get edit_kiosk_private_lesson_path(lesson)
    assert_redirected_to kiosk_private_lessons_path

    patch kiosk_private_lesson_path(lesson), params: { private_lesson: { teacher: "Altro" } }
    delete kiosk_private_lesson_path(lesson)
    assert_equal "Marco", lesson.reload.teacher
    assert_equal "Il mese di questa privata è chiuso: può correggerla solo un amministratore.", flash[:error]

    post kiosk_private_lessons_path, params: { private_lesson: lesson_params(held_at: 1.month.ago) }
    assert_response :unprocessable_entity
  end

  test "the kiosk user stays out of the desk page" do
    get private_lessons_path
    assert_redirected_to kiosk_root_path
  end

  private
    def lesson_params(**overrides)
      { teacher: "marco rossi", athletes: [ "Luca" ], held_at: Time.current.strftime("%Y-%m-%dT%H:%M"), duration_minutes: 45 }.merge(overrides)
    end

    def write(by: users(:kiosk), **attributes)
      PrivateLesson.create!(teacher: "Marco", athletes: [ "Luca" ], held_at: Time.current, duration_minutes: 60, recorded_by: by, **attributes)
    end

    def dom(record) = "##{ActionView::RecordIdentifier.dom_id(record)}"
end
