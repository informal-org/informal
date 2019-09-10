import { configureStore, createSlice } from 'redux-starter-kit'
import { modifySize, parseEverything } from './controller.js'
import { apiPost } from './utils.js'
import { CELL_MAX_WIDTH, CELL_MAX_HEIGHT } from './constants.js'

const initialState = {
    cells: {
        byId: {
            1: {
                id: 1,
                type: "cell",
                name: "Count",
                input: "1 + 1"
            },
            2: {
                id: 2,
                type: "cell",
                name: "Name",
                input: "true"
//                input: "@1 + 3"
            },
            // "@3": {
            //     id: "@3",
            //     type: "list",
            //     name: "List",
            //     length: 3,
            //     values: ["@4", "@5", "@6"]
            // },
            // "@4": {
            //     id: "@4",
            //     type: "listcell",
            //     input: "1",
            //     parent: "@3"
            // },
            // "@5": {
            //     id: "@5",
            //     type: "listcell",
            //     input: "2",
            //     parent: "3"
            // },
            // "@6": {
            //     id: "@6",
            //     type: "listcell",
            //     input: "3",
            //     parent: "3"
            // },
        },
        allIds: [1, 2 ], //"@3", "@4", "@5", "@6", 
        focus: null,  // ID of the element selected
        modified: true,  // Allow initial evaluation
    }
}

// 280
for(var i = 7; i < 240; i++){
    let id = i
    
    initialState.cells.byId[id] = {
        "id": id,
        "input": "",
        "type": "cell"
    }
    initialState.cells.allIds.push(id);
}



const cellsSlice = createSlice({
    slice: 'cells',
    initialState: initialState.cells,
    reducers: {
        setInput: (state, action) => {
            let cell = state.byId[action.payload.id]
            console.log(action.payload.id);
            console.log(cell);
            cell.input = action.payload.input;
            state.modified = true;
        },
        setName: (state, action) => {
            let cell = state.byId[action.payload.id]
            console.log(action.payload.id);
            console.log(cell);
            cell.name = action.payload.name;
            state.modified = true;
        },        
        setModified: (state, action) => {
            state.modified = true;
        },
        saveOutput: (state, action) => {
            let status = action.payload.status;
            let response = action.payload.response;
            console.log(response);
            const responseCells = response["results"];
            responseCells.forEach((responseCell) => {
                let stateCell = state.byId[responseCell.id];
                stateCell.output = responseCell.output;
                stateCell.error = responseCell.error;
            });
            // Short-circuit re-evaluation until a change happens.
            state.modified = false;
        },
        incWidth: (state, action) => {
            modifySize(state.byId[action.payload.id], "width", 1, CELL_MAX_WIDTH, action.payload.amt);
        }, 
        incHeight: (state, action) => {
            modifySize(state.byId[action.payload.id], "height", 1, CELL_MAX_HEIGHT, action.payload.amt);
        },
        setFocus: (state, action) => {
            state.focus = action.payload
        },
        moveFocus: (state, action) => {
            let currentIndex = state.allIds.indexOf(state.focus);
            if(currentIndex !== -1){
                let newIndex = currentIndex + action.payload;
                if(newIndex >= 0 && newIndex <= state.allIds.length){
                    state.focus = state.allIds[newIndex];
                }
            }
        }
    }
})


const setInput = cellsSlice.actions.setInput;
const setName = cellsSlice.actions.setName;
const saveOutput = cellsSlice.actions.saveOutput;
// const reEvaluate = cellsSlice.actions.reEvaluate;
const incWidth = cellsSlice.actions.incWidth;
const incHeight = cellsSlice.actions.incHeight;
const setFocus = cellsSlice.actions.setFocus;
const moveFocus = cellsSlice.actions.moveFocus;
const setModified = cellsSlice.actions.setModified;


const reEvaluate = () => {
    return (dispatch, getState) => {
        const state = getState();
        if(state.cellsReducer.modified === false){
            return
        }
        let parsed = parseEverything(state.cellsReducer.byId);
        parsed.input = {
            'path': '/hello',
            'method': 'GET',
            'query': 'v=1&message=hello',
            'get': {        // query & query_string in actix
                'v': 1,
                'message': 'hello'
            },
            'cookies': 'sid=12312',
            'headers': '',
            'content_type': ''  // content-type header
            // TODO: post payload
        }

        apiPost("/api/evaluate", parsed)
        .then(json => {
            // Find the cells and save the value.;
            dispatch(saveOutput({
                'status': true,
                'response': json
            }))
        })
        .catch(error => {
            // document.getElementById("result").textContent = "Error : " + error
            console.log("Error")
            console.log(error);
            // TODO error state 
            // This happens separate from an individual cell failing.
        });
    }
}

const cellsReducer = cellsSlice.reducer;
export const store = configureStore({
  reducer: {
    cellsReducer
  }
})

window.store = store;

// Initial evaluation
store.dispatch(reEvaluate())

export const mapStateToProps = (state /*, ownProps*/) => {
    return {
        cells: state.cellsReducer.allIds.map((id) => state.cellsReducer.byId[id]),
        byId: state.cellsReducer.byId,
        focus: state.cellsReducer.focus
    }
}

export const mapDispatchToProps = {setFocus, setInput, setName, reEvaluate, incWidth, incHeight, moveFocus, setModified}