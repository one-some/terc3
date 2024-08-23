module terc3;
import std::io;
import raylib;
import std::collections::list;
import std::collections::map;

const TILE_SIZE = 32;
const CHUNK_SIZE = 128;

struct Player {
	raylib::Vector2 position;
	raylib::Vector2 size;
	raylib::Vector2 velocity;
}

struct Bomb {
	double birthtime;
	raylib::Vector2 position;
}

struct Chunk {
	raylib::Vector2 position;
	ushort[CHUNK_SIZE*CHUNK_SIZE] tiles;
}

struct Tile {
	String name;
	raylib::Texture2D texture;
}

Player player = {
	raylib::Vector2 { 10, 0 },
	raylib::Vector2 { 28, 64 },
	raylib::Vector2 { 0, 0 },
};

List(<Bomb>) bombs;
HashMap(<String, Chunk*>) chunks;
HashMap(<usz, int>) item_counts;
usz item_index = 0;

raylib::Camera2D camera;
raylib::Texture2D ants_tex;
raylib::Texture2D bomb_tex;
Tile[10] tile_list;

fn void add_item(usz id, int delta) {
	int! count = item_counts.get(id);
	
	if (try count) {
		item_counts.set(id, $$max(0, count + delta));
	} else {
		item_counts.set(id, $$max(0, delta));
	}
}

fn void harvest_tile(int x, int y) {
	usz tile_id = get_tile(x, y);
	if (!tile_id) return;
	add_item(tile_id, 1);
	set_tile(x, y, 0);
}

fn void place(bool break_tile) {
	float global_mouse_x = raylib::get_mouse_x() + camera.target.x;
	float global_mouse_y = raylib::get_mouse_y() + camera.target.y;

	int tile_x = (int)($$floor(global_mouse_x / TILE_SIZE));
	int tile_y = (int)($$floor(global_mouse_y / TILE_SIZE));

	if (break_tile) {
		harvest_tile(tile_x, tile_y);
		return;
	}

	usz tile_id = get_tile(tile_x, tile_y);
	if (tile_id) return;
	add_item(1, -1);
	set_tile(tile_x, tile_y, 1);
}

fn void logic() {
	player_physics();
	
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
    bool on_ground = false;

	raylib::Vector2 future_pos = player.position;
	future_pos.y += player.velocity.y;
	future_pos.x += player.velocity.x;

	List(<raylib::Vector2>) colliding_tiles = get_maybe_colliding_tiles(future_pos);
	foreach (tile : colliding_tiles) {

		if (!get_tile((int)(tile.x), (int)(tile.y))) continue;
		// raylib::draw_rectangle((int)tile.x * TILE_SIZE, (int)tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, raylib::GREEN);

        raylib::Vector2 t_wpos = { tile.x * TILE_SIZE, tile.y * TILE_SIZE };

		// Check if actually colliding
        if (t_wpos.x + TILE_SIZE < future_pos.x) continue;
        if (t_wpos.x > future_pos.x + player.size.x) continue;
        if (t_wpos.y + TILE_SIZE < future_pos.y) continue;
        if (t_wpos.y > future_pos.y + player.size.y) continue;

		bool sitting_collision = t_wpos.y + TILE_SIZE > future_pos.y + player.size.y;
		//(t_wpos.x < future_pos.x + player.size.x) || (t_wpos.x + TILE_SIZE > future_pos.x);

		//raylib::draw_rectangle((int)tile.x * TILE_SIZE, (int)tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, sitting_collision ? raylib::BLUE : raylib::GOLD);

		if (!sitting_collision) player.velocity.x = 0;
		player.velocity.y = 0;
        on_ground = true;
        //break;
    }
	colliding_tiles.free();

	if (on_ground && raylib::is_key_down(raylib::keyboard::SPACE)) player.velocity.y -= 12.0;

	player.position.x += player.velocity.x;
	player.position.y += player.velocity.y;

	if (raylib::is_mouse_button_down(raylib::MouseButton.BUTTON_LEFT)) {
		place(true);
	}

	if (raylib::is_mouse_button_down(raylib::MouseButton.BUTTON_RIGHT)) {
		place(false);
	}

	if (raylib::is_key_pressed(raylib::keyboard::B)) {
		spawn_bomb(player.position);
	}
}

fn List(<raylib::Vector2>) get_maybe_colliding_tiles(raylib::Vector2 pos) {
	List(<raylib::Vector2>) colliding_tiles;
    colliding_tiles.new_init();

	for (int x = (int)$$floor(pos.x / TILE_SIZE) - 1; x < (int)$$ceil((pos.x + player.size.x) / TILE_SIZE) + 1; x++) {
		for (int y = (int)$$floor(pos.y / TILE_SIZE) - 1; y < (int)$$ceil((pos.y + player.size.y) / TILE_SIZE) + 1; y++) {
			colliding_tiles.push(raylib::Vector2 { x, y });
		}
	}

	return colliding_tiles;
}

