module terc3;

//import ui;
//import uig;
import chat;
import libc;
import raylib;
import vector2;
import std::io;
import std::collections::list;

import tiles;
import chunks;
import inventory;

struct Player {
	raylib::Vector2 position;
	raylib::Vector2 size;
	raylib::Vector2 velocity;
	bool on_ground;
}

struct Bomb {
	double birthtime;
	raylib::Vector2 position;
}

Player player = {
	raylib::Vector2 { 10, -128 },
	raylib::Vector2 { 28, 64 },
	raylib::Vector2 { 0, 0 },
	false
};

struct SelectedMineProgress {
    double start_time;
    Vector2i position;
    double progress;
}
SelectedMineProgress mine_progress;

List(<Bomb>) bombs;
bool sigint_hit = false;

raylib::Camera2D camera;
raylib::Texture2D ants_tex;
raylib::Texture2D bomb_tex;

fn void harvest_tile(int x, int y) {
	ItemID tile_id = chunks::get_tile(x, y);
	if (!tile_id) return;
	inventory::add_item(tile_id, 1);
	chunks::set_tile(x, y, 0);
}

fn Vector2i get_mouse_tpos() {
	return Vector2i {
		(int)($$floor(((raylib::get_mouse_x() / camera.zoom) + camera.target.x) / chunks::TILE_SIZE)),
		(int)($$floor(((raylib::get_mouse_y() / camera.zoom) + camera.target.y) / chunks::TILE_SIZE)),
	};
}

fn void place(bool break_tile) {
	Vector2i tile_pos = get_mouse_tpos();

	if (break_tile) {
		harvest_tile(tile_pos.x, tile_pos.y);
		return;
	}

    ItemID item_id = inventory::selected_item().id; //inventory::inventory[inventory::cursor_index].item;
	TileID! future_tile_id = tiles::item2tile.get(item_id).id;

	if (catch future_tile_id) return;
	if (!inventory::has_item(item_id)) return;

	ItemID tile_id = chunks::get_tile(tile_pos.x, tile_pos.y);
	if (tile_id) return;

	inventory::add_item(item_id, -1);
	chunks::set_tile(tile_pos.x, tile_pos.y, future_tile_id);
}

fn bool air_adjacent(Vector2i pos) {
    // NOTE: Returns FALSE if tile is actually air

    if (chunks::get_tile(pos.x, pos.y) == 0) return false;

    for (int x_off = -1; x_off <= 1; x_off++) {
        for (int y_off = -1; y_off <= 1; y_off++) {
            if (chunks::get_tile(pos.x + x_off, pos.y + y_off) == 0) return true;
        }
    }

    return false;
}

fn double mine_time(ItemID tile) {
	if (inventory::selected_item().id == 5) return 0.1;
    if (tile == 3) return 2.0;
    if (tile == 4) return 2.0;
    if (tile == 6) return 0.1;
    if (tile == 7) return 3.0;
    return 0.3;
}

fn void mine_held() {
    double time = raylib::get_time();
    Vector2i tile_pos = get_mouse_tpos();

    if (!mine_progress.start_time || !tile_pos.eq(mine_progress.position)) {
        if (!air_adjacent(tile_pos)) {
            mine_progress.start_time = 0.0;
            return;
        }
        mine_progress.start_time = time;
        mine_progress.position = tile_pos;
        mine_progress.progress = 0.0;
        return;
    }

    double time_needed = mine_time(chunks::get_tile(tile_pos.x, tile_pos.y));

    mine_progress.progress = (time - mine_progress.start_time) / time_needed;

    if (time - mine_progress.start_time < time_needed) return;

    mine_progress.start_time = 0.0;
    place(true);
}

