require "test_helper"

# niente N+1: le query di una pagina non devono crescere con il numero di righe
class QueryBudgetTest < ActionDispatch::IntegrationTest
  setup do
    @yoga = disciplines(:yoga)
    @course = link!(products(:yoga_monthly), @yoga)
  end

  def queries_for(path)
    get path # scalda autoload e cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveRecord::Base.connection.clear_query_cache # nei test la cache sopravvive tra le richieste
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    assert_response :success
    count
  end

  def enroll(count)
    count.times do |i|
      member = Member.create!(first_name: "Allievo#{i}", last_name: "Kiosk", birth_date: "1990-01-01", fiscal_code_pending: true,
                              medical_certificate_expiry: Date.current + 100)
      Subscription.create!(member:, product: products(:annual_membership), start_date: Date.current - 10, end_date: Date.current + 200, agreed_price_cents: 0)
      # saldati: così lo stato arriva a "in scadenza" e il controllo del rinnovo viene davvero eseguito
      Subscription.create!(member:, product: @course, start_date: Date.current - 10, end_date: Date.current + (i.even? ? 3 : 20), agreed_price_cents: 0)
    end
  end

  test "kiosk discipline page does not grow with members" do
    sign_in_as(users(:staff))
    enroll(2)
    few = queries_for(kiosk_discipline_path(@yoga))

    enroll(8)
    many = queries_for(kiosk_discipline_path(@yoga))

    assert_equal few, many, "N+1 nel kiosk: #{few} query con 2 soci, #{many} con 10"
  end

  test "member subscriptions page does not grow with rows" do
    sign_in_as(users(:staff))
    member = members(:alice)
    add = ->(from, n) { n.times { |i| Subscription.create!(member:, product: @course, start_date: from + i * 40, end_date: from + i * 40 + 30, agreed_price_cents: 0) } }

    add.(Date.current - 400, 2)
    few = queries_for(member_subscriptions_path(member))

    add.(Date.current - 300, 6)
    many = queries_for(member_subscriptions_path(member))

    assert_equal few, many
    assert_operator few, :>, 3, "il contatore deve vedere le query reali"
  end

  test "members list does not grow with members" do
    sign_in_as(users(:staff))
    enroll(2)
    few = queries_for(members_path)

    enroll(8)
    many = queries_for(members_path)

    assert_equal few, many
  end

  test "the current user is loaded together with the session" do
    sign_in_as(users(:staff))
    get root_path
    queries = []
    collect = ->(*, payload) { queries << payload[:sql] unless payload[:cached] }
    ActiveRecord::Base.connection.clear_query_cache
    ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { get root_path }

    assert_equal 1, queries.count { it.include?('FROM "sessions"') }
    assert_equal 0, queries.count { it.match?(/FROM "users" WHERE "users"."id" = /) }
  end
end
