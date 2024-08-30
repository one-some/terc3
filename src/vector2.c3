import raylib;

struct Vector2i {
	int x;
	int y;
}

fn bool Vector2i.eq(&self, Vector2i v) { return self.x == v.x && self.y == v.y; }
fn Vector2i Vector2i.plus(&self, Vector2i v) { return {self.x + v.x, self.y + v.y}; }
fn Vector2i Vector2i.minus(&self, Vector2i v) { return {self.x - v.x, self.y - v.y}; }

fn Vector2i Vector2i.div_scalar(&self, int s) { return {self.x / s, self.y / s}; }

fn double Vector2i.distance_to(&self, Vector2i v) {
	return $$sqrt(
		$$pow((double)v.x - (double)self.x, 2.0) +
		$$pow((double)v.y - (double)self.y, 2.0)
	);
}
fn Vector2i to_2i(Vector2 v) {
	return { (int)v.x, (int)v.y };
}