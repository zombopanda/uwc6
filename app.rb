require 'bundler/setup'
Bundler.require(:default, :development)
require './wg_api'
require './utils'
require './models'


api_key = '0e31839d1668e03ca28bc62faeaf2d04'
api = WgAPI.new(api_key, Logger.new)

time do
  SpinningCursor.run do
    banner "Processing"
    type :dots
  end

  # получаем кланы
  clans = api.globalwar_top(map_id: 'globalmap', order_by: 'provinces_count')[0...15]
    .select { |clan| clan['members_count'] > 30 }.sample(2)
    .map do |clan| 
    Clan.new clan['clan_id'], name: clan['name'], provinces_count: clan['provinces_count']
  end

  # получаем игроков клана
  api.clan_info(clan_id: clans.map(&:id).join(','), fields: 'members.account_id,members.account_name').each do |clan_id, data|
    # берем 20 случайных участников
    Parallel.each data['members'].values.first(20), in_threads: 16 do |data|
      player = Player.new data['account_id'], account_name: data['account_name']
      # получаем танки
      player.player_tanks = api.tanks_stats(account_id: player.id, fields: 'tank_id,mark_of_mastery').values.flatten.map do |tank| 
        PlayerTank.new tank['tank_id'], tank: TankRegistry.get(tank['tank_id']), mark_of_mastery: tank['mark_of_mastery']
      end
      clans.find { |c| c.id == clan_id.to_i }.players << player
    end
  end

  # выбираем 15 участников с танков > 15
  clans.each do |clan|
    clan.players = clan.players.select { |player| player.player_tanks.length > 15 }.sample(15)
  end

  # получаем характеристики танков
  api.encyclopedia_tankinfo(
    tank_id: TankRegistry.tanks.map(&:id).join(','), fields: 'name_i18n,gun_damage_min,gun_damage_max,max_health,level'
  ).each do |tank_id, data|
    TankRegistry.get(tank_id).attributes = data
  end

  # считаем команды и сортируем кланы по весу
  clan_combinations = clans.map do |clan|
    # получаем обьекты комбинаций сгрупированные по tank_id 
    grouped_tanks = clan.players.map do |player|
      player.player_tanks.map do |t| 
        Combination.new tank: t.tank, mark_of_mastery: t.mark_of_mastery, account_id: player.id, player: player
      end
    end
      .flatten
      .select { |t| (4..6).include? t.tank.level }
      .group_by(&:tank_id)

    player_ids = clan.players.map(&:id)
    all_combinations = []

    # побираем танки для игроков
    grouped_tanks.sort_by { |tank_id, combinations| combinations.map(&:tank_weight).uniq }.reverse.each do |tank_id, combinations|
      break if player_ids.empty?

      combinations.sort_by(&:mark_of_mastery).reverse.each do |c|
        if player_ids.include?(c.account_id) && c.mark_of_mastery > 0
          player_ids.delete c.account_id
          all_combinations << c
          break
        end
      end
    end

    ClanCombinations.new clan: clan, combinations: all_combinations, tanks: grouped_tanks
  end.sort_by(&:weight)

  # первый - клан с большим весом
  last, first = clan_combinations

  # получаем незадействованные танки для первого клана
  other_tanks_ids = first.combinations.map(&:tank_id)
  other_tanks = first.tanks
    .sort_by { |tank_id, combinations| combinations.map(&:tank_weight).uniq }
    .reverse
    .select {|k, v| !other_tanks_ids.include? k }

  # уменьшаем вес первого клана к уровню второго
  weight = first.weight
  first.combinations.each do |combination|
    other_tanks.each do |tank_id, combs|
      # закончить если вес отличается не более чем на 5%
      break if (first.weight / last.weight * 100) < 105

      combs.sort_by(&:mark_of_mastery).reverse.each do |comb|
        if comb.weight > 0 && (weight - combination.weight + comb.weight) > last.weight
          weight = weight - combination.weight + comb.weight
          combination.attributes = comb.attributes
          break
        end
      end
    end
  end

  SpinningCursor.stop  

  # рисуем таблицы
  clan_combinations.each do |clan_combination|
    puts Terminal::Table.new(
      headings: [cut_string(clan_combination.clan.name, 25), 
        "Танк (#{clan_combination.weight.round(2)})", 'MoM', 'GDMin', 'GDMax', 'MH', 'Lvl'],
      rows: clan_combination.combinations.map do |c|
        [cut_string(c.player.account_name, 25), cut_string(c.tank.name_i18n, 20), c.mark_of_mastery, c.tank.gun_damage_min, 
          c.tank.gun_damage_max, c.tank.max_health, c.tank.level]
      end
    )
  end

  puts ' * - MoM (Mark of mastery), GDMin (Gun damage min), GDMax (Gun damage max), MH (Max health), Lvl (Level)'
end
