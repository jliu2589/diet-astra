// Portion arithmetic is deterministic. Per-100g AI values remain estimates.
export function validateRequest(value) {
  if (!value || typeof value !== 'object' || typeof value.text !== 'string' || value.text.length > 4000) throw new Error('invalid');
  const image = value.image;
  if (image != null && (typeof image !== 'string' || image.length > 8_000_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(image) || !image.startsWith('/9j/'))) throw new Error('invalid image');
  if (!value.text.trim() && !image) throw new Error('empty');
  return { text: value.text.trim(), image };
}
export function portions(result, uuid) {
  if (!result || typeof result.title !== 'string' || !result.title.trim() || result.title.length > 200 || typeof result.note !== 'string' || result.note.length > 4000 || !Array.isArray(result.foods) || result.foods.length < 1 || result.foods.length > 50) throw new Error('invalid response');
  const foods = result.foods.map(food => {
    if (typeof food.name !== 'string' || !food.name.trim() || food.name.length > 200 || !Number.isFinite(food.grams) || food.grams < 0.001 || food.grams > 10000) throw new Error('invalid food');
    const row = { id: uuid(), name: food.name.trim(), grams: food.grams, source: 'AI estimate · per-100g values scaled to portion' };
    for (const field of ['calories', 'protein', 'carbs', 'fat']) {
      const value = food[field + '_per100g'];
      if (!Number.isFinite(value) || value < 0 || value > (field === 'calories' ? 1000 : 100)) throw new Error('invalid nutrient');
      row[field] = Math.round(value * food.grams) / 100;
      if (row[field] > 20000) throw new Error('portion too large');
    }
    return row;
  });
  return { title: result.title.trim(), note: result.note, foods };
}
export const schema = {
  type: 'object', additionalProperties: false, required: ['title', 'note', 'foods'],
  properties: {
    title: { type: 'string' }, note: { type: 'string' },
    foods: { type: 'array', items: { type: 'object', additionalProperties: false,
      required: ['name', 'grams', 'calories_per100g', 'protein_per100g', 'carbs_per100g', 'fat_per100g'],
      properties: { name: { type: 'string' }, grams: { type: 'number' }, calories_per100g: { type: 'number' }, protein_per100g: { type: 'number' }, carbs_per100g: { type: 'number' }, fat_per100g: { type: 'number' } }
    } }
  }
};
