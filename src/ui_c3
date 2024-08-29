import raylib;
import std::collections::list;
import std::io;

import uig;
import vector2;


enum ComponentType {
    BASE,
    BOX,
}

enum EventType {
    MOUSE_ENTER,
    MOUSE_LEAVE,
}

List(<UIComponent*>) renderables;
Vector2i last_mouse_pos;

def EventCallback = fn void(UIComponent*, EventType);

struct UIComponent {
    ComponentType type;
    UIComponent* parent;
    Vector2i position;

    // HACK
    EventCallback event_callback;
}

struct UIBox {
    inline UIComponent component;
    Vector2i size;
    raylib::Color background_color;
}

struct UIGridContainer {
    inline UIComponent component;
    int rows;
}

fn UIBox* uibox_new() {
    UIBox* component = uig::new(<UIBox>)();
    component.event_callback = fn (UIComponent* _self, event_type) {
        UIBox* self = (UIBox*)_self;
        self.background_color = event_type == EventType.MOUSE_ENTER ? raylib::BLUE : raylib::RED;
    };
    return component;
}

fn Vector2i UIComponent.global_position(&self) {
    if (!self.parent) return self.position;
    return self.parent.global_position().plus(self.position);
}

fn void UIComponent.render(&self) {

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

fn bool point_in_box(Vector2i pos, Vector2i size) {
    if (pos.x < 0) return false;
    if (pos.y < 0) return false;
    if (pos.x > size.x) return false;
    if (pos.y > size.y) return false;
    return true;
}

fn void process_mouse_events(Vector2i mouse_pos) {
    foreach (_r : renderables) {
        if (!_r.event_callback) continue;
        if (_r.type != ComponentType.BOX) continue;
        UIBox* box = (UIBox*)_r;

        Vector2i pos = box.global_position();

        bool in_box = point_in_box(mouse_pos.minus(pos), box.size);
        bool formerly_in_box = point_in_box(last_mouse_pos.minus(pos), box.size);

        if (in_box == formerly_in_box) continue;
        box.event_callback(box, in_box ? EventType.MOUSE_ENTER : EventType.MOUSE_LEAVE);
    }
}

fn void render() {
    Vector2i mouse_pos = {
        raylib::get_mouse_x(),
        raylib::get_mouse_y(),
    };

    if (!mouse_pos.eq(last_mouse_pos)) {
        process_mouse_events(mouse_pos);
        last_mouse_pos = mouse_pos;
    }

    foreach (r : renderables) {
        r.render();
    }
}