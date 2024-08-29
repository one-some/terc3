module uig(<Component>);

import ui;
import raylib;

fn Component* new(UIComponent* parent = null) {
    Component* component = mem::new(Component);
    if (parent) component.parent = parent;

    $if $typeof(Component) == UIBox:
        component.type = ComponentType.BOX;
        component.size = {100, 100};
        component.background_color = raylib::RED;
    $endif

    ui::renderables.push(component);
    return component;
}