import raylib;
import std::collections::map;
import std::collections::list;
import std::io;

import tiles;
import inventory;
import terc3;
import vector2;

const TILE_SIZE = 32;
const CHUNK_SIZE = 32;
def ChunkData = ushort[CHUNK_SIZE * CHUNK_SIZE];
HashMap(<String, Chunk*>) chunks;

struct Chunk {
	Vector2i position;
    ChunkData* tiles;
    ChunkData* bg_tiles;
    bool fg_modified;
    bool bg_modified;
    ChunkData* light_map;
}

struct Light {
    Vector2i position;
    ushort intensity;
}

List(<Light>) lights;

double[] kernel = {
    1f/16f, 1f/8f, 1f/16f, 
    1f/8f,  1f/4f, 1f/8f, 
    1f/16f, 1f/8f, 1f/16f, 
};

fn void Chunk.update_light_map(&self) {
    if (!self.light_map) self.light_map = mem::new(ChunkData);
    // HOLY SHIT! O^876278312371263
    for (int x = 0; x < CHUNK_SIZE; x++) {
        for (int y = 0; y < CHUNK_SIZE; y++) {
            if (get_tile(
                x + (self.position.x * CHUNK_SIZE),
                y + (self.position.y * CHUNK_SIZE),
            )) continue;

            int index = x + (CHUNK_SIZE * y);
            (*self.light_map)[index] = 255;
        }
    }

    for (int threshold = 255; threshold > 0; threshold -= 255/8) {
        ChunkData last = *self.light_map;

        for (int x = 0; x < CHUNK_SIZE; x++) {
            for (int y = 0; y < CHUNK_SIZE; y++) {
                int our_index = x + (CHUNK_SIZE * y);
                bool done = false;

                for (int kx = -1; kx <= 1; kx++) {
                    for (int ky = -1; ky <= 1; ky++) {
                        int local_x = x + kx;
                        int local_y = y + ky;

                        // FIXME!
                        if (local_x < 0) continue;
                        if (local_y < 0) continue;
                        if (local_x >= CHUNK_SIZE) continue;
                        if (local_y >= CHUNK_SIZE) continue;

                        int index = local_x + (CHUNK_SIZE * local_y);

                        if (last[index] < threshold) continue;
                        if ((*self.light_map)[our_index] > threshold) continue;

                        (*self.light_map)[our_index] = (ushort)threshold;
                        done = true;
                        break;
                    }
                    if (done) break;
                }
            }
        }
    }
}

fn ushort gen_bg_tile(int x, int y, ushort tile) {
    if (tile == 7) return 3;
    return tile;
}

