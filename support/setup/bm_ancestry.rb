require "bundler/setup"
require "active_record"
require "ancestry"

# Env variables
#   DATABASE_URL  url for the database
#   COUNT         number of children per parent (will only be 1 root)
#   DEPTH         number of levels of children
ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL'))
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :ancestry
    t.string :name
  end
  add_index :users, :ancestry
end

class User < ActiveRecord::Base
  has_ancestry
end

def create_tree(parent, name: 'Tree 1', count: 2, depth: 2)
  if parent.kind_of?(Class) # root
    root = parent.create(name: name)
    create_tree(root, name: name, count: count, depth: depth - 1)
  else
    count.times do |i|
      # parent_id: parent.id
      child = parent.children.create(name: "#{name}.#{i+1}")
      create_tree(child, name: child.name, count: count, depth: depth - 1) if depth > 1
    end
  end
end

count = ENV["COUNT"]&.to_i || 6
depth = ENV["DEPTH"]&.to_i || 4
create_tree(User, name: 'Tree 1', count: count, depth: depth)
