import {castBoolean, isTrue, isFalse, castLiteral, isBigNum, cleanBoolStr} from '../utils'
import { Big } from 'big.js';
import {} from 'jest';


test('test is true boolean checks', () => {
    // Case insensitive
    // @ts-ignore:
    expect(isTrue(true)).toBe(true);
    expect(isTrue("true")).toBe(true);
    expect(isTrue("TRUE")).toBe(true);
    expect(isTrue("tRUe")).toBe(true);

    expect(isTrue("false")).toBe(false);
    expect(isTrue("FALSE")).toBe(false);
    expect(isTrue("something")).toBe(false);

    expect(isTrue("0")).toBe(false);
    // @ts-ignore:
    expect(isTrue(0)).toBe(false);
    // @ts-ignore:
    expect(isTrue(1)).toBe(false);
    // @ts-ignore:
    expect(isTrue(-1)).toBe(false);

});

test('test is false boolean checks', () => {
    // Case insensitive
    // @ts-ignore:
    expect(isFalse(true)).toBe(false);
    expect(isFalse("true")).toBe(false);
    expect(isFalse("TRUE")).toBe(false);
    expect(isFalse("tRUe")).toBe(false);

    expect(isFalse("false")).toBe(true);
    expect(isFalse("FALSE")).toBe(true);
    expect(isFalse("faLse")).toBe(true);

    expect(isFalse("something")).toBe(false);

    expect(isFalse("0")).toBe(false);
    // @ts-ignore:
    expect(isFalse(0)).toBe(false);
    // @ts-ignore:
    expect(isFalse(1)).toBe(false);
    // @ts-ignore:
    expect(isFalse(-1)).toBe(false);
});

test('test casting literals', () => {
    // @ts-ignore:
    expect(cleanBoolStr(true)).toBe("TRUE");
    expect(cleanBoolStr("true")).toBe("TRUE");

    expect(castBoolean("true")).toBe(true);

    expect(castLiteral("true")).toBe(true)
    expect(castLiteral("FALSE")).toBe(false)

    expect(isBigNum(Big("10"))).toBe(true);
    expect(isBigNum("blah")).toBe(false);

    expect(castLiteral("something")).toEqual("something")
});