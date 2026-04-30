module FlashHelper
  FLASH_CLASSES = {
    notice:  "alert-success text-white",
    success: "alert-success text-white",
    alert:   "alert-error text-white",
    error:   "alert-error text-white",
    warning: "alert-warning text-black"
  }.with_indifferent_access.freeze

  def flash_class(type)
    FLASH_CLASSES[type] || "alert-info text-white"
  end

  def flash_icon_name(type)
    case type.to_sym
    when :alert, :error then "error"
    when :notice, :success then "success"
    when :warning then "warning"
    else "info"
    end
  end
end
