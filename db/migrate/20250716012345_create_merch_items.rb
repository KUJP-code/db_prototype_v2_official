class CreateMerchItems < ActiveRecord::Migration[7.1]
  def change
    create_table :merch_items do |t|
      t.string  :name, null: false
      t.integer :cost, null: false
      t.integer :stock
      t.string :sku
      t.boolean :closed, default: false
      t.datetime :close_at
      t.string :event_name
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
