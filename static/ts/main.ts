// src/index.ts

import Vue from "vue";
import Vuex from 'vuex'
import { mapState } from 'vuex'

import {Engine, Value, Group} from './engine/engine'

let eng = new Engine();
new Value("Hello", eng.root);


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

import Cell from './components/Cell.vue';
import CellList from './components/CellList.vue';


let arevelapp = new Vue({
    el: "#app",
    store,
    computed: {
        ...mapState([
          'engine'
        ])
    },
    components: {
        Cell,
        CellList
    }
});
