require "test_helper"

class ItalianMessagesTest < ActiveSupport::TestCase
  test "app runs in italian only" do
    assert_equal [ :it ], I18n.available_locales
    assert_equal :it, I18n.default_locale
  end

  test "full messages use italian attribute names" do
    sale = Sale.new(amount_cents: -1)
    sale.validate

    assert_includes sale.errors.full_messages, "Importo deve essere maggiore o uguale a 0"
    assert_includes sale.errors.full_messages, "Socio deve esistere"
  end

  test "nested subscription errors are named in italian" do
    member = members(:alice)
    grant_membership_to(member)
    quota = products(:annual_membership)
    busy = member.subscriptions.kept.find_by!(end_date: Date.current.end_of_year)

    sale = Sale.new(member:, product: quota, user: users(:staff), sold_on: Date.current,
                    subscription_attributes: { member:, product: quota, start_date: busy.start_date, end_date: busy.end_date })
    sale.validate

    assert_includes sale.errors.full_messages, "Abbonamento Già un abbonamento per '#{quota.name}' in queste date."
  end

  test "username format message is italian" do
    user = User.new(username: "Mario Rossi")
    user.validate
    assert_includes user.errors.full_messages, "Username può contenere solo lettere minuscole, numeri e underscore"
  end

  test "every validated attribute has an italian name" do
    [ AccessLog, Attendance, Discipline, Feedback, GymProfile, Member, Product, Sale, Subscription, User ].each do |model|
      model.validators.flat_map(&:attributes).uniq.each do |attr|
        key = "activerecord.attributes.#{model.model_name.i18n_key}.#{attr}"
        assert I18n.exists?(key, :it), "manca #{key}"
      end
    end
  end
end
