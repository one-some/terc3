module terc3;
import std::io;
import raylib;
import std::collections::list;
import std::collections::map;
import libc;

const TILE_SIZE = 32;
const CHUNK_SIZE = 32;
const INVENTORY_ITEM_SIZE = 48;

struct Player {
	raylib::Vector2 position;
	raylib::Vector2 size;
	raylib::Vector2 velocity;
	bool on_ground;
}

struct Vector2i {
	int x;
	int y;
}

fn bool Vector2i.eq(&self, Vector2i that) {
    return self.x == that.x && self.y == that.y;
}

fn Vector2i Vector2i.plus(&self, int x, int y) {
    return {
        self.x + x,
        self.y + y,
    };
}

struct Bomb {
	double birthtime;
	raylib::Vector2 position;
}

struct Chunk {
	Vector2i position;
	ushort[CHUNK_SIZE*CHUNK_SIZE] tiles;
	ushort[CHUNK_SIZE*CHUNK_SIZE] bg_tiles;
    bool fg_modified;
    bool bg_modified;
}

struct Tile {
	String name;
	raylib::Texture2D texture;
}

struct InventorySlot {
    ItemID item;
    int count;
}

InventorySlot[50] inventory;

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

def ItemID = ushort;

List(<Bomb>) bombs;
List(<Tile>) tile_list;
HashMap(<String, Chunk*>) chunks;
usz cursor_index = 1;
bool sigint_hit = false;
bool inventory_open = false;

raylib::Camera2D camera;
raylib::Texture2D ants_tex;
raylib::Texture2D bomb_tex;

fn void add_item(ItemID id, int delta) {
    foreach (i, slot : inventory) {
        if (slot.item != id) continue;
        inventory[i].count += delta;

        // Clear item if decrementing all of 'em
        if (inventory[i].count <= 0) {
            inventory[i] = {0, 0};
        }

        return;
    }

    foreach (i, slot : inventory) {
        if (slot.item) continue;
        inventory[i] = { id, delta };
        return;
    }

    io::printn("Out of inventory space!!!!!");
}

fn bool has_item(ItemID id) {
    foreach (i, slot : inventory) {
        if (slot.item != id) continue;
        return true;
    }
    return false;
}

fn void harvest_tile(int x, int y) {
	ItemID tile_id = get_tile(x, y);
	if (!tile_id) return;
	add_item(tile_id, 1);
	set_tile(x, y, 0);
}

fn Vector2i get_mouse_tpos() {
	return Vector2i {
		(int)($$floor(((raylib::get_mouse_x() / camera.zoom) + camera.target.x) / TILE_SIZE)),
		(int)($$floor(((raylib::get_mouse_y() / camera.zoom) + camera.target.y) / TILE_SIZE)),
	};
}

fn void place(bool break_tile) {
	Vector2i tile_pos = get_mouse_tpos();

	if (break_tile) {
		harvest_tile(tile_pos.x, tile_pos.y);
		return;
	}

    ItemID item_id = inventory[cursor_index].item;

	// Don't place air!
	if (!item_id) return;
	if (!has_item(item_id)) return;

	ItemID tile_id = get_tile(tile_pos.x, tile_pos.y);
	if (tile_id) return;

	add_item(item_id, -1);
	set_tile(tile_pos.x, tile_pos.y, item_id);
}

fn bool air_adjacent(Vector2i pos) {
    // NOTE: Returns FALSE if tile is actually air

    if (get_tile(pos.x, pos.y) == 0) return false;

    for (int x_off = -1; x_off <= 1; x_off++) {
        for (int y_off = -1; y_off <= 1; y_off++) {
            if (get_tile(pos.x + x_off, pos.y + y_off) == 0) return true;
        }
    }

    return false;
}

