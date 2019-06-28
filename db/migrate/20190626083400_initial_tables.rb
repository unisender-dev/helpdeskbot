class InitialTables < ActiveRecord::Migration[5.2]
  def change

    create_table :admins do |t|
      t.string :username, null: false
      t.integer :chat_id, limit: 8, null: true
      t.integer :ticket_id, null: true
      t.string :name, null: true
    end
    add_index :admins, :username, unique: true

    create_table :users do |t|
      t.string :username, null: true
      t.string :firstname, null: true
      t.string :lastname, null: true
      t.integer :chat_id, limit: 8, null: true
      t.integer :ticket_id, null: true
    end

    create_table :tickets do |t|
      t.belongs_to :user, null: false
      t.belongs_to :admin
      t.integer :status, default: 0
      t.datetime :created_at, null: false
      t.datetime :closed_at
    end

    create_table :messages do |t|
      t.belongs_to :ticket, null: false
      t.belongs_to :user, null: true
      t.belongs_to :admin, null: true
      t.datetime :messaged_at, null: false
      t.text :message
      t.string :file_name
      t.string :file
      t.string :photo
    end

  end
end
