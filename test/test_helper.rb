ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/caching_test_helper"

module ActiveSupport
  class TestCase
    # Test in parallelo con N worker
    parallelize(workers: ENV["CI"] ? 1 : :number_of_processors)

    # Carica tutte le fixture di test/fixtures/*.yml in ordine alfabetico.
    fixtures :all

    # TEST_NOW="2027-01-01 10:00" bin/rails test: esegue la suite in una data a scelta.
    # Si viaggia prima di super, cioè prima delle fixture: anche il loro ERB (1.year.from_now) vede TEST_NOW
    if ENV["TEST_NOW"]
      def before_setup
        travel_to Time.zone.parse(ENV["TEST_NOW"])
        super
      end
    end

    # Helper condivisi da tutti i test.
    # quote dell'anno solare da 3 anni prima a 3 dopo start_date; salta gli anni già coperti
    def grant_membership_to(member, start_date: Date.current)
      membership_product = products(:annual_membership)
      staff_user = users(:admin) # storico: date nel passato, solo admin

      base_date = start_date.beginning_of_year

      (-3..3).each do |offset|
        d = base_date + offset.years
        next if member.subscriptions.kept.where(product: membership_product, start_date: ..d.end_of_year, end_date: d..).exists?

        Sale.create!(
          member: member,
          user: staff_user,
          product: membership_product,
          sold_on: d,
          payment_method: :cash,
          subscription_attributes: {
            member: member,
            product: membership_product,
            start_date: d,
            end_date: d.end_of_year
          }
        )
      end
    end

    # vendita + abbonamento in un colpo; amount nil = prezzo concordato
    def sell!(member:, product:, user: users(:staff), amount: nil, sold_on: Date.current, payment_method: :cash, **subscription)
      Sale.create!(member:, product:, user:, amount:, sold_on:, payment_method:,
                   subscription_attributes: { member:, product:, **subscription })
    end

    def link!(product, *disciplines)
      disciplines.each { ProductDiscipline.create!(product:, discipline: it) }
      product.reload
    end
  end
end
