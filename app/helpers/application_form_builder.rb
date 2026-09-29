# campi di un form con le classi di daisyUI già messe: basta f.text_field :name. Una class esplicita le sostituisce
class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  %i[ text_field email_field telephone_field password_field date_field datetime_field number_field ].each do |helper|
    define_method(helper) { |method, options = {}| super(method, { class: "input w-full" }.merge(options)) }
  end

  def text_area(method, options = {}) = super(method, { class: "textarea w-full" }.merge(options))

  def select(method, choices = nil, options = {}, html_options = {}, &)
    super(method, choices, options, { class: "select w-full" }.merge(html_options), &)
  end

  def label(method, text = nil, options = {}, &)
    text, options = nil, text if text.is_a?(Hash)
    super(method, text, { class: "label" }.merge(options), &)
  end

  def submit(value = "Salva", options = {})
    super(value, { class: "btn btn-primary", data: { turbo_submits_with: "Salvataggio..." } }.merge(options))
  end
end
