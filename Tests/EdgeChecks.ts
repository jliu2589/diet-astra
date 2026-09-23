// No network permission is granted. All fetches must hit the explicit stub.
Deno.env.set('SUPABASE_URL', 'https://astra-test.invalid');
Deno.env.set('SUPABASE_ANON_KEY', 'test-public-key');
Deno.env.set('OPENAI_API_KEY', 'test-server-key');
Deno.env.set('OPENAI_MEAL_MODEL', 'test-model');
const { handleMeal } = await import('../supabase/functions/interpret-meal/handler.ts');
const realFetch = globalThis.fetch;
function assert(value: unknown, message: string) { if (!value) throw new Error(message); }
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const food = { name: 'Rice', grams: 250, calories_per100g: 130, protein_per100g: 2.7, carbs_per100g: 28, fat_per100g: .3 };
function request(body: unknown, token = 'Bearer test-user-token', method = 'POST') {
  return new Request('https://astra-test.invalid/functions/v1/interpret-meal', { method, headers: { Authorization: token, 'Content-Type': 'application/json' }, ...(method === 'POST' ? { body: JSON.stringify(body) } : {}) });
}
Deno.test('Edge authentication, quota, failures, structured review payload and privacy options', async () => {
  let authStatus = 200, quota = true, modelStatus = 'completed', modelFoods = [food];
  let modelCalls = 0;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith('/auth/v1/user')) {
      assert(new Headers(init?.headers).get('Authorization') === 'Bearer test-user-token', 'Must validate caller token');
      return response({ id: 'test-user' }, authStatus);
    }
    if (url.endsWith('/rest/v1/rpc/astra_claim_ai_request')) {
      assert(new Headers(init?.headers).get('Authorization') === 'Bearer test-user-token', 'Quota must use caller identity');
      return response(quota);
    }
    if (url === 'https://api.openai.com/v1/responses') {
      modelCalls++;
      const body = JSON.parse(String(init?.body));
      assert(body.store === false, 'No stored response');
      assert(body.text.format.strict === true, 'Strict schema required');
      assert(!JSON.stringify(body).includes('test-user-token'), 'No user JWT sent to OpenAI');
      return response({ status: modelStatus, output: [{ content: [{ type: 'output_text', text: JSON.stringify({ title: 'Lunch', note: 'Verify portion', foods: modelFoods }) }] }] });
    }
    throw new Error('Unexpected network target');
  }) as typeof fetch;
  try {
    assert((await handleMeal(request({}, '', 'GET'))).status === 405, 'Reject method');
    assert((await handleMeal(request({ text: 'Rice' }, ''))).status === 401, 'Reject missing auth');
    authStatus = 401;
    assert((await handleMeal(request({ text: 'Rice' }))).status === 401, 'Reject expired auth');
    assert(modelCalls === 0, 'Unauthenticated request cannot incur model cost');
    authStatus = 200;
    assert((await handleMeal(request({ text: '' }))).status === 400, 'Reject empty input');
    assert((await handleMeal(request({ text: 'Rice', image: 'https://example.invalid' }))).status === 400, 'No arbitrary image URL');
    quota = false;
    assert((await handleMeal(request({ text: 'Rice' }))).status === 429, 'Enforce quota');
    assert(modelCalls === 0, 'Over-quota request cannot incur model cost');
    quota = true;
    const result = await handleMeal(request({ text: '250g rice' }));
    assert(result.status === 200, 'Successful analysis');
    const body = await result.json();
    assert(body.foods[0].calories === 325 && body.foods[0].protein === 6.75, 'Deterministic scaling');
    assert(typeof body.foods[0].id === 'string', 'Stable draft IDs supplied');
    modelStatus = 'incomplete';
    assert((await handleMeal(request({ text: 'Rice' }))).status === 422, 'Reject incomplete model output');
    modelStatus = 'completed'; modelFoods = [];
    assert((await handleMeal(request({ text: 'Not food' }))).status === 422, 'Reject unrecognized meal');
  } finally { globalThis.fetch = realFetch; }
});
