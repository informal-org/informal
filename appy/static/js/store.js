import { configureStore, createSlice } from 'redux-starter-kit'
import { parseEverything } from './controller.js'
import { apiPost, apiPatch } from './utils.js'
import { CELL_MAX_WIDTH, CELL_MAX_HEIGHT } from './constants.js'
import { evaluate } from "./engine/engine.js"


/* Schema
{
    id: shortuuid,
    name: valid_string_name,
    params: [cells],    // Basic - just a list of names. Complex - nested cells.
    body: [cells],      // Private function body
    value: value | [values] | [cells]   - Ordered as list, but may represent a dictionary
    computed: {
        error: _,
        value: _
    },
    parsed: _,
    depends_on: []
    used_by: []
}
*/


const initialState = {
    cells: {
        byId: {},
        allIds: [], //"@3", "@4", "@5", "@6", 
        focus: null,  // ID of the element selected
        modified: false,  // Allow initial evaluation
    },
    view: {
        uuid: '',
        shortuuid: '',
        name: '',
        pattern: '',
        method_get: true,
        method_post: true
    }
}

const cellsSlice = createSlice({
    slice: 'cells',
    initialState: initialState.cells,
    reducers: {
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
        initCells: (state, action) => {
            let cells = action.payload;
            cells.forEach((cell) => {
                let id = cell.id;

                state.byId[id] = {
                    "id": cell.id,
                    "input": cell.input,
                    "name": cell.name,
                    "type": "cell"
                };
                state.allIds.push(id);                
            });
            
            // Don't set state.modified since this is initialization
        },        
        setInput: (state, action) => {
            let cell = state.byId[action.payload.id]
            console.log(action.payload.id);
            console.log(cell);
            cell.input = action.payload.input;

            // Clear output for any emptied cells which would be excluded in the response
            if(cell.input.trim() === "") {
                cell.output = "";
                cell.error = "";
            }

            state.modified = true;
        },
        setName: (state, action) => {
            let cell = state.byId[action.payload.id]
            console.log(action.payload.id);
            console.log(cell);
            cell.name = action.payload.name;
            state.modified = true;
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
});

const viewSlice = createSlice({
    slice: 'view',
    initialState: initialState.view,
    reducers: {
        initView: (state, action) => {
            let view = action.payload;
            console.log("Init view ");
            console.log(view);
            state.uuid = view.uuid;
            state.shortuuid = view.shortuuid;
            state.name = view.name;
            state.pattern = view.pattern;
            state.method_get = view.method_get;
            state.method_post = view.method_post;
        },
        patchView: (state, action) => {
            // Allow patching multiple fields in a single call
            let mod = action.payload;
            if ("name" in mod) {
                state.name = mod.name;
            }
            if ("pattern" in mod) {
                state.pattern = mod.pattern;
            }
            if ("method_get" in mod){
                state.method_get = mod.method_get;
            }
            if ("method_post" in mod) {
                state.method_post = mod.method_post;
            }

            apiPatch("/api/v1/views/" + window._aa_viewid + "/?format=json", action.payload)
        }
    }
});


const setInput = cellsSlice.actions.setInput;
const setName = cellsSlice.actions.setName;
const saveOutput = cellsSlice.actions.saveOutput;
const setFocus = cellsSlice.actions.setFocus;
const moveFocus = cellsSlice.actions.moveFocus;
const setModified = cellsSlice.actions.setModified;
const initCell = cellsSlice.actions.initCell;
const initCells = cellsSlice.actions.initCells;
export const addCell = cellsSlice.actions.addCell;

export const initView = viewSlice.actions.initView;
export const patchView = viewSlice.actions.patchView;

export const loadView = () => {
    return (dispatch, getState) => {
        fetch('/api/v1/views/' + window._aa_viewid + '?format=json').then((data) => {
            return data.json();
        }).then((view) => {
            console.log("view is");
            console.log(view);
            window._aa_view = view;
            dispatch(initView(view));

            var content;
            var body;
            
            if(view.content.length > 0) {
                console.log(view.content);
                content = JSON.parse(view.content);
                body = content['body']    
            } else {
                content = {}
                body = []
            }

            let newCells = [];

    
            for(var i = 0; i < body.length; i++) {
                newCells.push(body[i]);
            }

            for(var i = body.length; i < 255; i++) {
                newCells.push({
                    'id': i, 
                    'name': "",
                    'input': '',
                    'type': 'cell'
                });
            }

            dispatch(initCells(newCells));

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

        var result = evaluate(parsed);
        dispatch(saveOutput({
            'status': true,
            'response': result
        }));

        // // TODO: This would be done by the backend
        // apiPost("/api/evaluate", parsed)
        // .then(json => {
        //     console.log("Server eval response");
        //     console.log(json);
        //     // Find the cells and save the value.;
        //     dispatch(saveOutput({
        //         'status': true,
        //         'response': json
        //     }))
        // })
        // .catch(error => {
        //     // document.getElementById("result").textContent = "Error : " + error
        //     console.log("Error")
        //     console.log(error);
        //     // TODO error state 
        //     // This happens separate from an individual cell failing.
        // });
    }
}

const cellsReducer = cellsSlice.reducer;
const viewReducer = viewSlice.reducer;
export const store = configureStore({
  reducer: {
    cellsReducer,
    viewReducer
  }
})

window.store = store;

// Initial evaluation


export const mapStateToProps = (state /*, ownProps*/) => {
    return {
        cells: state.cellsReducer.allIds.map((id) => state.cellsReducer.byId[id]),
        byId: state.cellsReducer.byId,
        focus: state.cellsReducer.focus,
        view_name: state.viewReducer.name,
        view_pattern: state.viewReducer.pattern,
        view_m_get: state.viewReducer.method_get,
        view_m_post: state.viewReducer.method_post
    }
}

export const mapDispatchToProps = {setFocus, setInput, setName, reEvaluate,
    moveFocus, setModified, initCell, addCell, initView, patchView}