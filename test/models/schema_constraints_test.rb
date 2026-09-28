require "test_helper"

# ogni colonna NOT NULL è difesa dal modello: chi sbaglia un form vede un messaggio, non un errore 500
class SchemaConstraintsTest < ActiveSupport::TestCase
  AUTOMATIC = %w[id created_at updated_at].freeze

  setup do
    grant_membership_to(members(:alice))
    sale = sell!(member: members(:alice), product: products(:yoga_monthly))

    @records = [
      members(:alice), products(:yoga_monthly), disciplines(:yoga), users(:staff), gym_profiles(:asd),
      sale, sale.subscription, ReceiptCounter.first,
      Attendance.create!(member: members(:alice), discipline: disciplines(:yoga), marked_by: users(:kiosk)),
      PrivateLesson.create!(teacher: "Marco", athletes: [ "Luca" ], held_at: Time.current, duration_minutes: 60, recorded_by: users(:kiosk))
    ]
  end

  test "blanking a required column is refused by validations, never by the database" do
    unguarded = @records.flat_map do |record|
      required_columns(record.class).select do |column|
        record.reload
        record[column] = nil
        record.save && record.reload[column].nil?
      rescue ActiveRecord::NotNullViolation
        true
      end.map { "#{record.class.name}##{it}" }
    end

    assert_empty unguarded, "il database rifiuta nil ma il modello lo accetta"
  end

  private
    def required_columns(model)
      model.columns.reject(&:null).map(&:name) - AUTOMATIC
    end
end
