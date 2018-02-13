import {} from 'jest';
import { Environment, Engine } from '../engine';
import { Big } from 'big.js';
import { evaluateExpr, parseFormula } from '../expr';
import { castLiteral } from '../utils';

test('precise floating point math', () => {
    let engine = new Engine()
    let env = engine.rootEnv;

    expect(evaluateExpr(parseFormula("=0.1 + 0.2"), env).eq(new Big("0.3"))).toEqual(true)
    expect(evaluateExpr(parseFormula("=1.0 / 10"), env).eq(new Big("0.1"))).toEqual(true)
    expect(evaluateExpr(parseFormula("=.01 + 100000000000000"), env).eq(new Big("100000000000000.01"))).toEqual(true)

    expect(evaluateExpr(parseFormula("=1.2 - 1.0"), env).eq(new Big("0.2"))).toEqual(true)


    // Verify fudging - big js would normally return 0.3333 (x20)
    expect(evaluateExpr(parseFormula("=(1/3) * 3"), env).eq(new Big("1"))).toEqual(true)
});

test('operator precedence', () => {
    let engine = new Engine()
    let env = engine.rootEnv;

    // Wrong order
    expect(evaluateExpr(parseFormula("=3 + 4 * 5"), env).eq(new Big("35"))).toEqual(false) // Left to right precedence
    expect(evaluateExpr(parseFormula("=3 * 4 + 5"), env).eq(new Big("27"))).toEqual(false) // Right to left precedence

    // Multiplication before addition
    expect(evaluateExpr(parseFormula("=3 + 4 * 5"), env).eq(new Big("23"))).toEqual(true)
    expect(evaluateExpr(parseFormula("=3 * 4 + 5"), env).eq(new Big("17"))).toEqual(true)

    // Parenthesis evaluation
    expect(evaluateExpr(parseFormula("=(3 + 4) * 5"), env).eq(new Big("35"))).toEqual(true)
    expect(evaluateExpr(parseFormula("=3 * (4 + 5)"), env).eq(new Big("27"))).toEqual(true)
});


test('rounding mode', () => {

    let engine = new Engine()
    let env = engine.rootEnv;

    // Round-up method
    // @ts-ignore: Assume return value is Big
    expect(castLiteral("2.5").round().eq(new Big("3"))).toEqual(false)

    // Verify using banker's roll
    // @ts-ignore: Assume return value is Big
    expect(castLiteral("2.5").round().eq(new Big("2"))).toEqual(true)

    // Verify round to zero
    // @ts-ignore: Assume return value is Big
    expect(castLiteral("0.5").round().eq(new Big("0"))).toEqual(true)
    // @ts-ignore: Assume return value is Big
    expect(castLiteral("-0.5").round().eq(new Big("0"))).toEqual(true)

    // @ts-ignore: Assume return value is Big
    expect(castLiteral("-1.5").round().eq(new Big("-2"))).toEqual(true)
    // @ts-ignore: Assume return value is Big
    expect(castLiteral("1.5").round().eq(new Big("2"))).toEqual(true)
})