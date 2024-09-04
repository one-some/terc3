import raylib;
import vector2;
import std::io;
import inventory;
import ui;
import std::collections::list;

const MSG_HEIGHT = 32;
const FONT_SIZE = 24;

struct ChatMessage {
    String content;
    int visual_ttl;
    int px_width;
}

List(<ChatMessage>) messages;
String chat_buf;

fn void add_message(String content) {
    // Don't need ZString as we won't be editing before this
    messages.push({
        content,
        800,
        raylib::measure_text(content, FONT_SIZE)
    });
}

fn void process_key(char key) {
    if (!ui::menu_open() && key == '/') {
        chat_buf = "/";
        ui::active_menu = Menu.CHAT;
        return;
    }

    if (!ui::menu_open() && key == 't') {
        chat_buf = "";
        ui::active_menu = Menu.CHAT;
        return;
    }

    if (ui::active_menu != Menu.CHAT) return;

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
            add_message(string::new_format("[giantmaze] %s", cmd));
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

    if (ui::active_menu == Menu.CHAT) {
        if (raylib::is_key_pressed(raylib::keyboard::BACKSPACE) && chat_buf.len) {
            chat_buf = chat_buf[0 : ^1];
        }

        if (raylib::is_key_pressed(raylib::keyboard::ENTER)) {
            execute_command(chat_buf);
            chat_buf = "";
            ui::active_menu = Menu.NONE;
            return;
        }


        raylib::draw_rectangle(0, y += MSG_HEIGHT, screen_size.x, 32, {0, 0, 0, 0x77});
        @pool() {
            // Questionable allocation and formatting overhead for stupidness
            raylib::draw_text(string::tformat_zstr("%s", chat_buf), 4, 4 + y, 24, raylib::WHITE);
        };
    }

    foreach_r (&message : messages) {
        if (!message.visual_ttl) continue;
        message.visual_ttl--;

        float opacity = 1.0;
        if (message.visual_ttl < 200) {
            opacity = (float)(message.visual_ttl) / 200.0;
        }

        raylib::draw_rectangle(
            0,
            y += MSG_HEIGHT,
            message.px_width + 8,
            32,
            {0, 0, 0, (char)(opacity * 0x77)}
        );
        raylib::draw_text(
            message.content,
            4,
            y + 4,
            FONT_SIZE,
            {0xFF, 0xFF, 0xFF, (char)(opacity * 0xFF)}
        );
    }
}