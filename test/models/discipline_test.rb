require "test_helper"

class DisciplineTest < ActiveSupport::TestCase
  setup do
    @discipline = disciplines(:yoga)
  end

  test "valid discipline setup" do
    assert @discipline.valid?
    assert @discipline.requires_medical_certificate?
  end

  test "name normalization" do
    discipline = Discipline.new(name: "  karate  kid  ")
    discipline.validate # Triggera normalizes
    assert_equal "Karate Kid", discipline.name
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

  test "associations work" do
    discipline = Discipline.create!(name: "Boxe")
    product = products(:annual_membership)

    discipline.products << product

    assert_includes discipline.products, product
    assert_equal 1, discipline.product_disciplines.count

    discipline.destroy # Hard delete per testare la pulizia DB
    assert_equal 0, ProductDiscipline.where(discipline_id: discipline.id).count
  end
end
