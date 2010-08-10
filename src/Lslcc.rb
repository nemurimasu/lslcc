#!/usr/bin/env jruby

include Java

require 'LslNodes.rb'
require 'LslAntlr.rb'

class Array
  def parent=( value )
    self.each {|nn| nn.parent = value if nn.respond_to? :parent= }
  end
end

class Lslcc
  java_signature 'void main(String[])'
  def self.main(args)
    args.each do |file|
      puts file if args.length > 1
      tree = LslAntlr::LslParser.new(file).lscriptProgram
      tree.all_functions.each do |f|
        f.body.insert(0, Lsl::Expression.new([Lsl::Call.new({:name => 'llOwnerSay', :params => ["\"Entering #{f.name}\""]})]))
      end
      puts tree
    end
  end
end

Lslcc.main(ARGV)
