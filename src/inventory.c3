import raylib;
import std::io;
import std::collections::list;

import ui;
import vector2;

def ItemID = ushort;

struct InventorySlot {
    ItemID item;
    int count;
}

const INVENTORY_ITEM_SIZE = 48;
const HAND_SLOT = 50;
InventorySlot[51] inventory;
bool inventory_open = false;
int cursor_index = 1;
int hovered_slot = - 1;

struct Item {
    ItemID id;
    String name;
    raylib::Texture2D texture;
    int stack_size;
}

List(<Item*>) item_list;

fn Item* create_item(String name, raylib::Texture2D texture, int stack_size = 99) {
    Item* item = mem::new(Item, {(ItemID)item_list.len(), name, texture, stack_size});
    item_list.push(item);
    return item;
}

fn Item* selected_item() {
	return item_list[inventory[cursor_index].item];
}

fn int InventorySlot.get_index(InventorySlot* target) {
    foreach (int i, slot : inventory) {
        if (target == &inventory[i]) return i;
    }
    unreachable("Uh oh");
}

fn void handle_item_left_click() {
    if (hovered_slot < 0) return;

    InventorySlot* hand = &inventory[HAND_SLOT];
    InventorySlot* hovered = &inventory[hovered_slot];

    // Put something in hand if nothing there
    if (!hand.count) {
        *hand = *hovered;
        *hovered = {};
        return;
    }

    // If the items are different, swap them
    if (hand.item != hovered.item) {
        @swap(*hovered, *hand);
        return;
    }

    // Items are same, let's calculate how much we can stuff in there
    Item* item = item_list[hovered.item];
    int needed_for_stack = item.stack_size - hovered.count;
    int amount_to_give = $$min(needed_for_stack, hand.count);

    hand.count -= amount_to_give;
    hovered.count += amount_to_give;
    if (!hand.count) hand.item = 0;
}

fn void handle_item_right_click() {
    if (hovered_slot < 0) return;

    InventorySlot* hand = &inventory[HAND_SLOT];
    InventorySlot* hovered = &inventory[hovered_slot];

    if (hand.count) {
        // We want to give!

        // If this isn't an empty slot, take some things into account
        if (hovered.count) {
            // Don't stack into another item!
            if (hovered.item != hand.item) return;

            Item* item = item_list[hovered.item];
            // Don't stack higher than you can handle!
            if (hovered.count >= item.stack_size) return;
        }

        hovered.count++;
        hovered.item = hand.item;
        if (!--hand.count) hand.item = 0;

        return;
    }

    // We want to take!

    // Take ...what?
    if (!hovered.count) return;

    // Our hands are full!
    if (hand.count) return;

    int count_to_take = hovered.count / 2;

    // Can't take zero!
    if (!count_to_take) return;

    hovered.count -= count_to_take;
    hand.count = count_to_take;
    hand.item = hovered.item;
}

fn void add_item(ItemID id, int delta) {
    bool rev = delta < 0;
    // Loop forward if adding items, backward if removing items
    for (int i = rev ? inventory.len - 1 : 0; i != (rev ? -1 : inventory.len); i += rev ? -1 : 1) {
        InventorySlot slot = inventory[i];
        if (slot.item != id) continue;

        int max_count = item_list[slot.item].stack_size;
        int future_count = inventory[i].count + delta;

        if (future_count > max_count) {
            inventory[i].count = max_count;
            delta = future_count - max_count;
            continue;
        }

        inventory[i].count += delta;

        // Clear item if decrementing all of 'em
        if (inventory[i].count <= 0) {
            inventory[i] = {0, 0};
        }

        return;
    }

    // If it's a new item (or it doesn't), add a slot for it
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

fn void InventorySlot.render(&self, raylib::Vector2 pos, bool selected) {
    bool hovered = ui::mouse_in_rect({
        pos.x,
        pos.y,
        INVENTORY_ITEM_SIZE,
        INVENTORY_ITEM_SIZE
    });

    bool render_bg = true;

    if (self == &inventory[HAND_SLOT]) {
        hovered = false;
        render_bg = false;
    }

    if (hovered) {
        hovered_slot = self.get_index();
    }

    bool highlighted = selected || hovered;

    if (render_bg) {
        raylib::draw_rectangle_v(
            pos,
            {INVENTORY_ITEM_SIZE, INVENTORY_ITEM_SIZE},
            highlighted ? raylib::RED : raylib::Color {0x00, 0x00, 0x00, 0xAA},
        );
    }

    if (!self.item) return;

    raylib::draw_texture_ex(
        item_list[self.item].texture,
        {pos.x + 2.0, pos.y + 2.0},
        0.0,
        (float)INVENTORY_ITEM_SIZE / 18.0f,
        raylib::WHITE
    );

    if (self.count == 1) return;

    raylib::draw_text(
        string::tformat_zstr("%d", self.count),
        ((int)pos.x) + INVENTORY_ITEM_SIZE - 26,
        (int)pos.y,
        24,
        highlighted ? raylib::RED : raylib::YELLOW
    );
}

fn void render_inventory() {
    int screen_width = raylib::get_screen_width();
    int screen_height = raylib::get_screen_height();

    const MARGIN = 4;
    const HOTBAR_WIDTH = (INVENTORY_ITEM_SIZE + MARGIN) * 10;
    int hotbar_start = (screen_width - HOTBAR_WIDTH) / 2;

    hovered_slot = -1;

    for (int i = 9; i >= 0; i--) {
        raylib::Vector2 pos = {
            (float)(hotbar_start + ((INVENTORY_ITEM_SIZE + MARGIN) * i)),
            (float)(screen_height - INVENTORY_ITEM_SIZE),
        };

        inventory[i].render(pos, i == cursor_index);
    }

    if (!inventory_open) return;

    for (int i = 10; i < 50; i++) {
        Vector2i item_pos = { i % 10, 4 - (i / 10) };

        raylib::Vector2 pos = {
            (float)(hotbar_start + ((INVENTORY_ITEM_SIZE + MARGIN) * item_pos.x)),
            (float)((screen_height / 2) - ((INVENTORY_ITEM_SIZE + MARGIN) * (item_pos.y - 2))),
        };

        inventory[i].render(pos, false);
    }

    if (raylib::is_mouse_button_pressed(raylib::MouseButton.BUTTON_LEFT)) {
        handle_item_left_click();
    } else if (raylib::is_mouse_button_pressed(raylib::MouseButton.BUTTON_RIGHT)) {
        handle_item_right_click();
    }

    inventory[HAND_SLOT].render(raylib::get_mouse_position(), false);
}