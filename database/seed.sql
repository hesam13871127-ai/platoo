USE vibetable;

INSERT INTO games (id, display_name, category, min_players, max_players, supports_teams, accent_color, icon_key, config) VALUES
('ocho','Ocho','cards',2,4,FALSE,'#7C5CFC','style',JSON_OBJECT('deckSize',108)),
('pool_8_ball','Pool 8-ball','sports',2,2,FALSE,'#1C9B78','sports_bar',JSON_OBJECT('tableSize',8)),
('ludo','Ludo','board',2,4,TRUE,'#F36B4B','casino',JSON_OBJECT('tokensPerPlayer',4)),
('werewolf','Werewolf','party',5,12,FALSE,'#8B5CF6','nightlife',JSON_OBJECT('nightLength',45)),
('chess','Chess','board',2,2,FALSE,'#C9894B','grid_on',JSON_OBJECT('clockSeconds',600)),
('four_in_a_row','4 in a Row','board',2,2,FALSE,'#E94862','view_week',JSON_OBJECT('rows',6,'columns',7)),
('dice_party','Dice Party','party',2,6,FALSE,'#F2A93B','casino',JSON_OBJECT('rounds',5)),
('carrom','Carrom','board',2,4,TRUE,'#BE8B58','radio_button_checked',JSON_OBJECT('coins',19)),
('bingo','Bingo','party',2,8,FALSE,'#EC4899','confirmation_num',JSON_OBJECT('size',5)),
('dominoes','Dominoes','board',2,4,FALSE,'#6B7280','view_module',JSON_OBJECT('doubleSix',TRUE)),
('backgammon','Backgammon','board',2,2,FALSE,'#A9673B','casino',JSON_OBJECT('points',15)),
('checkers','Checkers','board',2,2,FALSE,'#D946EF','grid_4x4',JSON_OBJECT('boardSize',8)),
('mini_golf','Mini Golf','sports',2,4,FALSE,'#22A06B','golf_course',JSON_OBJECT('holes',9)),
('table_soccer','Table Soccer','sports',2,4,TRUE,'#159A8C','sports_soccer',JSON_OBJECT('goals',5)),
('archery','Archery','sports',1,4,FALSE,'#E76F51','gps_fixed',JSON_OBJECT('rounds',5)),
('bowling','Bowling','sports',1,4,FALSE,'#4F7CAC','sports',JSON_OBJECT('frames',10)),
('darts','Darts','sports',1,4,FALSE,'#B7791F','adjust',JSON_OBJECT('target',301)),
('sea_battle','Sea Battle','board',2,2,FALSE,'#1882A5','directions_boat',JSON_OBJECT('grid',10)),
('mancala','Mancala','board',2,2,FALSE,'#B5651D','circle',JSON_OBJECT('pits',6)),
('hearts','Hearts','cards',3,4,FALSE,'#E04F5F','favorite',JSON_OBJECT('targetScore',100)),
('spades','Spades','cards',4,4,TRUE,'#334155','style',JSON_OBJECT('targetScore',500)),
('sketch_guess','Sketch & Guess','party',3,8,FALSE,'#F59E0B','brush',JSON_OBJECT('roundSeconds',60)),
('trivia_battle','Trivia Battle','party',2,8,FALSE,'#3B82F6','quiz',JSON_OBJECT('questions',10)),
('emoji_charades','Emoji Charades','party',3,8,FALSE,'#F97316','emoji_emotions',JSON_OBJECT('roundSeconds',45)),
('word_chain','Word Chain','party',2,8,FALSE,'#10B981','translate',JSON_OBJECT('turnSeconds',20)),
('memory_race','Memory Race','party',2,6,FALSE,'#8B5CF6','memory',JSON_OBJECT('pairs',12)),
('impostor_light','Impostor Light','party',4,10,FALSE,'#DC2626','visibility_off',JSON_OBJECT('roundSeconds',90)),
('quick_challenges','Quick Challenges','arcade',1,6,FALSE,'#EAB308','bolt',JSON_OBJECT('rounds',7))
ON DUPLICATE KEY UPDATE display_name=VALUES(display_name), config=VALUES(config), is_active=TRUE;

INSERT INTO shop_items (id, sku, name, description, category, price_coins, price_pips, asset_key, is_giftable) VALUES
('10000000-0000-4000-8000-000000000001','avatar-neon','Neon Nova','A bright neon profile avatar.','avatar',500,0,'avatar_neon',TRUE),
('10000000-0000-4000-8000-000000000002','frame-sunset','Sunset Frame','Warm sunset frame for your profile.','frame',750,0,'frame_sunset',TRUE),
('10000000-0000-4000-8000-000000000003','emote-fire','Fire Emote','Show the table who is on fire.','emote',250,0,'emote_fire',TRUE),
('10000000-0000-4000-8000-000000000004','table-aurora','Aurora Table','An aurora-lit table for private rooms.','table',1500,0,'table_aurora',TRUE),
('10000000-0000-4000-8000-000000000005','dice-crystal','Crystal Dice','Transparent crystal dice with electric edges.','dice',1000,0,'dice_crystal',TRUE),
('10000000-0000-4000-8000-000000000006','bundle-starter','Starter Vibe Pack','Avatar, frame, emote and 1,500 coins.','bundle',0,150,'bundle_starter',TRUE)
ON DUPLICATE KEY UPDATE name=VALUES(name), description=VALUES(description), price_coins=VALUES(price_coins), price_pips=VALUES(price_pips), is_active=TRUE;

INSERT INTO seasons (id, name, starts_at, ends_at, status)
VALUES ('20000000-0000-4000-8000-000000000001','Season One: First Light','2026-01-01 00:00:00.000','2026-12-31 23:59:59.000','active')
ON DUPLICATE KEY UPDATE status=VALUES(status), starts_at=VALUES(starts_at), ends_at=VALUES(ends_at);

INSERT INTO season_rewards (id, season_id, min_rank, max_rank, coins, pips, shop_item_id) VALUES
('21000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',1,1,10000,300,'10000000-0000-4000-8000-000000000004'),
('21000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001',2,10,5000,150,'10000000-0000-4000-8000-000000000003'),
('21000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000001',11,100,1500,50,NULL)
ON DUPLICATE KEY UPDATE coins=VALUES(coins), pips=VALUES(pips), shop_item_id=VALUES(shop_item_id);
