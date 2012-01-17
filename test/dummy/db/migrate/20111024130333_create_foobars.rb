# -*- encoding : utf-8 -*-
class CreateFoobars < ActiveRecord::Migration
  def change
    create_table :foobars do |t|
      t.string  :foo
      t.integer :bar

      t.timestamps
    end
  end
end

