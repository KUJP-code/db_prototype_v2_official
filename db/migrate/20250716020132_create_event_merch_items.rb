class CreateEventMerchItems < ActiveRecord::Migration[7.1]
  def change
    create_table :event_merch_items do |t|
      t.references :event, null: false, foreign_key: true
      t.references :merch_item, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_merch_items, [:event_id, :merch_item_id], unique: true
  end
end
