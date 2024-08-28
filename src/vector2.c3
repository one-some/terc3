struct Vector2i {
	int x;
	int y;
}

fn bool Vector2i.eq(&self, Vector2i v) {
	return self.x == v.x && self.y == v.y;
}

fn Vector2i Vector2i.plus(&self, Vector2i v) {
	return {self.x + v.x, self.y + v.y};
}