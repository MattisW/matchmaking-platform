class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, default: 'dispatcher', null: false
    add_column :users, :company_name, :string
  end
end
