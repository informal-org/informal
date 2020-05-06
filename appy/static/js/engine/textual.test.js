import {} from './textual.js';

test('dependency order maintained', () => {
  expect(textual.add(1, 2)).toBe(3);
});