fn Chunk* chunk_for_tile(int x, int y) {
	int chunk_x = (int)$$floor(x / (double)CHUNK_SIZE);
	int chunk_y = (int)$$floor(y / (double)CHUNK_SIZE);

	Chunk* target_chunk = null;

	// Yes this sux but idk a better way atm.................!
	String chunk_key = std::core::string::tformat("%d,%d", chunk_x, chunk_y);
	// io::printf("%d, %d\n", x, chunk_x);

	if (try maybe_chunk = chunks.get(chunk_key)) {
		return maybe_chunk;
	}

	io::printf("Gotta make chunk %d, %d\n", chunk_x, chunk_y);

	Chunk* new_chunk = mem::new(Chunk);
	*new_chunk = gen_chunk(chunk_x, chunk_y);
	chunks.set(chunk_key, new_chunk);

	return new_chunk;
}

fn usz tile_index(int x, int y) @inline {
	int local_x = x % CHUNK_SIZE;
	if (local_x < 0) local_x = CHUNK_SIZE + local_x;

	int local_y = y % CHUNK_SIZE;
	if (local_y < 0) local_y = CHUNK_SIZE + local_y;

	assert (local_x >= 0);
	assert (local_y >= 0);

	return (usz)(local_x + (local_y * CHUNK_SIZE));
}

fn ushort get_tile(int x, int y) {
	Chunk* target_chunk = chunk_for_tile(x, y);
	return target_chunk.tiles[tile_index(x, y)];
}

fn void set_tile(int x, int y, ushort tile) {
	Chunk* target_chunk = chunk_for_tile(x, y);

	target_chunk.tiles[tile_index(x, y)] = tile;
}

fn Chunk gen_chunk(int chunk_x, int chunk_y) {
	io::printf("Generating %d %d\n", chunk_x, chunk_y);

	int base_x = chunk_x * CHUNK_SIZE;
	int base_y = chunk_y * CHUNK_SIZE;

	ushort[CHUNK_SIZE * CHUNK_SIZE] tiles;

	for (int x = 0; x < CHUNK_SIZE; x++) {
		for (int y = 0; y < CHUNK_SIZE; y++) {
			tiles[x + (y * CHUNK_SIZE)] = gen_tile(base_x + x, base_y + y);
		}
	}

	return Chunk {
		raylib::Vector2 { chunk_x, chunk_y },
		tiles
	};
}

fn ushort gen_tile(int x, int y) {
	double dx = x;
	double yy = ($$sin(dx / 5.0) + 1.0) * 6.0;
	yy *= $$sin(dx / 10.0);

	int yi = (int)$$round(yy);

	if (y == yi) return 2;
	if (y > yi) return 1;
	return 0;
}

fn void render_tiles() {
	foreach (chunk : chunks.value_tlist()) {
		for (int x = 0; x < CHUNK_SIZE; x++) {
			for (int y = 0; y < CHUNK_SIZE; y++) {
				uint tile = chunk.tiles[x + (CHUNK_SIZE * y)];
				if (!tile) continue;

				raylib::draw_texture_ex(
					tile_list[tile - 1].texture,
					raylib::Vector2 {
						(float) ((chunk.position.x * CHUNK_SIZE) + x) * TILE_SIZE,
						(float) ((chunk.position.y * CHUNK_SIZE) + y) * TILE_SIZE,
					},
					0.0,
					2.0,
					raylib::WHITE
				);
			}
		}
	}
}

fn int main(String[] args) {
	bombs.new_init();
	chunks.new_init();
	item_counts.new_init();

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

	bomb_tex = raylib::load_texture("resources/bomb.png");
	ants_tex = raylib::load_texture("resources/ants.png");
	tile_list[0] = Tile { "Dirt", raylib::load_texture("resources/dirt.png") };
	tile_list[1] = Tile { "Grass", raylib::load_texture("resources/grass.png") };

	while (!raylib::window_should_close()) {
		raylib::begin_drawing();

		raylib::clear_background(raylib::DARKBLUE);

		camera.target = player.position;
		camera.target.x -= ((float)raylib::get_screen_width()) / 2;
		camera.target.y -= ((float)raylib::get_screen_height()) / 2;

    	raylib::begin_mode2d(camera);
			render_tiles();
			raylib::draw_rectangle_v(player.position, player.size, raylib::RED);

			float global_mouse_x = raylib::get_mouse_x() + camera.target.x;
			float global_mouse_y = raylib::get_mouse_y() + camera.target.y;

			raylib::draw_texture_ex(
				ants_tex,
				raylib::Vector2 {
					(float)($$floor(global_mouse_x / TILE_SIZE) * TILE_SIZE),
					(float)($$floor(global_mouse_y / TILE_SIZE) * TILE_SIZE),
				},
				0.0,
				2.0,
				raylib::WHITE
			);

			logic();
		raylib::end_mode2d();


		foreach (i, item_id : item_counts.key_tlist()) {
			if (!item_id) continue;

			Tile item = tile_list[item_id - 1];
			int! count = item_counts.get(item_id);

			if (catch count) {
				unreachable("Hello what the hell!");
			}

			float y_level = 46.0f * (i + 1.0f);

			raylib::draw_texture_ex(
				item.texture,
				raylib::Vector2 {
					0,
					y_level,
				},
				0.0,
				2.0,
				raylib::WHITE
			);

			raylib::draw_text(
				string::tformat_zstr(
					"%s: %d",
					item.name,
					count,
				),
				32,
				(int)y_level,
				24,
				raylib::BLACK
			);
		}

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
		
		raylib::end_drawing();
	}

	raylib::close_window();
	return 0;
}
