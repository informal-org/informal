// src/index.ts

import Vue from "vue";
import Vuex from 'vuex'
import { mapState } from 'vuex'
import editor from 'vue2-medium-editor';



Vue.use(Vuex);

const store = new Vuex.Store({
    state: {
        myText: 'hello'
    },
    mutations: {
        setEdit(state, payload) {

        }
    }
});

var editorOptions = {
      toolbar: {buttons: ['bold', 'italic', 'anchor']}
};



let arevelapp = new Vue({
    el: "#app",
    store,
    data: {
        text: "Hello world",
        options: editorOptions
      },
    computed: {
        // ...mapState([
        //   'engine'
        // ])
    },
    components: {
        'medium-editor': editor
    },
    methods: {
        applyTextEdit() {
            console.log("Applying text edit");
        }
    }
});
