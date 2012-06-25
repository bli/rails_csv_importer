ActiveRecord::Schema.define(:version => 0) do
  create_table :categories, :force => true do |t|
    t.string :name
  end

  create_table :materials, :force => true do |t|
    t.string :name

    t.boolean :fragile, :default => false
    t.integer :category_id
  end
end

