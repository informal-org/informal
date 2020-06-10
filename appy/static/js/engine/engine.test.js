import { evaluate } from "./engine"


function listToDict(list, key="id") {
    let d = {};
    list.forEach((elem) => {
        d[elem[key]] = elem
    })
    return d
}

test('Evaluate basic expressions', () => {
    // When cells don't depend on each other, their order remains the same
    let state ={
        cellsReducer: {
            byId: {
                0: {
                    id: 0,
                    name: "root",
                    depends_on: [], 
                
                    body: [1, 2, 3],
                    params: []
                },
                1: {
                    id: 1,
                    name: "a",
                    expr: "1 + 1",
                    depends_on: [],
                    
                    body: [],
                    params: []
                },
                2: {
                    id: 2,
                    name: "b",
                    depends_on: [1],
                    expr: "a * 2",
            
                    body: [],
                    params: []
                },
                3: {
                    id: 3,
                    name: "",
                    depends_on: [2],
                    expr: "b",
            
                    body: [],
                    params: []
                }
            },
            currentRoot: 0
        }
    }

    let output = evaluate(state).results;
    console.log(output);
    let outputDict = listToDict(output)

    expect(outputDict[1].value).toEqual(2)
    expect(outputDict[2].value).toEqual(4)
    expect(outputDict[3].value).toEqual(4)
});

function evalSingleExpr(expr) {
    let state ={
        cellsReducer: {
            byId: {
                0: {
                    id: 0,
                    name: "",
                    expr: "",
                    depends_on: [],
                    
                    body: [1],
                    params: []
                },
                1: {
                    id: 1,
                    name: "",
                    expr: expr,
                    depends_on: [],
                    
                    body: [],
                    params: []
                },                
            },
            currentRoot: 0
        }
    }

    let output = evaluate(state).results;
    let outputDict = listToDict(output)
    return outputDict[1].value
}

test('Eval order of ops', () => {
    expect(evalSingleExpr("(2 + 3) * 4")).toEqual(20)
});
