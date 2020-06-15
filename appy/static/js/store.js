import { configureStore, createSlice } from 'redux-starter-kit'
import { parseEverything } from './controller.js'
import { apiPost, apiPatch, genID } from './utils'
import { evaluate } from "./engine/engine.js"
import { Cell } from './engine/Cell.js'



/* Schema
{
    id: shortuuid,
    type: "cell"
    name: valid_string_name,
    expr: value | [values array] | [[keys...], [values...]] | [{id: cell_ref_id}]  // Expressions/values. 
    params: [cells],    // Basic - just a list of names. Complex - nested cells.
    body: [cells],      // Sub block of code cells for function bodies, conditionals, etc. 

    error: undefined, 
    value: undefined,
    parsed: _,
    depends_on: [],     // Cell_ids  
    used_by: [],

    parent: parent_cell_id | null,
}

Dictionaries are stored as ordered keys and values lists.
Nested arrays and objects should be stored as a reference.
*/

function newCell(id, name="", expr="", params=[], parent=null) {
    return {
        id: id, 
        type: "cell",
        name: name, 
        expr: expr,
        params: params,
//        parent: parent,
        body: [],

        value: null,    // Computed result value
        error: null,

//        parsed: null,
//        depends_on: [],
//        used_by: []
    }
}


const ROOT_ID = genID()

const initialState = {
    cells: {
        byId: {},
        // allIds: [], // "@3", "@4", "@5", "@6"
        byName: {},
        focus: null,  // ID of the element selected         // TODO: Move to component
        modified: false,  // Allow initial evaluation,      // TODO: Remove?

        currentRoot: ROOT_ID, // TODO. Use this and remove allIds. Allows top-level re-focus
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

initialState.cells.byId[ROOT_ID] = newCell(ROOT_ID)



const cellsSlice = createSlice({
    slice: 'cells',
    initialState: initialState.cells,
    reducers: {
        initCells: (state, action) => {
            let cells = action.payload;
            // state.currentRoot = newCell(genID());

            cells.forEach((cell) => {
                let id = cell.id;
                state.byId[id] = newCell(cell.id, cell.name, cell.expr, cell.params, cell.parent);
                if(cell.name in state.byName) {
                    state.byName[cell.name].push(cell.id);
                } else {
                    state.byName[cell.name] = [cell.id];
                }
                // state.byId[id] = cell;
                // state.allIds.push(id);       
                state.byId[state.currentRoot].body.push(id)
            });
            
            // Don't set state.modified since this is initialization
        },        
        setInput: (state, action) => {
            let cell = state.byId[action.payload.id]
            console.log(action.payload.id);
            console.log(cell);
            cell.expr = action.payload.input;

            // Clear output for any emptied cells which would be excluded in the response
            if(cell.expr.trim() === "") {
                cell.value = "";
                cell.error = null;
            }

            state.modified = true;
        },
        setName: (state, action) => {
            console.log("ID -> " + action.payload.id)
            let cell = state.byId[action.payload.id];
            console.log(cell);
            console.log(cell.name);
            var oldName = cell.name;
            var newName = action.payload.name;

            // Remove the cell from the old name mapping
            if(oldName != "" && oldName in state.byName) {
                state.byName[oldName] = state.byName[oldName].filter((elem) => elem.id !== cell.id)
            }

            cell.name = newName;
            // Add the new name mapping
            if(newName != "") {
                if(newName in state.byName) {
                    state.byName[newName].push(cell.id);
                } else {
                    state.byName[newName] = [cell.id];
                }    
            }
            state.modified = true;
        },
        addCell: (state, action) => {
            let id = genID();
            state.byId[id] = newCell(id);
            state.byId[state.currentRoot].body.push(id)

            // state.allIds.push(id);
        },
        addParam: (state, action) => {
            var id = action.payload.id;
            state.byId[id].params.push("")
        },
        addRow: (state, action) => {
            var id = action.payload.id;
            // TODO: Add to expr. Support expr as an array. Values should be cell ref objects or raw expression values.
            // state.byId[id].expr
        },
        setParam: (state, action) => {
            var id = action.payload.id;
            var param_index = action.payload.param_index;
            var param_value = action.payload.param_value;
            state.byId[id].params[param_index] = param_value;
            console.log("Setting param");
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
                stateCell.value = responseCell.value;
                stateCell.error = responseCell.error;
            });
            // Short-circuit re-evaluation until a change happens.
            state.modified = false;
        },
        setFocus: (state, action) => {
            state.focus = action.payload
        },
        moveFocus: (state, action) => {
            console.log("Move focus: " + action);
            let currentIndex = state.byId[state.currentRoot].body.indexOf(state.focus);
            console.log(currentIndex);
            if(currentIndex !== -1){
                let newIndex = currentIndex + action.payload;
                console.log("New index: " + newIndex);
                if(newIndex >= 0 && newIndex < state.byId[state.currentRoot].body.length){
                    state.focus = state.byId[state.currentRoot].body[newIndex];
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
export const moveFocus = cellsSlice.actions.moveFocus;
const setModified = cellsSlice.actions.setModified;
const initCells = cellsSlice.actions.initCells;
export const addParam = cellsSlice.actions.addParam;
export const setParam = cellsSlice.actions.setParam;
export const addCell = cellsSlice.actions.addCell;
export const addRow = cellsSlice.actions.addRow;
export const initView = viewSlice.actions.initView;
export const patchView = viewSlice.actions.patchView;

export const loadView = () => {
    return (dispatch, getState) => {
        fetch('/api/v1/views/' + window._aa_viewid + '?format=json').then((data) => {
            return data.json();
        }).then((view) => {
            window._aa_view = view;
            dispatch(initView(view));

            var content;
            var body;
            
            if(view.content.length > 0) {
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

            for(var i = body.length; i < 5; i++) {
                var id = genID();
                newCells.push(newCell(id));
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
        
        if(parsed.body.length > 0) {
            // Prevent wiping all contents accidentally
            apiPatch("/api/v1/views/" + window._aa_viewid + "/?format=json", {
                'content': JSON.stringify(parsed)
            })
        }

        // var result = evaluate(parsed);
        var result = evaluate(state);

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
        currentRoot: state.cellsReducer.currentRoot,
        cells: state.cellsReducer.byId[state.cellsReducer.currentRoot].body.map((id) => state.cellsReducer.byId[id]),
        byId: state.cellsReducer.byId,
        focus: state.cellsReducer.focus,
        view_name: state.viewReducer.name,
        view_pattern: state.viewReducer.pattern,
        view_m_get: state.viewReducer.method_get,
        view_m_post: state.viewReducer.method_post
    }
}

export const mapDispatchToProps = {setFocus, setInput, setName, reEvaluate,
    moveFocus, setModified, addCell, initView, patchView, addParam, setParam, addRow}