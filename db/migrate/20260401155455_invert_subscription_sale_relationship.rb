class InvertSubscriptionSaleRelationship < ActiveRecord::Migration[8.1]
  def up
    add_reference :sales, :subscription, foreign_key: true, null: true

    Subscription.find_each do |sub|
      Sale.where(id: sub.sale_id).update_all(subscription_id: sub.id)
    end

    remove_reference :subscriptions, :sale, foreign_key: true
  end

  def down
    add_reference :subscriptions, :sale, foreign_key: true, null: true
    Sale.where.not(subscription_id: nil).find_each do |sale|
      Subscription.where(id: sale.subscription_id).update_all(sale_id: sale.id)
    end
    remove_reference :sales, :subscription, foreign_key: true
  end
end
