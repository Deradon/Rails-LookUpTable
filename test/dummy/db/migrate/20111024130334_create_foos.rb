# -*- encoding : utf-8 -*-
class CreateFoos < ActiveRecord::Migration
  def change
    create_table :foos do |t|
      t.string  :foo
      #t.integer :bar

      t.timestamps
    end
  end
end

