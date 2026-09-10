shader_type canvas_item;

uniform float skew_amount : hint_range(-1.0, 1.0) = 0.22;
uniform float center_y : hint_range(0.0, 100.0) = 11.0;

void vertex() {
    VERTEX.x += (VERTEX.y - center_y) * skew_amount;
}