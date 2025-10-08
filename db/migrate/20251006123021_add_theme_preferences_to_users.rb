class AddThemePreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :theme_mode, :string
    add_column :users, :accent_color, :string
    add_column :users, :font_size, :string
    add_column :users, :density, :string
    add_column :users, :avatar_url, :string
  end
end
