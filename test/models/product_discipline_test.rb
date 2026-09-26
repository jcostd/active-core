require "test_helper"

class ProductDisciplineTest < ActiveSupport::TestCase
  setup do
    @product = products(:yoga_monthly)
    @discipline = disciplines(:yoga)
  end

  test "valid link creation" do
    link = ProductDiscipline.new(product: @product, discipline: @discipline)
    assert link.valid?
    assert link.save

    assert_includes @product.reload.disciplines, @discipline
  end

  test "prevent duplicate links via validation" do
    # 1. Creiamo il primo link (legalmente)
    ProductDiscipline.create!(product: @product, discipline: @discipline)

    # 2. Proviamo a creare il duplicato
    duplicate_link = ProductDiscipline.new(product: @product, discipline: @discipline)

    assert_not duplicate_link.valid?
    assert_includes duplicate_link.errors[:product_id], "include già questa disciplina"
  end

  test "prevent duplicate links via DB constraint" do
    ProductDiscipline.create!(product: @product, discipline: @discipline)

    duplicate_link = ProductDiscipline.new(product: @product, discipline: @discipline)

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate_link.save!(validate: false)
    end
  end

  test "touch updates product timestamp" do
    # Reset del timestamp per essere sicuri
    old_time = 1.day.ago
    @product.update_columns(updated_at: old_time)

    ProductDiscipline.create!(product: @product, discipline: @discipline)

    assert_not_equal old_time, @product.reload.updated_at
  end
end
