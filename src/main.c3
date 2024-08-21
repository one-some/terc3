module terc3;
import std::io;
import raylib;
import std::collections::list;

struct Player {
	raylib::Vector2 position;
	raylib::Vector2 size;
	raylib::Vector2 velocity;
}

const TILE_SIZE = 32;

Player player = {
	raylib::Vector2 { 10, 0 },
	raylib::Vector2 { 32, 64 },
	raylib::Vector2 { 0, 0 },
};

fn void player_physics() {
	if (raylib::is_key_down(raylib::keyboard::D)) player.position.x += 5.0;
	if (raylib::is_key_down(raylib::keyboard::A)) player.position.x -= 5.0;

	player.velocity.y = (float)$$min(9.8, player.velocity.y + 0.31);
    bool on_ground = false;

	List(<raylib::Vector2>) tiles = get_maybe_colliding_tiles();
	foreach (tile : tiles) {
		//raylib::draw_rectangle((int)tile.x * TILE_SIZE, (int)tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, raylib::GREEN);

		if (!get_tile((int)tile.x, (int)tile.y)) continue;
		player.velocity.y = 0;
        on_ground = true;
    }
	tiles.free();

	if (on_ground && raylib::is_key_down(raylib::keyboard::SPACE)) player.velocity.y -= 12.0;

	player.position.y += player.velocity.y;
}

raylib::Texture2D[10] tiles;

fn List(<raylib::Vector2>) get_maybe_colliding_tiles() {
	List(<raylib::Vector2>) tiles;
    tiles.new_init();

	for (int x = (int)$$floor(player.position.x / TILE_SIZE); x < (int)$$ceil((player.position.x + player.size.x) / TILE_SIZE); x++) {
		for (int y = (int)$$floor(player.position.y / TILE_SIZE); y < (int)$$ceil((player.position.y + player.size.y) / TILE_SIZE); y++) {
			tiles.push(raylib::Vector2 { x, y });
		}
	}

	return tiles;
}

fn uint get_tile(int x, int y) {
	if (y == 11) return 2;
	if (y > 10) return 1;
	return 0;
}

fn void render_tiles() {
	for (int x = -128; x < 128; x++) {
		for (int y = -128; y < 128; y++) {
			uint tile = get_tile(x, y);
			if (!tile) continue;

			raylib::draw_texture_ex(
				tiles[tile - 1],
				raylib::Vector2 {
					(float) x * TILE_SIZE,
					(float) y * TILE_SIZE,
				},
				0.0,
				2.0,
				raylib::WHITE
			);
		}
	}
}

fn int main(String[] args)
{
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
		player_physics();
		raylib::end_mode2d();
		
		raylib::end_drawing();
	}

	raylib::close_window();
	return 0;
}
