import raylib;
import std::collections::list;

struct Tile {
	String name;
	raylib::Texture2D texture;
}

List(<Tile>) tile_list;

fn void register() {
	//tile_list.new_init();
	tile_list.push(Tile { "Air", raylib::load_texture("resources/hi.png") });
	tile_list.push(Tile { "Dirt", raylib::load_texture("resources/dirt.png") });
	tile_list.push(Tile { "Grass", raylib::load_texture("resources/grass.png") });
	tile_list.push(Tile { "Stone", raylib::load_texture("resources/stone.png") });
	tile_list.push(Tile { "Stone Brick", raylib::load_texture("resources/stone_brick.png") });
	tile_list.push(Tile { "Log", raylib::load_texture("resources/log.png") });
	tile_list.push(Tile { "Leaves", raylib::load_texture("resources/leaves.png") });
	tile_list.push(Tile { "Iron Ore", raylib::load_texture("resources/iron.png") });
}