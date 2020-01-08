import { configureStore, createSlice } from 'redux-starter-kit'
import { modifySize, parseEverything } from './controller.js'
import { apiPost, apiPatch } from './utils.js'
import { CELL_MAX_WIDTH, CELL_MAX_HEIGHT } from './constants.js'

const initialState = {
    cells: {
        byId: {},
        allIds: [], //"@3", "@4", "@5", "@6", 
        focus: null,  // ID of the element selected
        modified: false,  // Allow initial evaluation
    }
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
        initCell: (state, action) => {
            let id = action.payload.id;
            let cell = action.payload;
            state.byId[id] = {
                "id": cell.id,
                "input": cell.input,
                "name": cell.name,
                "type": "cell"
            };
            state.allIds.push(id);
            // Don't set state.modified since this is initialization
        },
        addCell: (state, action) => {
            console.log("in add cell");
            let id = 1;
            if(state.allIds.length > 0) {
                // Find the ID of the last cell and increment
                id = state.allIds[state.allIds.length - 1] + 1;
            }
            console.log(id);
            state.byId[id] = {
                "id": id,
                "name": "",
                "input": "",
                "type": "cell"
            }
            state.allIds.push(id);
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
const initCell = cellsSlice.actions.initCell;
export const addCell = cellsSlice.actions.addCell;

export const loadView = () => {
    return (dispatch, getState) => {
        fetch('/api/v1/views/' + window._aa_viewid + '?format=json').then((data) => {
            return data.json();
        }).then((view) => {
            console.log("view is");
            console.log(view);
            window._aa_view = view;

            var content = JSON.parse(view.content);
            var body = content['body']
    
            for(var i = 0; i < body.length; i++) {
                dispatch(initCell(body[i]))
            }
            dispatch(setModified())

            dispatch(reEvaluate())
        });
        
    }
}

const reEvaluate = () => {
    return (dispatch, getState) => {
        const state = getState();
        if(state.cellsReducer.modified === false){
            return
        }
        let parsed = parseEverything(state.cellsReducer.byId);

        apiPatch("/api/v1/views/" + window._aa_viewid + "/?format=json", {
            'content': JSON.stringify(parsed)
        })

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

        
        // TODO: This would be done by the backend
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


export const mapStateToProps = (state /*, ownProps*/) => {
    return {
        cells: state.cellsReducer.allIds.map((id) => state.cellsReducer.byId[id]),
        byId: state.cellsReducer.byId,
        focus: state.cellsReducer.focus
    }
}

export const mapDispatchToProps = {setFocus, setInput, setName, reEvaluate, incWidth, incHeight, moveFocus, setModified, initCell, addCell}