class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      t.references :transport_request, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.decimal :base_price, precision: 10, scale: 2, null: false
      t.decimal :surcharge_total, precision: 10, scale: 2, default: 0.0
      t.string :currency, default: 'EUR', null: false
      t.datetime :valid_until
      t.datetime :accepted_at
      t.datetime :declined_at
      t.text :notes

      t.timestamps
    end

    add_index :quotes, :status
  end
end
