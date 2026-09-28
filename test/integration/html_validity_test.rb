require "test_helper"

# HTML5 valido su tutte le pagine principali: struttura, id unici, attributi non ripetuti
class HtmlValidityTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    @sale = sell!(member: @member, product: course)
    Attendance.create!(member: @member, discipline: disciplines(:yoga), marked_by: users(:kiosk))
    Subscription.create!(member: members(:bob), product: course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    sign_in_as(users(:admin))
  end

  PAGES = {
    "dashboard" => ->(t) { t.root_path },
    "soci" => ->(t) { t.members_path },
    "socio" => ->(t) { t.member_path(t.members(:alice)) },
    "abbonamenti socio" => ->(t) { t.member_subscriptions_path(t.members(:alice)) },
    "acquisti socio" => ->(t) { t.member_sales_path(t.members(:alice)) },
    "discipline" => ->(t) { t.disciplines_path },
    "iscritti disciplina" => ->(t) { t.discipline_members_path(t.disciplines(:yoga)) },
    "prodotti" => ->(t) { t.products_path },
    "vendite" => ->(t) { t.sales_path },
    "vendita" => ->(t) { t.sale_path(t.instance_variable_get(:@sale)) },
    "POS" => ->(t) { t.new_sale_path(member_id: t.members(:alice).id) },
    "modifica socio a pagina intera" => ->(t) { t.edit_member_path(t.members(:alice)) },
    "segnalazione a pagina intera" => ->(t) { t.new_feedback_path },
    "report" => ->(t) { t.reports_path },
    "presenze socio" => ->(t) { t.member_attendances_path(t.members(:alice)) },
    "iscritti di un mese chiuso" => ->(t) { t.discipline_members_path(t.disciplines(:yoga), month: Date.current.prev_month.strftime("%Y-%m")) },
    "utenti" => ->(t) { t.users_path },
    "dati ASD" => ->(t) { t.gym_profile_path },
    "modifica dati ASD" => ->(t) { t.edit_gym_profile_path },
    "kiosk" => ->(t) { t.kiosk_root_path },
    "registro kiosk" => ->(t) { t.kiosk_discipline_path(t.disciplines(:yoga)) },
    "ricerca kiosk" => ->(t) { t.kiosk_discipline_member_searches_path(t.disciplines(:yoga), query: "i") },
    "accesso" => ->(t) { t.new_session_path },
    "recupero password" => ->(t) { t.new_password_path },
    "nuova password" => ->(t) { t.edit_password_path(t.users(:staff).password_reset_token) }
  }

  PAGES.each do |name, path|
    test "#{name} is valid html" do
      get path.(self)
      assert_response :success

      html = response.body
      doc = Nokogiri::HTML5(html, max_errors: 20)
      errors = doc.errors.map(&:message).reject { it.include?("Expected a doctype token") } # frammenti turbo/modal
      assert_empty errors, "errori HTML in #{name}:\n#{errors.join("\n")}"

      duplicated_ids = doc.css("[id]").map { it["id"] }.tally.select { |_, n| n > 1 }.keys
      assert_empty duplicated_ids, "id duplicati in #{name}"

      assert_empty doc.css("legend").reject { it.parent.name == "fieldset" && it.parent.element_children.first == it }, "legend fuori posto"
      assert_empty doc.css("div[disabled], span[disabled], a[disabled]"), "disabled su elemento non di form"
    end
  end
end
