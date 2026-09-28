require "test_helper"

# la segreteria legge le private del mese; i mesi chiusi li corregge solo l'admin
class PrivateLessonsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:staff)) }

  test "the month with a summary per teacher" do
    write(teacher: "Marco", athletes: [ "Luca", "Sara" ], duration_minutes: 60)
    write(teacher: "Marco", athletes: [ "Luca" ], duration_minutes: 30)
    write(teacher: "Giulia", athletes: [ "Anna" ], duration_minutes: 45)
    write(teacher: "Passato", held_at: 1.month.ago, by: users(:admin))

    get private_lessons_path
    assert_response :success
    assert_select "#private_lessons li.list-row", count: 3
    assert_select "#private_lessons_summary tbody tr", count: 2
    assert_select "#private_lessons_summary tr", text: /Marco\s+2\s+1 h 30 min\s+2/
    assert_select "#private_lessons_summary tr", text: /Giulia\s+1\s+45 min\s+1/
    assert_no_match "Passato", response.body
  end

  test "another month, and a teacher or a name to look for" do
    write(teacher: "Marco", athletes: [ "Luca" ])
    old = write(teacher: "Giulia", athletes: [ "Anna Verdi" ], note: "Recupero", held_at: 1.month.ago, by: users(:admin))
    month = old.held_at.strftime("%Y-%m")

    get private_lessons_path(month:)
    assert_select "#private_lessons li.list-row", count: 1
    assert_select "#private_lessons", text: /Giulia/

    get private_lessons_path(teacher: "Giulia")
    assert_select "#private_lessons", count: 0

    [ { teacher: "Giulia" }, { query: "verdi" }, { query: "recupero" } ].each do |filter|
      get private_lessons_path(month:, **filter)
      assert_select "#private_lessons li.list-row", 1, filter.inspect
    end
  end

  test "staff corrects this month, not the closed ones" do
    current = write
    closed = write(held_at: 1.month.ago, by: users(:admin))

    get private_lessons_path
    assert_select "a[href=?]", edit_private_lesson_path(current)

    get private_lessons_path(month: closed.held_at.strftime("%Y-%m"))
    assert_select "a[href=?]", edit_private_lesson_path(closed), count: 0

    delete private_lesson_path(closed)
    assert_redirected_to private_lessons_path
    assert PrivateLesson.exists?(closed.id)
  end

  test "the admin writes and corrects a closed month" do
    sign_in_as(users(:admin))
    held_at = 1.month.ago.change(hour: 18, min: 0)

    post private_lessons_path, params: { private_lesson: { teacher: "Esterno", athletes: [ "Anna" ], duration_minutes: 60,
                                                           held_at: held_at.strftime("%Y-%m-%dT%H:%M") } }
    lesson = PrivateLesson.last
    assert_redirected_to private_lessons_path(month: held_at.strftime("%Y-%m"))
    assert_equal [ held_at, users(:admin) ], [ lesson.held_at, lesson.recorded_by ]

    patch private_lesson_path(lesson), params: { private_lesson: { note: "Pagata al maestro" } }
    assert_equal "Pagata al maestro", lesson.reload.note

    delete private_lesson_path(lesson)
    assert_not PrivateLesson.exists?(lesson.id)
  end

  test "the form opens in the modal and as a page" do
    get new_private_lesson_path, headers: { "Turbo-Frame" => "modal" }
    assert_select "turbo-frame#modal dialog form[action=?]", private_lessons_path

    get new_private_lesson_path
    assert_select "h1", text: "Nuova privata"
  end

  test "errors stay in the modal" do
    post private_lessons_path, params: { private_lesson: { teacher: "Marco", athletes: [ "" ], duration_minutes: 60 } },
                               headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal .alert", text: /Atleti deve contenere almeno un nome/
  end

  private
    def write(by: users(:staff), **attributes)
      PrivateLesson.create!(teacher: "Marco", athletes: [ "Luca" ], held_at: Time.current, duration_minutes: 60, recorded_by: by, **attributes)
    end
end
