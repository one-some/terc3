import raylib;
import std::collections::list;
import std::io;

import vector2;

def Callback = fn void(UIBox*);

enum ComponentType {
    BASE,
    BOX,
}

struct UIComponent {
    ComponentType type;
    UIComponent* parent;
    Vector2i position;
}

List(<UIBox*>) renderables;
Vector2i last_mouse_pos;

struct UIBox {
    inline UIComponent component;
    Vector2i size;
    raylib::Color background_color;

    Callback ev_mouse_enter;
}

fn void null_callback() { }

fn void hello(UIBox* self) {
    self.background_color = raylib::BLUE;
    io::printn("Hello");
}


fn UIBox* uibox_new() {
    UIBox* component = mem::new(UIBox, {
        {BOX, null, {100, 100}},
        {25, 25},
        raylib::RED,
        &hello
    });
    renderables.push(component);
    return component;
}

fn Vector2i UIComponent.global_position(&self) {
    if (!self.parent) return self.position;
    return self.parent.global_position().plus(self.position);
}

fn void UIBox.render(&self) {
    Vector2i pos = self.global_position();
    raylib::draw_rectangle(
        pos.x,
        pos.y,
        self.size.x,
        self.size.y,
        self.background_color
    );
}

fn void process_mouse_events(Vector2i mouse_pos) {
    foreach (r : renderables) {
        if (r.type != ComponentType.BOX) continue;

        Vector2i pos = r.global_position();
        if (mouse_pos.x < pos.x) continue;
        if (mouse_pos.y < pos.y) continue;
        if (mouse_pos.x > pos.x + r.size.x) continue;
        if (mouse_pos.y > pos.y + r.size.x) continue;
        r.ev_mouse_enter(r);
    }
}

fn void render() {
    Vector2i mouse_pos = {
        raylib::get_mouse_x(),
        raylib::get_mouse_y(),
    };

    if (!mouse_pos.eq(last_mouse_pos)) {
        last_mouse_pos = mouse_pos;
        process_mouse_events(mouse_pos);
    }

    foreach (r : renderables) {
        r.render();
    }
}