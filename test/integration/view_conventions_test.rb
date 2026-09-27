require "test_helper"

# convenzioni sulle viste verificate staticamente
class ViewConventionsTest < ActiveSupport::TestCase
  VIEWS = Dir[Rails.root.join("app/views/**/*.erb")]

  test "no Tailwind class is built at runtime" do
    offenders = VIEWS.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, i|
        "#{file.delete_prefix(Rails.root.to_s)}:#{i + 1}" if line.match?(/\b[a-z]+-<%=/)
      end
    end
    assert_empty offenders, "classi composte al volo: Tailwind non le genera"
  end

  test "helpers do not build Tailwind classes at runtime" do
    offenders = Dir[Rails.root.join("app/helpers/**/*.rb")].select { File.read(it).match?(/\b[a-z]+-\#\{/) }
    assert_empty offenders
  end

  test "colors come from the daisyUI theme, not the raw Tailwind palette" do
    palette = /\b(?:bg|text|border|outline|ring)-(?:red|blue|gray|green|yellow|slate|zinc|stone)-\d{2,3}\b/
    offenders = VIEWS.select { File.read(it).match?(palette) }
    assert_empty offenders, "usare i colori semantici del tema (error, primary, base-content...)"
  end

  test "every sort offered by a page is known to its model" do
    default = %w[created_desc created_asc name_asc name_desc]

    [ Member, User, Product, Discipline, Sale ].each do |model|
      assert_empty default - model::SORTS.keys, "#{model} non conosce un ordinamento predefinito"
    end
    assert_empty %w[date_desc date_asc] - AccessLog::SORTS.keys
  end

  test "no daisyUI 4 classes" do
    old = %w[input-bordered select-bordered textarea-bordered form-control label-text btn-group card-bordered]
    offenders = VIEWS.select { |file| old.any? { File.read(file).include?(it) } }
    assert_empty offenders
  end
end
