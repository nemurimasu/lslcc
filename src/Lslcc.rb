#!/usr/bin/env jruby

include Java

java_import 'org.antlr.runtime.ANTLRFileStream'
java_import 'org.antlr.runtime.TokenRewriteStream'
java_import 'org.antlr.runtime.Token'
java_import 'org.antlr.runtime.tree.TreeAdaptor'
java_import 'org.antlr.runtime.tree.CommonTreeAdaptor'
java_import 'org.antlr.runtime.tree.BaseTree'
java_import 'org.antlr.runtime.tree.CommonTree'
java_import 'org.lslcc.antlr.LslLexer'
java_import 'org.lslcc.antlr.LslParser'

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
      lex = LslLexer.new(ANTLRFileStream.new(file, 'utf-8'))
      tokens = TokenRewriteStream.new(lex)
      grammar = LslParser.new(tokens)
      grammar.set_tree_adaptor(LslAntlr::LslTreeAdaptor.new)
      ret = grammar.lscriptProgram
      tree = ret.tree.convert
      tree.all_functions.each do |f|
        f.body.insert(0, Lsl::Expression.new([Lsl::Call.new({:name => 'llOwnerSay', :params => ["\"Entering #{f.name}\""]})]))
      end
      puts tree
    end
  end
end

Lslcc.main(ARGV)