fn double mine_time(ItemID tile) {
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

    double time_needed = mine_time(get_tile(tile_pos.x, tile_pos.y));

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

	if (raylib::is_key_pressed(raylib::keyboard::ONE)) cursor_index = 0;
	if (raylib::is_key_pressed(raylib::keyboard::TWO)) cursor_index = 1;
	if (raylib::is_key_pressed(raylib::keyboard::THREE)) cursor_index = 2;
	if (raylib::is_key_pressed(raylib::keyboard::FOUR)) cursor_index = 3;
	if (raylib::is_key_pressed(raylib::keyboard::FIVE)) cursor_index = 4;
	if (raylib::is_key_pressed(raylib::keyboard::SIX)) cursor_index = 5;
	if (raylib::is_key_pressed(raylib::keyboard::SEVEN)) cursor_index = 6;
	if (raylib::is_key_pressed(raylib::keyboard::EIGHT)) cursor_index = 7;
	if (raylib::is_key_pressed(raylib::keyboard::NINE)) cursor_index = 8;
	if (raylib::is_key_pressed(raylib::keyboard::ZERO)) cursor_index = 9;
	
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

		if (!get_tile((int)(tile.x), (int)(tile.y))) continue;
		// raylib::draw_rectangle((int)tile.x * TILE_SIZE, (int)tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, raylib::GREEN);

        raylib::Vector2 t_wpos = { tile.x * TILE_SIZE, tile.y * TILE_SIZE };

		// Check if actually colliding
        if (t_wpos.x + TILE_SIZE < future_pos.x) continue;
        if (t_wpos.x > future_pos.x + player.size.x) continue;
        if (t_wpos.y + TILE_SIZE < future_pos.y) continue;
        if (t_wpos.y > future_pos.y + player.size.y) continue;

		bool sitting_collision = t_wpos.y + TILE_SIZE > future_pos.y + player.size.y;
		// raylib::draw_rectangle((int)tile.x * TILE_SIZE, (int)tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, ceiling_collision ? raylib::PINK : raylib::GOLD);

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

fn ItemID get_tile(int x, int y) {
	Chunk* target_chunk = chunk_for_tile(x, y);
	return target_chunk.tiles[tile_index(x, y)];
}

fn void set_tile(int x, int y, ItemID tile) {
	Chunk* target_chunk = chunk_for_tile(x, y);

	target_chunk.tiles[tile_index(x, y)] = tile;
    target_chunk.fg_modified = true;
}

fn void save_chunks() {
	foreach (chunk : chunks.value_tlist()) {
        if (chunk.fg_modified) save_chunk(chunk, false);
        if (chunk.bg_modified) save_chunk(chunk, true);
    }
}

fn void save_chunk(Chunk* chunk, bool bg) {
    String path = std::core::string::tformat(
        bg ? "world/BG%d,%d" : "world/FG%d,%d",
        chunk.position.x,
        chunk.position.y
    );

    // Clean for filesystem (just in case....)
    foreach (i, c : path) {
        if (c == ',') path[i] = '_';
    }

    io::printn(path);

    File! file = io::file::open(path, "wb");
    if (catch file) unreachable("Terrible things are happening on the filesystem");

    char[CHUNK_SIZE*CHUNK_SIZE*2] tile_buf;
    foreach (i, tile : (bg ? chunk.bg_tiles : chunk.tiles)) {
        tile_buf[i * 2] = (char)(tile >> 8);
        tile_buf[(i * 2) + 1] = (char)(tile & 0xFF);
    }

    file.write(&tile_buf)!!;
    file.close()!!;
}

fn void load_chunks() {
    io::path::Path! path = io::path::new_cwd().new_append("world")!!;

    foreach (file_path : io::path::new_ls(path)!!) {
        // Im sure theres a better way to do this
        char[] data = io::file::load_new(
            io::path::new(path.path_string).new_append(file_path.path_string).path_string
        )!!;

        String[] s_coords = file_path.path_string[2..].split("_");
        Vector2i chunk_pos = { s_coords[0].to_int()!!, s_coords[1].to_int()!! };
        String chunk_key = std::core::string::tformat("%d,%d", chunk_pos.x, chunk_pos.y);

        ushort[CHUNK_SIZE*CHUNK_SIZE] tile_buf;
        for (int i = 0; i < tile_buf.len; i++) {
            tile_buf[i] = (data[i * 2] << 8) | (data[(i * 2) + 1] & 0xFF);
        }

        bool is_bg = file_path.path_string[0..2] == "BG";

        Chunk* chunk;
        bool chunk_existing = false;

        if (try maybe_chunk = chunks.get(chunk_key)) {
            chunk = maybe_chunk;
            chunk_existing = true;
        } else {
            chunk = mem::new(Chunk);
            chunk.position = chunk_pos;
        }

        if (is_bg) {
            chunk.bg_tiles = tile_buf;
            chunk.bg_modified = true;
        } else {
            chunk.tiles = tile_buf;
            chunk.fg_modified = true;
        }

        if (!chunk_existing) chunks.set(chunk_key, chunk);
    }
}

fn Chunk gen_chunk(int chunk_x, int chunk_y) {
	io::printf("Generating %d %d\n", chunk_x, chunk_y);

	int base_x = chunk_x * CHUNK_SIZE;
	int base_y = chunk_y * CHUNK_SIZE;

	ushort[CHUNK_SIZE * CHUNK_SIZE] tiles;
	ushort[CHUNK_SIZE * CHUNK_SIZE] bg_tiles;

	for (int x = 0; x < CHUNK_SIZE; x++) {
		for (int y = 0; y < CHUNK_SIZE; y++) {
            int index = x + (y * CHUNK_SIZE);
            ushort tile_id = gen_tile(base_x + x, base_y + y); 
			tiles[index] = tile_id;
            bg_tiles[index] = gen_bg_tile(base_x + x, base_y + y, tile_id);
		}
	}

	return Chunk {
		{ chunk_x, chunk_y },
		tiles,
        bg_tiles,
        false,
        false,
	};
}

fn ushort gen_bg_tile(int x, int y, ushort tile) {
    if (tile == 7) return 3;
    return tile;
}

fn ushort gen_tile(int x, int y) {
	double dx = x;
	double yy = ($$sin(dx / 5.0) + 1.0) * 6.0;
	yy *= $$sin(dx / 10.0);

	int yi = (int)$$round(yy);

	int rock_level = yi + 12 + (int)($$cos(dx / 40.0) * 9.0);

	if (y > rock_level) {
        int rand_level = $$min(50, y);
        if (raylib::get_random_value(0, rand_level) == 0) return 7;
        return 3;
    }


	if (y > yi) return 1;
	if (y == yi) return 2;

	return 0;
}

fn void render_tiles() {
	foreach (chunk : chunks.value_tlist()) {
		for (int x = 0; x < CHUNK_SIZE; x++) {
			for (int y = 0; y < CHUNK_SIZE; y++) {
				int index = x + (CHUNK_SIZE * y);
                Vector2i tile_pos = {
                    (chunk.position.x * CHUNK_SIZE) + x,
                    (chunk.position.y * CHUNK_SIZE) + y,
                };

                raylib::Vector2 draw_pos = raylib::Vector2 {
                    (float)tile_pos.x * TILE_SIZE,
                    (float)tile_pos.y * TILE_SIZE,
                };

				uint bg_tile = chunk.bg_tiles[index];
				if (bg_tile) {
                    raylib::draw_texture_ex(
                        tile_list[bg_tile].texture,
                        draw_pos,
                        0.0,
                        2.0,
                        raylib::GRAY
                    );
                }

				uint tile = chunk.tiles[index];
				if (tile) {
                    raylib::draw_texture_ex(
                        tile_list[tile].texture,
                        draw_pos,
                        0.0,
                        2.0,
                        raylib::WHITE
                    );
                }

                if (mine_progress.start_time && tile_pos.eq(mine_progress.position)) {
                    raylib::draw_rectangle_v(
                        {
                            (float)(tile_pos.x * TILE_SIZE),
                            (float)(tile_pos.y * TILE_SIZE),
                        },
                        {32, 32},
                        raylib::fade(raylib::WHITE, (float)mine_progress.progress / 3),
                    );
                }
			}
		}
	}
}

fn void InventorySlot.render(&self, raylib::Vector2 pos, bool highlighted) {
    raylib::draw_rectangle_v(
        pos,
        {INVENTORY_ITEM_SIZE, INVENTORY_ITEM_SIZE},
        highlighted ? raylib::RED : raylib::BLACK,
    );

    if (!self.item) return;

    raylib::draw_texture_ex(
        tile_list[self.item].texture,
        pos,
        0.0,
        (float)INVENTORY_ITEM_SIZE / 16.0f,
        raylib::WHITE
    );

    raylib::draw_text(
        string::tformat_zstr("%d", self.count),
        ((int)pos.x) + INVENTORY_ITEM_SIZE - 26,
        (int)pos.y,
        24,
        highlighted ? raylib::RED : raylib::BLACK,
    );
}

fn void render_ui() {
    int screen_width = raylib::get_screen_width();
    int screen_height = raylib::get_screen_height();

    const MARGIN = 4;
    const HOTBAR_WIDTH = (INVENTORY_ITEM_SIZE + MARGIN) * 10;
    int hotbar_start = (screen_width - HOTBAR_WIDTH) / 2;

    for (int i = 9; i >= 0; i--) {
        raylib::Vector2 pos = {
            (float)(hotbar_start + ((INVENTORY_ITEM_SIZE + MARGIN) * i)),
            (float)(screen_height - INVENTORY_ITEM_SIZE),
        };

        inventory[i].render(pos, i == cursor_index);
    }

    if (!inventory_open) return;

    foreach (int i, slot : inventory[10..]) {
        Vector2i item_pos = { i % 10, 4 - (i / 10) };

        raylib::Vector2 pos = {
            (float)(hotbar_start + ((INVENTORY_ITEM_SIZE + MARGIN) * item_pos.x)),
            (float)((screen_height / 2) - ((INVENTORY_ITEM_SIZE + MARGIN) * (item_pos.y - 2))),
        };

        raylib::draw_rectangle_v(
            pos,
            {INVENTORY_ITEM_SIZE, INVENTORY_ITEM_SIZE},
            i == 0 ? raylib::RED : raylib::BLACK,
        );
    }
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

	tile_list.new_init();
	bombs.new_init();
	chunks.new_init();

    io::printn("Loading chunks...");

    load_chunks();

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

	tile_list.push(Tile { "Air", raylib::load_texture("resources/hi.png") });
	tile_list.push(Tile { "Dirt", raylib::load_texture("resources/dirt.png") });
	tile_list.push(Tile { "Grass", raylib::load_texture("resources/grass.png") });
	tile_list.push(Tile { "Stone", raylib::load_texture("resources/stone.png") });
	tile_list.push(Tile { "Stone Brick", raylib::load_texture("resources/stone_brick.png") });
	tile_list.push(Tile { "Log", raylib::load_texture("resources/log.png") });
	tile_list.push(Tile { "Leaves", raylib::load_texture("resources/leaves.png") });
	tile_list.push(Tile { "Iron Ore", raylib::load_texture("resources/iron.png") });

	for (ushort i = 0; i < tile_list.len(); i++) {
        inventory[i] = { i + 1, 99 };
	}

    io::printn("Go time!");

	while (!window_should_close()) {
		raylib::begin_drawing();

		raylib::clear_background(raylib::DARKBLUE);

		camera.zoom += raylib::get_mouse_wheel_move_v().y / 10.0;
		camera.zoom = $$max(0.01f, camera.zoom);

		camera.target = player.position;
		camera.target.x -= ((float)raylib::get_screen_width() / camera.zoom) / 2;
		camera.target.y -= ((float)raylib::get_screen_height() / camera.zoom) / 2;

    	raylib::begin_mode2d(camera);
			render_tiles();
			raylib::draw_rectangle_v(player.position, player.size, raylib::RED);

			Vector2i tpos = get_mouse_tpos();
			raylib::draw_texture_ex(
				ants_tex,
				raylib::Vector2 {
					(float)(tpos.x * TILE_SIZE),
					(float)(tpos.y * TILE_SIZE),
				},
				0.0,
				2.0,
				raylib::WHITE
			);

			logic();
		raylib::end_mode2d();

        render_ui();

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

    save_chunks();

    io::printn("Goodbye!");
	raylib::close_window();
	return 0;
}