fn void logic() {
	player_physics();

	if (raylib::is_mouse_button_released(raylib::MouseButton.BUTTON_LEFT)) {
        mine_progress.start_time = 0.0;
    } else if (raylib::is_mouse_button_down(raylib::MouseButton.BUTTON_LEFT)) {
        mine_held();
	}

	if (raylib::is_mouse_button_down(raylib::MouseButton.BUTTON_RIGHT)) {
		place(false);
	}

	if (raylib::is_key_pressed(raylib::keyboard::B)) {
		spawn_bomb(player.position);
	}

	if (raylib::is_key_pressed(raylib::keyboard::ONE)) inventory::cursor_index = 0;
	if (raylib::is_key_pressed(raylib::keyboard::TWO)) inventory::cursor_index = 1;
	if (raylib::is_key_pressed(raylib::keyboard::THREE)) inventory::cursor_index = 2;
	if (raylib::is_key_pressed(raylib::keyboard::FOUR)) inventory::cursor_index = 3;
	if (raylib::is_key_pressed(raylib::keyboard::FIVE)) inventory::cursor_index = 4;
	if (raylib::is_key_pressed(raylib::keyboard::SIX)) inventory::cursor_index = 5;
	if (raylib::is_key_pressed(raylib::keyboard::SEVEN)) inventory::cursor_index = 6;
	if (raylib::is_key_pressed(raylib::keyboard::EIGHT)) inventory::cursor_index = 7;
	if (raylib::is_key_pressed(raylib::keyboard::NINE)) inventory::cursor_index = 8;
	if (raylib::is_key_pressed(raylib::keyboard::ZERO)) inventory::cursor_index = 9;

	if (raylib::is_key_pressed(raylib::keyboard::E)) inventory::inventory_open = !inventory::inventory_open;
	
	double time = raylib::get_time();
	foreach (bomb : bombs) {
		double normalized_age = (time - bomb.birthtime);
		raylib::draw_texture_ex(
			bomb_tex,
			bomb.position,
			0.0,
			1.0 + (float)normalized_age,
			raylib::RED,
			//raylib::color_brightness(raylib::RED, (float)normalized_age),
		);

		if (normalized_age < 1.0) continue;
		bombs.remove_first();

		for (int x = -8; x < 8; x++) {
			for (int y = -8; y < 8; y++) {
				if ((x * x) + (y * y) > (8 * 8)) continue;

				int target_x = (int)(bomb.position.x / 32) + x;
				int target_y = (int)(bomb.position.y / 32) + y;
				harvest_tile(target_x, target_y);
			}
		}
	}
}

fn void spawn_bomb(raylib::Vector2 stupid_hehehe) {
	bombs.push(Bomb { raylib::get_time(), stupid_hehehe });
}

fn void player_physics() {
    // FIXME: plrsssdsasserreeee fix meeee opelassderi love jamieei love jamie hehehehehehe
    player.velocity.x = 0;
	if (raylib::is_key_down(raylib::keyboard::D)) player.velocity.x = 5.0;
	if (raylib::is_key_down(raylib::keyboard::A)) player.velocity.x = -5.0;

	player.velocity.y = (float)$$min(9.8, player.velocity.y + 0.31);
	if (player.on_ground && raylib::is_key_down(raylib::keyboard::SPACE)) player.velocity.y -= 12.0;
    player.on_ground = false;

	raylib::Vector2 future_pos = player.position;
	future_pos.y += player.velocity.y;
	future_pos.x += player.velocity.x;

	List(<raylib::Vector2>) colliding_tiles = get_maybe_colliding_tiles(future_pos);
	foreach (tile : colliding_tiles) {

		if (!chunks::get_tile((int)(tile.x), (int)(tile.y))) continue;
		// raylib::draw_rectangle((int)tile.x * chunks::TILE_SIZE, (int)tile.y * chunks::TILE_SIZE, chunks::TILE_SIZE, chunks::TILE_SIZE, raylib::GREEN);

        raylib::Vector2 t_wpos = { tile.x * chunks::TILE_SIZE, tile.y * chunks::TILE_SIZE };

		// Check if actually colliding
        if (t_wpos.x + chunks::TILE_SIZE < future_pos.x) continue;
        if (t_wpos.x > future_pos.x + player.size.x) continue;
        if (t_wpos.y + chunks::TILE_SIZE < future_pos.y) continue;
        if (t_wpos.y > future_pos.y + player.size.y) continue;

		bool sitting_collision = t_wpos.y + chunks::TILE_SIZE > future_pos.y + player.size.y;
		// raylib::draw_rectangle((int)tile.x * chunks::TILE_SIZE, (int)tile.y * chunks::TILE_SIZE, chunks::TILE_SIZE, chunks::TILE_SIZE, ceiling_collision ? raylib::PINK : raylib::GOLD);

		if (!sitting_collision) player.velocity.x = 0;
		player.velocity.y = 0;
        player.on_ground = true;
        //break;
    }
	colliding_tiles.free();

	player.position.x += player.velocity.x;
	player.position.y += player.velocity.y;
}

