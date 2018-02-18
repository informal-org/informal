// src/index.ts

import Vue from "vue";
import Vuex from 'vuex'
import { mapState } from 'vuex'

import {Engine, Value, Group} from './engine/engine'

let eng = new Engine();
new Value("Hello", eng.root);

new Value(23, eng.root);


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
        GroupView
    }
});
