import raylib;
import inventory;
import std::collections::map;
import std::collections::list;

def TileID = ushort;

struct Tile {
	TileID id;
	ItemID item_id;
	String name;
	raylib::Texture2D texture;
}

HashMap(<ItemID, Tile*>) item2tile;
Tile*[] tile_list;

fn void new_from_item(Item* item) {
	item2tile.set(item.id, mem::new(Tile, {
		(TileID)item2tile.len(),
		item.id,
		item.name,
		item.texture
	}));
}

fn void register() {
	new_from_item(inventory::create_item("Air", raylib::load_texture("resources/hi.png")));
	new_from_item(inventory::create_item("Dirt", raylib::load_texture("resources/dirt.png")));
	new_from_item(inventory::create_item("Grass", raylib::load_texture("resources/grass.png")));
	new_from_item(inventory::create_item("Stone", raylib::load_texture("resources/stone.png")));
	new_from_item(inventory::create_item("Stone Brick", raylib::load_texture("resources/stone_brick.png")));
	inventory::create_item("Synthium Pickaxe", raylib::load_texture("resources/pickaxe.png"));
	new_from_item(inventory::create_item("Log", raylib::load_texture("resources/log.png")));
	new_from_item(inventory::create_item("Leaves", raylib::load_texture("resources/leaves.png")));
	new_from_item(inventory::create_item("Iron Ore", raylib::load_texture("resources/iron.png")));

	tile_list = item2tile.value_new_list();
}