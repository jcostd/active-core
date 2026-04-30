module ProductsHelper
  def product_category_badge(product)
    if product.associative?
      content_tag(:span, "Q. Associativa", class: "badge badge-info badge-soft badge-sm")
    else
      content_tag(:span, "Q. Istituzionale", class: "badge badge-warning badge-soft badge-sm")
    end
  end

  def product_category_text(product)
    if product.associative?
      content_tag(:span, "Quota Associativa", class: "text-info font-bold")
    else
      content_tag(:span, "Quota Istituzionale", class: "text-warning font-bold")
    end
  end
end
