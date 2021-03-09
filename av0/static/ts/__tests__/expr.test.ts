import {uppercaseKeywords} from '../engine/expr'

import {} from 'jest';
// import {test, expect, toEqual} from 'jest'

/* Environment tests */
// Test getting a variable in direct environment
test('reserved keywords are transformed to uppercase', () => {
  expect(uppercaseKeywords("x > 2 where blah and 3 wherein boring (or 2)")).toEqual("x > 2 WHERE blah AND 3 wherein boring (OR 2)");

  // Works on ends of string as well
  expect(uppercaseKeywords("where (and) test whEre")).toEqual("WHERE (AND) test WHERE");
});
