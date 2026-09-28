require "test_helper"
require "turbo/broadcastable/test_helper"

class DomainEdgesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, Turbo::Broadcastable::TestHelper

  # --- ANNO SPORTIVO ---

  test "sport year flips on september first" do
    assert_equal "2025/2026", SportYear.new(Date.new(2026, 8, 31)).to_s
    assert_equal "2026/2027", SportYear.new(Date.new(2026, 9, 1)).to_s
  end

  test "membership sold in august covers the next sport year too" do
    d = Duration.for(products(:annual_membership), Date.new(2026, 8, 20))
    assert_equal Date.new(2027, 8, 31), d.end_date
  end

  test "membership sold on august first or september first" do
    assert_equal Date.new(2027, 8, 31), Duration.for(products(:annual_membership), Date.new(2026, 8, 1)).end_date
    assert_equal Date.new(2027, 8, 31), Duration.for(products(:annual_membership), Date.new(2026, 9, 1)).end_date
  end

  test "membership sold in july still ends that august" do
    assert_equal Date.new(2026, 8, 31), Duration.for(products(:annual_membership), Date.new(2026, 7, 31)).end_date
  end

  test "courses sold in august are not extended" do
    assert_equal Date.new(2026, 8, 31), Duration.for(products(:yoga_monthly), Date.new(2026, 8, 20)).end_date
  end

  test "monthly course in february handles leap years" do
    course = products(:yoga_monthly)
    assert_equal Date.new(2028, 2, 29), Duration.for(course, Date.new(2028, 2, 10)).end_date
    assert_equal Date.new(2027, 2, 28), Duration.for(course, Date.new(2027, 2, 10)).end_date
  end

  test "rolling annual course ends the day before one year later" do
    course = products(:yoga_monthly)
    course.duration_days = 365
    assert_equal Date.new(2027, 3, 14), Duration.for(course, Date.new(2026, 3, 15)).end_date
  end

  # --- RICEVUTE ---

  test "receipt year follows the accounting date, not today" do
    member = members(:alice)
    grant_membership_to(member)
    sale = sell!(member:, product: products(:annual_membership), user: users(:admin), sold_on: Date.new(Date.current.year - 1, 12, 31),
                 start_date: Date.new(Date.current.year + 5, 1, 1))

    assert_equal Date.current.year - 1, sale.receipt_year
  end

  test "receipt numbers restart per year and category" do
    ReceiptCounter.delete_all
    assert_equal 1, ReceiptCounter.next_number(2030, "associative")
    assert_equal 2, ReceiptCounter.next_number(2030, "associative")
    assert_equal 1, ReceiptCounter.next_number(2031, "associative")
    assert_equal 1, ReceiptCounter.next_number(2030, "institutional")
  end

  test "fiscal data cannot change after issue" do
    member = members(:alice)
    grant_membership_to(member)
    sale = sell!(member:, product: products(:yoga_monthly))

    assert_not sale.update(receipt_number: sale.receipt_number + 1)
    assert_match "dato fiscale", sale.errors.full_messages.to_sentence
  end

  test "product snapshot is not rewritten on later saves" do
    member = members(:alice)
    grant_membership_to(member)
    sale = sell!(member:, product: products(:yoga_monthly))
    products(:yoga_monthly).update!(name: "Yoga Nuovo")

    sale.update!(notes: "nota")
    assert_equal "Yoga Mensile", sale.reload.product_name_snapshot
  end

  # --- AGGIORNAMENTI IN TEMPO REALE ---

  test "member changes broadcast a refresh to the members stream" do
    assert_turbo_stream_broadcasts("members") do
      perform_enqueued_jobs { members(:alice).update!(phone: "3330001111") }
    end
  end

  test "marking and unmarking an attendance refresh the attendances stream" do
    attendance = nil
    assert_turbo_stream_broadcasts("attendances") do
      perform_enqueued_jobs { attendance = Attendance.create!(member: members(:alice), discipline: disciplines(:yoga), marked_by: users(:kiosk)) }
    end
    assert_turbo_stream_broadcasts("attendances") { perform_enqueued_jobs { attendance.destroy! } }
  end
end
