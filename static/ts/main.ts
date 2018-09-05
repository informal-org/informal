// src/index.ts

import Vue from "vue";
import Vuex from 'vuex'
import { mapState } from 'vuex'
import editor from 'vue2-medium-editor';

import {getCaretCharacterOffsetWithin} from "./utils";


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
    toolbar: {buttons: ['bold', 'italic', 'anchor']},
    autoLink: true
};


let arevelapp = new Vue({
    el: "#app",
    store,
    data: {
        text: "Hello world",
        options: editorOptions,
        isNewLine: false
    },
    mounted: function() {

        this.$on('editorCreated', function(value){
            console.log("Editor created")
            console.log(value);
                // editor.MediumEditor.subscribe("editableKeyup", this.editableKeyup);
        });
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
        mediumEdit() {
            console.log("Applying text edit");
        }
    }
});
