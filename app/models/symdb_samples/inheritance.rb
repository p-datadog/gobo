# frozen_string_literal: true

# Exercises: Class inheritance chain, superclass in language_specifics.
# Expected:
#   Inheritance::Vehicle:     no super_classes (Object excluded)
#   Inheritance::Car:         super_classes = ['SymdbSamples::Inheritance::Vehicle']
#   Inheritance::ElectricCar: super_classes = ['SymdbSamples::Inheritance::Car']
module SymdbSamples
  module Inheritance
    class Vehicle
      attr_reader :make, :model, :year

      def initialize(make, model, year)
        @make  = make
        @model = model
        @year  = year
      end

      def description
        "#{year} #{make} #{model}"
      end

      def age
        Time.now.year - @year
      end
    end

    class Car < Vehicle
      attr_reader :doors

      def initialize(make, model, year, doors = 4)
        super(make, model, year)
        @doors = doors
      end

      def sedan?
        @doors == 4
      end

      def to_s
        "#{description} (#{doors}-door)"
      end
    end

    class ElectricCar < Car
      attr_reader :range_km

      def initialize(make, model, year, range_km)
        super(make, model, year)
        @range_km = range_km
      end

      def zero_emissions?
        true
      end

      def to_s
        "#{description} EV (range: #{range_km}km)"
      end
    end
  end
end
