# Base mixin
module Attributes
  def initialize(attributes = {})
    self.attributes = attributes
  end

  def attributes=(hash)
    hash.each { |k, v| instance_variable_set "@#{k}", v }
  end

  def attributes
    Hash[instance_variables.map { |name| [name.to_s.sub('@', ''), instance_variable_get(name)] } ]
  end
end

# Entity mixin
module Entity
  include Attributes
  attr_accessor :id

  def initialize(id, attributes = {})
    @id = id.to_i
    super attributes
  end
end

# Clan model
class Clan
  include Entity
  attr_accessor :name, :provinces_count, :players

  def initialize(id, attributes = {})
    super id, attributes
    @players = []
  end
end

# Player model
class Player
  include Entity
  attr_accessor :account_name, :player_tanks
end

# Player tank model
class PlayerTank
  include Entity
  attr_accessor :mark_of_mastery, :tank
end

# Tank model
class Tank
  include Entity
  attr_accessor :name_i18n, :gun_damage_min, :gun_damage_max, :max_health, :level
end

# Registry of tanks
class TankRegistry
  @@tanks = {}

  def self.get(id)
    @@tanks[id.to_i] ||= Tank.new id
  end

  def self.tanks
    @@tanks.values
  end
end

# Clan combinations
class ClanCombinations
  include Attributes
  attr_accessor :weight, :combinations, :tanks, :clan

  def weight
    @combinations.inject(0) { |memo, c| memo += c.weight }
  end
end

# Combination
class Combination
  include Attributes
  attr_accessor :mark_of_mastery, :tank, :account_id, :player

  def weight
    @weight ||= (mastery_weight * tank_weight).round(3)
  end

  def mastery_weight
    @mastery_weight ||= (@mark_of_mastery * 2).round(3)
  end

  def tank_weight
    @tank_weight ||= (@tank.gun_damage_min * 0.01 * @tank.gun_damage_max * 0.01 * @tank.max_health * 0.05 *  @tank.level * 0.1).round(3)
  end

  def tank_id
    @tank.id
  end
end