fn List(<raylib::Vector2>) get_maybe_colliding_tiles(raylib::Vector2 pos) {
	List(<raylib::Vector2>) colliding_tiles;
    colliding_tiles.new_init();

	for (int x = (int)$$floor(pos.x / chunks::TILE_SIZE) - 1; x < (int)$$ceil((pos.x + player.size.x) / chunks::TILE_SIZE) + 1; x++) {
		for (int y = (int)$$floor(pos.y / chunks::TILE_SIZE) - 1; y < (int)$$ceil((pos.y + player.size.y) / chunks::TILE_SIZE) + 1; y++) {
			colliding_tiles.push(raylib::Vector2 { x, y });
		}
	}

	return colliding_tiles;
}

fn void render_ui() {
	raylib::draw_text(
		string::tformat_zstr(
			"Player: (%f, %f)",
			player.position.x,
			player.position.y
		),
		0,
		0,
		24,
		raylib::BLACK
	);

	inventory::render_inventory();
	chat::render();
}

fn void sig_ignore() {
    for (int i = 0; i < 17; i++) {
        io::printn("Do not do that!");
    }
    sigint_hit = true;
}

fn bool window_should_close() {
    return sigint_hit || raylib::window_should_close();
}

fn int main(String[] args) {
    io::printn("Early init...");

    raylib::set_trace_log_level(raylib::TraceLogLevel.WARNING);
    libc::signal(libc::SIGINT, (SignalFunction)&sig_ignore);

	bombs.new_init();
	//chunks.new_init();

    io::printn("Loading chunks...");

    chunks::load_chunks();

	camera = {
		raylib::Vector2 { 0, 0 },
		raylib::Vector2 { 0, 0 },
		0.0,
		1.0
	};

	// FLAG_WINDOW_RESIZABLE
	raylib::set_config_flags(0x00000004);
	raylib::init_window(800, 800, "HELLO");
	raylib::set_target_fps(60);

    io::printn("Loading textures...");
	bomb_tex = raylib::load_texture("resources/bomb.png");
	ants_tex = raylib::load_texture("resources/ants.png");

	tiles::register();

	for (ushort i = 0; i < inventory::item_list.len(); i++) {
		inventory::add_item(i, 99);
	}

    io::printn("Go time!");

	//UIGridContainer* grid = uig::new(<UIGridContainer>)();
	//for (int i = 0; i < 24; i++) {
	//	UIBox* y = uig::new(<UIBox>)(grid);
	//}

	while (!window_should_close()) {
		raylib::begin_drawing();

		raylib::clear_background(raylib::DARKBLUE);

		camera.zoom += raylib::get_mouse_wheel_move_v().y / 10.0;
		camera.zoom = $$max(0.01f, camera.zoom);

		camera.target = player.position;
		camera.target.x -= ((float)raylib::get_screen_width() / camera.zoom) / 2;
		camera.target.y -= ((float)raylib::get_screen_height() / camera.zoom) / 2;

    	raylib::begin_mode2d(camera);
			chunks::render_chunks();
			raylib::draw_rectangle_v(player.position, player.size, raylib::RED);

			Vector2i tpos = get_mouse_tpos();
			raylib::draw_texture_ex(
				ants_tex,
				raylib::Vector2 {
					(float)(tpos.x * chunks::TILE_SIZE),
					(float)(tpos.y * chunks::TILE_SIZE),
				},
				0.0,
				2.0,
				raylib::WHITE
			);

			logic();
		raylib::end_mode2d();

		// ui::render();
        render_ui();

		
		raylib::end_drawing();
	}

    chunks::save_chunks();

    io::printn("Goodbye!");
	raylib::close_window();
	return 0;
}
