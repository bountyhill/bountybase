# Author::    radiospiel  (mailto:eno@radiospiel.org)
# Copyright:: Copyright (c) 2011, 2012 radiospiel
# License::   Distributes under the terms  of the Modified BSD License, see LICENSE.BSD for details.
module Expectations
  def expect!(*expectations)
    expectations.each do |expectation|
      enumerator = case expectation
        when Hash   then expectation.each
        when Array  then expectation.each_slice(2)
        else        raise ArgumentError, "Invalid expectation: #{expectation.inspect}"
      end

      enumerator.each do |value, e|
        Expectations.verify! value, e
      end
    end
  end

  def self.met?(value, expectation)
    case expectation
    when Array  then expectation.any? { |e| met?(value, e) }
    when Proc   then expectation.call(value)
    when Regexp then expectation =~ value.to_s
    else             expectation === value
    end
  end
  
  def self.verify!(value, expectation)
    return if met?(value, expectation)

    backtrace = caller[3..-1]
    
    e = ArgumentError.new "#{value.inspect} does not meet expectation #{expectation.inspect}"
    e.singleton_class.send(:define_method, :backtrace) do
      backtrace
    end
    raise e
  end
end

Object.send :include, Expectations
