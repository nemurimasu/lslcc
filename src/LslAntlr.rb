#!/usr/bin/env jruby

module LslAntlr
  # the tree class used by Antlr
  class LslTree < CommonTree
    # map of integer token types to Node subclasses
    @@clsmap = nil
    # map of integer tokens to field names(TYPE -> type)
    @@namemap = nil
    # return an empty array instead of null when there are now children
    def children
      a = super
      return [] unless a
      return a
    end
    # properly duplicate nodes
    def dupNode
      self.class.new(self)
    end
    # convert this subtree into the proper class from the Lsl module
    def convert
      make_maps unless @@clsmap
      cls = @@clsmap[token.type]
      if cls
        # this node converts to an Lsl type
        node = cls.new
        others = []

        children.each do |child|
          # get the field name associated with the child's token type
          name = @@namemap[child.type]
          # names that end in 's' are taken to be arrays
          if name and name.end_with? 's'
            c = child.children.map {|gc| gc.convert}
          else
            c = child.convert
          end
          if name
            # determine setter method
            name += '='
            if node.respond_to? name
              # send setter method
              node.__send__(name.to_sym, c)
            elsif node.respond_to? :value=
              # fallback to setting single value
              node.value = c
            else
              # store in array to set values field later
              others << c
            end
          elsif node.respond_to? :value=
            # fallback to setting single value(because we don't know the name)
            node.value = c
          else
            # store in array to set values field later
            others << c
          end
        end
        if node.respond_to? :values=
          # set values field(possible empty)
          node.values = others
        elsif others.length != 0
          # we're about to discard part of the tree!
          raise "We have an array of values(#{others.inspect}), but #{node.class.to_s} does not accept a values array."
        end
        return node
      end
      return case children.length
      when 0 then self.text
      when 1 then children.first.convert
      else raise "collection of child nodes(#{children.inspect}) inside unknown node #{self.text}"
      end
    end

    private
    # build our map of IDs
    def make_maps
      java_class.synchronized do
        unless @@clsmap
          # IDs to classes
          @@clsmap = {}
          # IDs to field names
          @@namemap = {}
          # get classes
          lsl_constants = Lsl.constants
          # get all constants from LslParser(might be token names)
          LslParser.constants.each do |constant|
            # convert CONSTANT_NAME to field_name and ClassName
            fieldname = constant.downcase
            clsname = fieldname.split('_').each{|part| part.capitalize!}.join
            value = LslParser.const_get(constant)
            next unless value.kind_of? Fixnum
            @@namemap[value] = fieldname
            # check for existance
            if lsl_constants.include? clsname then
              cls = Lsl.const_get(clsname)
              # check for types and record
              @@clsmap[value] = cls if cls.kind_of? Class and cls != Lsl::Node
            end
          end
        end
      end
    end
  end

  class LslTreeAdaptor < CommonTreeAdaptor
    def create( token )
      if token
        return LslTree.new(token)
      end
      # JRuby doesn't work for LslTree.new(nil)
      # these nodes all get deleted before the tree leaves Antlr anyway
      return CommonTree.new(token)
    end
  end
end
