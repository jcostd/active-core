module ProductsHelper
  def product_category_badge(product)
    if product.associative?
      tag.span "Q. Associativa", class: "badge badge-info badge-soft badge-sm"
    else
      tag.span "Q. Istituzionale", class: "badge badge-warning badge-soft badge-sm"
    end
  end
end
