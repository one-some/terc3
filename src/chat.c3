import raylib;
import vector2;
import std::io;
import inventory;

bool chat_open = false;
String chat_buf;

fn void render_message(int y, int width, String message) {
    raylib::draw_rectangle(0, y, width, 32, {0, 0, 0, 0x77});
    raylib::draw_text(message, 4, 4 + y, 24, raylib::WHITE);
}

fn void process_key(char key) {
    if (key == '/') {
        chat_buf = "/";
        chat_open = !chat_open;
        return;
    }

    if (!chat_open) return;

    chat_buf = chat_buf.concat({key});
}

fn void execute_command(String cmd) {
    String[] bits = cmd.strip("/").split(" ");
    if (!bits.len) return;
    switch (bits[0]) {
        case "give":
            int amount = bits[1].to_integer(int)!!;
            ItemID item_id = bits[2].to_integer(ItemID)!!;
            inventory::add_item(item_id, amount);
            break;
        default:
            break;
    }
    io::printn(bits);
}

fn void render() {
    int y = 0;

    Vector2i screen_size = {
        raylib::get_screen_width(),
        raylib::get_screen_height(),
    };

    int key = raylib::get_char_pressed();

    while (key > 0) {
        process_key((char)key);
        key = raylib::get_char_pressed();
    }

    if (!chat_open) return;

    if (raylib::is_key_pressed(raylib::keyboard::BACKSPACE)) {
        // I have a serious misunderstanding of how the underlying data is being used to have to do this
        chat_buf = chat_buf[..(chat_buf.len - 2)].copy();
    }

    if (raylib::is_key_pressed(raylib::keyboard::ENTER)) {
        execute_command(chat_buf);
        chat_buf = "";
        chat_open = false;
        return;
    }

    render_message(y += 48, screen_size.x, chat_buf);
}