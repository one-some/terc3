module terc3;
import std::io;
import raylib;
import std::collections::list;
import std::collections::map;

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
	ushort[128*128] tiles;
}

const TILE_SIZE = 32;

Player player = {
	raylib::Vector2 { 10, 0 },
	raylib::Vector2 { 32, 64 },
	raylib::Vector2 { 0, 0 },
};

List(<Bomb>) bombs;
HashMap(<String, Chunk*>) chunks;

raylib::Texture2D bomb_tex;
raylib::Texture2D[10] tiles;

fn void logic() {
	player_physics();
	
	double time = raylib::get_time();
	foreach (bomb : bombs) {
		raylib::draw_texture_ex(
			bomb_tex,
			bomb.position,
			0.0,
			1.0,
			raylib::WHITE
		);

		if ((time - bomb.birthtime) < 1.0) continue;
		bombs.remove_first();

		for (int x = -8; x < 8; x++) {
			for (int y = -8; y < 8; y++) {
				if ((x * x) + (y * y) > (8 * 8)) continue;
				// TODO: CLEAR
				set_tile(
					(int)(bomb.position.x / 32) + x,
					(int)(bomb.position.y / 32) + y,
					0
				);
			}
		}

	}
}

fn void spawn_bomb(raylib::Vector2 stupid_hehehe) {
	bombs.push(Bomb { raylib::get_time(), stupid_hehehe });
}

fn void player_physics() {
    // FIXME: W
    player.velocity.x = 0;
	if (raylib::is_key_down(raylib::keyboard::D)) player.velocity.x = 5.0;
	if (raylib::is_key_down(raylib::keyboard::A)) player.velocity.x = -5.0;

	player.velocity.y = (float)$$min(9.8, player.velocity.y + 0.31);
    bool on_ground = false;

	raylib::Vector2 future_pos = player.position;
	future_pos.y += player.velocity.y;
	future_pos.x += player.velocity.x;

	List(<raylib::Vector2>) tiles = get_maybe_colliding_tiles(future_pos);
	foreach (tile : tiles) {
		//raylib::draw_rectangle((int)tile.x * TILE_SIZE, (int)tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, raylib::GREEN);

		if (!get_tile((int)(tile.x), (int)(tile.y))) continue;
        raylib::Vector2 t_wpos = { tile.x * TILE_SIZE, tile.y * TILE_SIZE };

        if (t_wpos.x + TILE_SIZE < future_pos.x) continue;
        if (t_wpos.x > future_pos.x + player.size.x) continue;

        if (t_wpos.y + TILE_SIZE < future_pos.y) continue;
        if (t_wpos.y > future_pos.y + player.size.y) continue;

		player.velocity.x = 0;
		player.velocity.y = 0;
        on_ground = true;
        break;
    }
	tiles.free();

	if (on_ground && raylib::is_key_down(raylib::keyboard::SPACE)) player.velocity.y -= 12.0;

	player.position.x += player.velocity.x;
	player.position.y += player.velocity.y;

	if (raylib::is_mouse_button_pressed(raylib::MouseButton.BUTTON_LEFT)) {
		io::printn("CLIOCK");
		spawn_bomb(player.position);
	}
}

fn List(<raylib::Vector2>) get_maybe_colliding_tiles(raylib::Vector2 pos) {
	List(<raylib::Vector2>) tiles;
    tiles.new_init();

	for (int x = (int)$$floor(pos.x / TILE_SIZE) - 1; x < (int)$$ceil((pos.x + player.size.x) / TILE_SIZE) + 1; x++) {
		for (int y = (int)$$floor(pos.y / TILE_SIZE) - 1; y < (int)$$ceil((pos.y + player.size.y) / TILE_SIZE) + 1; y++) {
			tiles.push(raylib::Vector2 { x, y });
		}
	}

	return tiles;
}

fn Chunk* chunk_for_tile(int x, int y) {
	int chunk_x = (int)$$floor(x / 128.0);
	int chunk_y = (int)$$floor(y / 128.0);

	Chunk* target_chunk = null;

	// Yes this sux but idk a better way atm.................!
	String chunk_key = std::core::string::tformat("%d,%d", chunk_x, chunk_y);
	io::printf("%d, %d\n", x, chunk_x);

	if (try maybe_chunk = chunks.get(chunk_key)) {
		return maybe_chunk;
	}

	io::printf("Gotta make chunk %d, %d\n", chunk_x, chunk_y);

	Chunk* new_chunk = mem::new(Chunk);
	*new_chunk = gen_chunk(chunk_x, chunk_y);
	chunks.set(chunk_key, new_chunk);

	return new_chunk;
}

fn ushort get_tile(int x, int y) {
	Chunk* target_chunk = chunk_for_tile(x, y);

	return target_chunk.tiles[
		$$abs(x % 128)
		+ ($$abs(y % 128) * 128)
	];
}

fn void set_tile(int x, int y, ushort tile) {
	Chunk* target_chunk = chunk_for_tile(x, y);

	target_chunk.tiles[
		$$abs(x % 128)
		+ ($$abs(y % 128) * 128)
	] = tile;
}

fn Chunk gen_chunk(int chunk_x, int chunk_y) {
	io::printf("Generating %d %d\n", chunk_x, chunk_y);

	int base_x = chunk_x * 128;
	int base_y = chunk_y * 128;

	ushort[128*128] tiles;

	for (int x = 0; x < 128; x++) {
		for (int y = 0; y < 128; y++) {
			tiles[x + (y * 128)] = gen_tile(base_x + x, base_y + y);
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
	// yy *= $$sin(dx / 10.0);

	int yi = (int)$$round(yy);

	if (y == yi) return 2;
	if (y > yi) return 1;
	return 0;
}

fn void render_tiles() {
	foreach (chunk : chunks.value_tlist()) {
		for (int x = 0; x < 128; x++) {
			for (int y = 0; y < 128; y++) {
				uint tile = chunk.tiles[x + (128 * y)];
				if (!tile) continue;

				raylib::draw_texture_ex(
					tiles[tile - 1],
					raylib::Vector2 {
						(float) ((chunk.position.x * 128) + x) * TILE_SIZE,
						(float) ((chunk.position.y * 128) + y) * TILE_SIZE,
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

	raylib::Camera2D camera = {
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
	tiles[0] = raylib::load_texture("resources/dirt.png");
	tiles[1] = raylib::load_texture("resources/grass.png");

	while (!raylib::window_should_close()) {
		raylib::begin_drawing();

		raylib::clear_background(raylib::DARKBLUE);

		camera.target = player.position;
		camera.target.x -= ((float)raylib::get_screen_width()) / 2;
		camera.target.y -= ((float)raylib::get_screen_height()) / 2;

    	raylib::begin_mode2d(camera);
			render_tiles();
			raylib::draw_rectangle_v(player.position, player.size, raylib::RED);
		
		logic();
		raylib::end_mode2d();

        raylib::draw_text(
            string::tformat(
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
