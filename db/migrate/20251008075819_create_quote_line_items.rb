class CreateQuoteLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_line_items do |t|
      t.references :quote, null: false, foreign_key: true
      t.string :description, null: false
      t.string :calculation
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :line_order, default: 0

      t.timestamps
    end

    add_index :quote_line_items, [:quote_id, :line_order]
  end
end
