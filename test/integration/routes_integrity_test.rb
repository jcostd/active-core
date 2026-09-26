require "test_helper"

# ogni route deve puntare a un'azione esistente, e ogni GET a una vista
class RoutesIntegrityTest < ActionDispatch::IntegrationTest
  FRAMEWORK = %w[rails/ active_storage action_mailbox turbo]
  NO_TEMPLATE = %w[preferences/themes#update]

  test "every route has an action" do
    app_routes.each do |controller, action, _|
      klass = "#{controller.camelize}Controller".safe_constantize
      assert klass&.action_methods&.include?(action), "manca #{controller}##{action}"
    end
  end

  test "every GET route has a template" do
    app_routes.select { |*, verb| verb.include?("GET") }.each do |controller, action, _|
      next if NO_TEMPLATE.include?("#{controller}##{action}")
      assert Dir[Rails.root.join("app/views/#{controller}/#{action}.*")].any?, "manca la vista #{controller}/#{action}"
    end
  end

  private
    def app_routes
      Rails.application.routes.routes.filter_map do |route|
        controller, action = route.defaults.values_at(:controller, :action)
        next if controller.nil? || controller.start_with?(*FRAMEWORK)
        [ controller, action, route.verb ]
      end
    end
end