fn int get_ground_height(int x) {
	double dx = x;
	double yy = ($$sin(dx / 5.0) + 1.0) * 6.0;
	yy *= $$sin(dx / 10.0);

	return (int)$$round(yy);
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
	*new_chunk = gen_chunk({chunk_x, chunk_y});
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

fn ItemID get_tile(int x, int y, bool bg_tile = false) {
	Chunk* target_chunk = chunk_for_tile(x, y);
	if (bg_tile) return (*target_chunk.bg_tiles)[tile_index(x, y)];
	return (*target_chunk.tiles)[tile_index(x, y)];
}

fn void set_tile(int x, int y, ItemID tile, bool bg_tile = false) {
	Chunk* target_chunk = chunk_for_tile(x, y);

	if (bg_tile) {
        (*target_chunk.bg_tiles)[tile_index(x, y)] = tile;
        target_chunk.bg_modified = true;
        return;
    }
	(*target_chunk.tiles)[tile_index(x, y)] = tile;
    target_chunk.fg_modified = true;
}

fn void save_chunks() @finalizer {
	foreach (chunk : chunks.value_tlist()) {
        if (chunk.fg_modified) save_chunk(chunk, false);
        if (chunk.bg_modified) save_chunk(chunk, true);
    }

    io::printn("Goodbye!");
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
    lights.push({{0, 0}, 255});

    io::path::Path! path = io::path::new_cwd().new_append("world")!!;

    foreach (file_path : io::path::new_ls(path)!!) {
        // Im sure theres a better way to do this
        char[] data = io::file::load_new(
            io::path::new(path.path_string).new_append(file_path.path_string).path_string
        )!!;

        String[] s_coords = file_path.path_string[2..].split("_");
        Vector2i chunk_pos = { s_coords[0].to_int()!!, s_coords[1].to_int()!! };
        String chunk_key = std::core::string::tformat("%d,%d", chunk_pos.x, chunk_pos.y);

        ChunkData* tile_buf = mem::new(ChunkData);
        for (int i = 0; i < tile_buf.len; i++) {
            (*tile_buf)[i] = (data[i * 2] << 8) | (data[(i * 2) + 1] & 0xFF);
        }

        bool is_bg = file_path.path_string[0..1] == "BG";

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

	foreach (chunk : chunks.value_tlist()) {
        // Complete the chunk: if a chunk only loads bg, generate fg and vice-versa.

        if (!chunk.tiles) {
            chunk.tiles = mem::new(ChunkData);
            chunk.generate(true, false);
        }

        if (!chunk.bg_tiles) {
            chunk.bg_tiles = mem::new(ChunkData);
            chunk.generate(false, true);
        }

        chunk.light_map = mem::new(ChunkData);
        chunk.update_light_map();
    }
}

fn void Chunk.generate(&self, bool fg, bool bg) {
    // HELLO. This is SO INEFFECIENT  SO like make it beteter.

	int base_x = self.position.x * CHUNK_SIZE;
	int base_y = self.position.y * CHUNK_SIZE;

	for (int x = 0; x < CHUNK_SIZE; x++) {
		for (int y = 0; y < CHUNK_SIZE; y++) {
            int index = x + (y * CHUNK_SIZE);
            ushort fg_tile = gen_tile(base_x + x, base_y + y); 
			if (fg) (*self.tiles)[index] = fg_tile;

            if (bg) (*self.bg_tiles)[index] = gen_bg_tile(base_x + x, base_y + y, fg_tile);

            //ushort existing_tile = self.tiles ? (*self.tiles)[index] : gen_tile(base_x + x, base_y + y); 
            //if (bg) (*self.bg_tiles)[index] = gen_bg_tile(base_x + x, base_y + y, existing_tile);
            //if (bg) (*self.bg_tiles)[index] = 4;
		}
	}
}

fn Chunk gen_chunk(Vector2i pos) {
	io::printf("Generating %d %d\n", pos.x, pos.y);

	Chunk chunk = {
		pos,
        mem::new(ChunkData),
        mem::new(ChunkData),
        false,
        false,
        null,
        //mem::new(ChunkData),
	};

    chunk.generate(true, true);
    return chunk;
}

fn void render_chunks() {
    Vector2 top_left = raylib::get_screen_to_world2d({0, 0}, terc3::camera);
    top_left.x = top_left.x / (float)TILE_SIZE / (float)CHUNK_SIZE;
    top_left.y = top_left.y / (float)TILE_SIZE / (float)CHUNK_SIZE;

    Vector2 bottom_right = raylib::get_screen_to_world2d({
        raylib::get_screen_width(),
        raylib::get_screen_height(),
    }, terc3::camera);
    bottom_right.x = bottom_right.x / (float)TILE_SIZE / (float)CHUNK_SIZE;
    bottom_right.y = bottom_right.y / (float)TILE_SIZE / (float)CHUNK_SIZE;

	foreach (chunk : chunks.value_tlist()) {
        if (chunk.position.x + 1 < (int)(top_left.x)) continue;
        if (chunk.position.x > (int)(bottom_right.x)) continue;
        if (chunk.position.y + 1 < (int)(top_left.y)) continue;
        if (chunk.position.y > (int)(bottom_right.y)) continue;

        if (!chunk.light_map) chunk.update_light_map();

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

				float light = (float)(*chunk.light_map)[index] / 255.0;

				uint bg_tile = (*chunk.bg_tiles)[index];
				if (bg_tile) {
                    raylib::draw_texture_ex(
                        tiles::tile_list[bg_tile].texture,
                        draw_pos,
                        0.0,
                        2.0,
                        raylib::color_brightness(raylib::WHITE, -1.4 + light),
                    );
                }

				ushort tile = (*chunk.tiles)[index];
				if (tile) {
                    raylib::draw_texture_ex(
                        tiles::tile_list[tile].texture,
                        draw_pos,
                        0.0,
                        2.0,
                        raylib::color_brightness(raylib::WHITE, -1.0 + light),
                    );
                }

                if (terc3::mine_progress.start_time && tile_pos.eq(terc3::mine_progress.position)) {
                    raylib::draw_rectangle_v(
                        {
                            (float)(tile_pos.x * TILE_SIZE),
                            (float)(tile_pos.y * TILE_SIZE),
                        },
                        {32, 32},
                        raylib::fade(raylib::WHITE, (float)terc3::mine_progress.progress / 3),
                    );
                }
			}
		}
	}
}
