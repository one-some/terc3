import raylib;
import std::io;

import tiles;
import vector2;

def ItemID = ushort;

struct InventorySlot {
    ItemID item;
    int count;
}

const INVENTORY_ITEM_SIZE = 48;
const HAND_SLOT = 51;
InventorySlot[51] inventory;
bool inventory_open = false;
int cursor_index = 1;

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

fn void InventorySlot.render(&self, raylib::Vector2 pos, bool highlighted) {
    raylib::draw_rectangle_v(
        pos,
        {INVENTORY_ITEM_SIZE, INVENTORY_ITEM_SIZE},
        highlighted ? raylib::RED : raylib::BLACK,
    );

    if (!self.item) return;

    raylib::draw_texture_ex(
        tiles::tile_list[self.item].texture,
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

fn void render_inventory() {
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

        inventory::inventory[i].render(pos, i == cursor_index);
    }

    if (!inventory_open) return;

    foreach (int i, slot : inventory::inventory[10..49]) {
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