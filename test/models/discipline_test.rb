require "test_helper"

class DisciplineTest < ActiveSupport::TestCase
  setup do
    @discipline = disciplines(:yoga)
  end


  test "name normalization" do
    discipline = Discipline.new(name: "  karate  kid  ")
    discipline.validate # Triggera normalizes
    assert_equal "Karate Kid", discipline.name
  end

  test "name keeps acronyms and brand casing" do
    assert_equal "MMA", Discipline.new(name: "MMA").name
    assert_equal "CrossFit", Discipline.new(name: "CrossFit").name
    assert_equal "Kick-Boxing", Discipline.new(name: "kick-boxing").name
  end

  test "name uniqueness ignores case" do
    duplicate = Discipline.new(name: "YOGA")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "è già presente"
  end

  test "name uniqueness enforces scope" do
    # Provo a creare un altro "Yoga" attivo -> Errore
    duplicate = Discipline.new(name: "Yoga")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "è già presente"

    # Provo a creare "Pilates" (che esiste ma è soft-deleted) -> OK
    new_pilates = Discipline.new(name: "Pilates")
    assert new_pilates.valid?
  end

  test "soft delete works" do
    @discipline.discard!
    assert @discipline.discarded?

    # Ora che è cancellata, posso riusare il nome
    new_yoga = Discipline.new(name: "Yoga")
    assert new_yoga.valid?
  end

  test "hard deleting a discipline unlinks products and keeps the products" do
    discipline = Discipline.create!(name: "Boxe")
    link!(products(:yoga_monthly), discipline)

    discipline.destroy

    assert_empty ProductDiscipline.where(discipline_id: discipline.id)
    assert Product.exists?(products(:yoga_monthly).id)
  end

  test "a discipline with a register cannot be hard deleted: it is archived instead" do
    discipline = Discipline.create!(name: "Boxe")
    attendance = Attendance.create!(member: members(:alice), discipline:, marked_by: users(:kiosk))

    assert_not discipline.destroy
    assert Attendance.exists?(attendance.id)

    discipline.discard!
    assert Attendance.exists?(attendance.id), "archiviare non tocca il registro"
  end
end
