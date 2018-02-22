// src/index.ts

import Vue from "vue";
import Vuex from 'vuex'
import { mapState } from 'vuex'

import {Engine, Value, Group, Table} from './engine/engine'

let eng = new Engine();
new Value("Hello", eng.root);
new Value(23, eng.root);

new Value("=cell2", eng.root);
// new Value("= 1 39 129 459", eng.root);

let g = new Group(eng.root, "mylist")
new Value(1, g)
new Value(2, g)
new Value(3, g)
new Value(4, g)

let tbl = new Table(eng.root, "Products");
let g1 = new Group(tbl, "Item");
new Value("Apple", g1)
new Value("Orange", g1)
new Value("Raspberry", g1)

let g2 = new Group(tbl, "Price");
new Value(10, g2)
new Value(50, g2)
new Value(100, g2)

new Value("=mylist where mylist > 3", eng.root);
new Value("=not (mylist > 2)", eng.root);



Vue.use(Vuex);

const store = new Vuex.Store({
    state: {
        engine: eng,
        editCell: null
    },
    mutations: {
        setEdit(state, payload) {
            state.editCell = payload;
        }
    }
});

import CellView from './components/CellView.vue';
import CellEdit from './components/CellEdit.vue';
import CellList from './components/CellList.vue';
import GroupView from './components/GroupView.vue';
import DestructBtn from './components/DestructBtn.vue';
import CellErrors from './components/CellErrors.vue';
import ResultView from './components/ResultView.vue';
import CellTable from './components/CellTable.vue';

let arevelapp = new Vue({
    el: "#app",
    store,
    computed: {
        ...mapState([
          'engine'
        ])
    },
    components: {
        CellView,
        CellEdit,
        CellList,
        DestructBtn,
        CellErrors,
        GroupView,
        ResultView,
        CellTable
    }
});
