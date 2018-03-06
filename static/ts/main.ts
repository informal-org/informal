// src/index.ts

import Vue from "vue";
import Vuex from 'vuex'
import { mapState } from 'vuex'

import Raven from 'raven-js';
import RavenVue from 'raven-js/plugins/vue';

// TODO: Some automatic way of disabling this in local dev.
Raven.config('https://cfe92cbbed2f428b99b73ccb9419dab0@sentry.io/296381').addPlugin(RavenVue, Vue).install();



import {Engine, Value, Group, Table, FunctionCall} from './engine/engine'

let eng = new Engine();
window.eng = eng;


new Value("World", eng.root, "Name");

new Value("Hello {{ Name }}! This is Arevel, an environment where you can play around with programming concepts.", eng.root);

new Value("Like excel, you can do math operations by starting a cell with =. Try modifying the equation in the cell below.", eng.root, "Basics");
new Value("= (3000 * 3) + 1", eng.root, "power_level");

new Value("You can refer to cell names to access them in other places.", eng.root, "Variable_names");
new Value("=power_level > 9000", eng.root, "is_powerful");

new Value("Arevel also supports the special boolean values 'True' and 'False' and boolean operators like 'and', 'or', 'not'.", eng.root, "boolean_intro");

new Value("=(true or False) and not (true or False) ", eng.root, "boolean_test");

// new Value("=true or false", eng.root);
// new Value("=cell2", eng.root);
// // new Value("= 1 39 129 459", eng.root);
new Value("To use variables within text, wrap them in curly quotes {{ variable_name }}.", eng.root, "text_intro");

new Value("You can also have a collection of values in a list.", eng.root, "lists_intro");

let g = new Group([], eng.root, "mylist")
new Value(1, g);
new Value(2, g);
new Value(3, g);
new Value(4, g);
new Value(5, g);
new Value(6, g);
new Value(7, g);

// let tbl = new Table([], eng.root, "Products");
// let g1 = new Group([], tbl, "Item");
// new Value("Apple", g1)
// new Value("Orange", g1)
// new Value("Raspberry", g1)

// let g2 = new Group([], tbl, "Price");
// new Value(10, g2)
// new Value(50, g2)
// new Value(100, g2)

// new Value("=products.item = 'Apple' ", eng.root);

// new Value("=mylist where mylist > 3", eng.root);
// new Value("=not (mylist > 2)", eng.root);
// new Value("=products where products.price > 10", eng.root);
// new Value("=cell8.price", eng.root);



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
import FunctionView from './components/FunctionView.vue';
import AddCellBtn from './components/AddCellBtn.vue';
import InlineEdit from './components/InlineEdit.vue';
import ColumnHead from './components/ColumnHead.vue';

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
        CellTable,
        FunctionView,
        AddCellBtn,
        InlineEdit,
        ColumnHead
    },
    methods: {
        addValue(){
            let c = new Value("", eng.root);
            this.$store.commit("setEdit", c);
            window.setTimeout(function(){
                window.location.hash = "edit";
            }, 200);
        },
        addList() {
            let c = new Group([], eng.root);
            this.$store.commit("setEdit", c);
            window.setTimeout(function(){
                window.location.hash = "edit";
            }, 200);
        },
        addFunction() {
            let c = new FunctionCall("", eng.root);
            this.$store.commit("setEdit", c);
            window.setTimeout(function(){
                window.location.hash = "edit";
            }, 200);
        }
    }
});
