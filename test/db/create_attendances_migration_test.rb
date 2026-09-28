require "test_helper"
require Rails.root.join("db/migrate/20260928090000_create_attendances")

# lo storico degli ingressi diventa una presenza per socio, disciplina e mese (ora di Roma)
class CreateAttendancesMigrationTest < ActiveSupport::TestCase
  test "many entries in a month become one attendance, marked by the first" do
    rows = [
      [ 1, 10, 7, "2026-09-03 08:00:00" ],
      [ 1, 10, 8, "2026-09-20 17:00:00" ],
      [ 1, 10, 9, "2026-10-01 17:00:00" ]
    ]

    assert_equal [ [ Date.new(2026, 9, 1), 7 ], [ Date.new(2026, 10, 1), 9 ] ],
                 convert(rows).map { it.values_at(:month, :marked_by_id) }
    assert_equal Time.utc(2026, 9, 3, 8), convert(rows).first[:created_at]
  end

  test "members and disciplines are kept apart" do
    rows = [ [ 1, 10, 7, "2026-09-03 08:00:00" ], [ 2, 10, 7, "2026-09-03 08:00:00" ], [ 1, 11, 7, "2026-09-03 08:00:00" ] ]

    assert_equal [ [ 1, 10 ], [ 2, 10 ], [ 1, 11 ] ], convert(rows).map { it.values_at(:member_id, :discipline_id) }
  end

  test "the month follows Rome time, in summer and in winter" do
    rows = [
      [ 1, 10, 7, "2026-08-31 22:30:00" ], # 00:30 del 1 settembre, ora legale
      [ 2, 10, 7, "2026-12-31 23:30:00" ], # 00:30 del 1 gennaio, ora solare
      [ 3, 10, 7, "2026-09-30 21:59:59" ]  # 23:59 del 30 settembre
    ]

    assert_equal [ Date.new(2026, 9, 1), Date.new(2027, 1, 1), Date.new(2026, 9, 1) ], convert(rows).map { it[:month] }
  end

  test "timestamps read from the database work as well as strings" do
    assert_equal Date.new(2026, 9, 1), convert([ [ 1, 10, 7, Time.utc(2026, 8, 31, 22, 30) ] ]).first[:month]
  end

  test "the converted rows are valid attendances" do
    rows = [ [ members(:alice).id, disciplines(:yoga).id, users(:staff).id, Date.current.beginning_of_month.in_time_zone.change(hour: 12).utc.to_s ] ]

    Attendance.insert_all(convert(rows))
    attendance = Attendance.last
    assert attendance.valid?
    assert_equal [ members(:alice), Date.current.beginning_of_month ], [ attendance.member, attendance.month ]
  end

  private
    def convert(rows) = CreateAttendances.attendances_from(rows)
end
