import raylib;
import inventory;

enum Menu {
    NONE,
    INVENTORY,
    CHAT
}

Menu active_menu = Menu.NONE;

fn bool menu_open() {
    return active_menu != Menu.NONE;
}

fn bool mouse_in_rect(Rectangle rect) {
    Vector2 mouse_pos = raylib::get_mouse_position();
    return raylib::check_collision_point_rec(
        mouse_pos,
        rect
    );
}