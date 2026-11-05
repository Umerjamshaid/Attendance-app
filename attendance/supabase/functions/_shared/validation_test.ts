import { ApiError, coordinate, image, text, uuid } from './validation.ts';
function assert(value: boolean) { if (!value) throw new Error('Assertion failed'); }
function rejects(action: () => unknown) { try { action(); } catch (error) { assert(error instanceof ApiError); return; } throw new Error('Expected rejection'); }
Deno.test('input boundaries reject invalid identifiers and coordinates', () => {
  assert(uuid('30000000-0000-4000-8000-000000000001') === '30000000-0000-4000-8000-000000000001');
  rejects(() => uuid('../another-user'));
  rejects(() => coordinate(NaN, -90, 90));
  rejects(() => coordinate(91, -90, 90));
  rejects(() => coordinate('24', -90, 90));
  rejects(() => text('', 100));
  rejects(() => text('x'.repeat(101), 100));
});
Deno.test('images must be bounded JPEG or PNG bytes', () => {
  rejects(() => image('not base64 !'));
  rejects(() => image(btoa('<script>no</script>')));
  const png = btoa(String.fromCharCode(137,80,78,71,13,10,26,10,0,0,0,0));
  assert(image(png).contentType === 'image/png');
  rejects(() => image('A'.repeat(2_796_208)));
});
