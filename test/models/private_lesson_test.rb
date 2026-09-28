require "test_helper"

class PrivateLessonTest < ActiveSupport::TestCase
  test "names are written by hand and tidied up" do
    lesson = write(teacher: "  marco ROSSI ", athletes: [ " luca bianchi", "", "Luca Bianchi", "sara d'amico" ], note: "  ")

    assert_equal "Marco Rossi", lesson.teacher
    assert_equal [ "Luca Bianchi", "Sara D'Amico" ], lesson.athletes
    assert_nil lesson.note
  end

  test "at least one athlete, a teacher and a known duration" do
    lesson = build(teacher: " ", athletes: [ "", " " ], duration_minutes: 50)

    assert_not lesson.valid?
    assert_equal [ "Maestro non può essere lasciato in bianco", "Atleti deve contenere almeno un nome",
                   "Durata non è compreso tra le opzioni disponibili" ], lesson.errors.full_messages
  end

  test "one to one and one to many" do
    assert_equal 1, write(athletes: [ "Luca" ]).athletes.size
    assert_equal 3, write(athletes: [ "Luca", "Sara", "Anna" ]).athletes.size
  end

  test "a month that has not started cannot be written, not even by the admin" do
    lesson = build(held_at: Time.current.next_month.beginning_of_month, by: users(:admin))

    assert_not lesson.valid?
    assert_includes lesson.errors.full_messages, "Inizio è in un mese non ancora iniziato"
  end

  test "closed months are written by the admin only" do
    last_month = 1.month.ago

    users(:kiosk, :staff).each do |user|
      lesson = build(held_at: last_month, by: user)
      assert_not lesson.valid?, user.username
      assert_includes lesson.errors.full_messages, "Inizio è in un mese chiuso: solo un amministratore può correggerlo"
    end
    assert build(held_at: last_month, by: users(:admin)).valid?
  end

  test "a lesson cannot be moved out of a closed month by who cannot correct it" do
    closed = write(held_at: 1.month.ago, by: users(:admin))

    assert_not closed.update(held_at: Time.current, recorded_by: users(:staff))
    assert_includes closed.errors.full_messages, "Inizio è in un mese chiuso: solo un amministratore può correggerlo"
  end

  test "editable_by? follows the attendance register" do
    current = write
    closed  = write(held_at: 1.month.ago, by: users(:admin))

    assert users(:kiosk, :staff, :admin).all? { current.editable_by?(it) }
    assert_equal [ false, false, true ], users(:kiosk, :staff, :admin).map { closed.editable_by?(it) }
  end

  test "the month follows Rome time" do
    month = Date.current.beginning_of_month
    first = write(held_at: month.in_time_zone.change(hour: 0, min: 30)) # 30 minuti dopo mezzanotte a Roma, il giorno prima in UTC

    assert_includes PrivateLesson.in_month(month), first
    assert_not_includes PrivateLesson.in_month(month.prev_month), first
  end

  test "suggestions: most used names first, only from the last year" do
    write(teacher: "Bruno", athletes: [ "Sara", "Luca" ])
    write(teacher: "Anna", athletes: [ "Luca" ])
    write(teacher: "Anna", athletes: [ "Luca", "Zeno" ])
    write(teacher: "Vecchio Maestro", athletes: [ "Vecchio Atleta" ], held_at: 13.months.ago, by: users(:admin))

    assert_equal [ "Luca", "Sara", "Zeno" ], PrivateLesson.athlete_names
    assert_equal [ "Anna", "Bruno" ], PrivateLesson.teacher_names.first(2)
    assert_not_includes PrivateLesson.teacher_names, "Vecchio Maestro"
  end

  test "staff names are suggested as teachers, the kiosk user is not" do
    names = PrivateLesson.teacher_names

    assert_includes names, users(:staff).full_name
    assert_not_includes names, users(:kiosk).full_name
  end

  test "the start is kept to the minute" do
    assert_equal 0, write(held_at: Time.zone.parse("#{Date.current} 18:02:47")).reload.held_at.sec
  end

  test "ends after its duration" do
    lesson = build(held_at: Time.zone.parse("2026-09-28 18:00"), duration_minutes: 90)
    assert_equal Time.zone.parse("2026-09-28 19:30"), lesson.ends_at
  end

  private
    def build(by: users(:kiosk), **attributes)
      PrivateLesson.new(teacher: "Marco", athletes: [ "Luca" ], held_at: Time.current, duration_minutes: 60, recorded_by: by, **attributes)
    end

    def write(...) = build(...).tap(&:save!)
end
