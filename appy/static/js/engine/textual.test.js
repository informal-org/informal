const textual = require('./textual.js');

test('adds 1 + 2 to equal 3', () => {
  expect(textual.add(1, 2)).toBe(3);
});
