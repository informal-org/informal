<template>
    <div @click="blockClick" class="InlineEdit">
        <template v-if="isLargeItem">
            <textarea v-model="cell.expr" class="DataInput"></textarea>
        </template>
        <template v-else>
            <input type="text" placeholder="Value" v-model="cell.expr" class="DataInput" autofocus/>
        </template>
        
        <span class="DeleteIcon" aria-label="Delete" v-on:click="cell.destruct()">
            <i class="fas fa-trash-alt" alt="delete" title="delete"></i>
        </span>

        <Cell-Errors v-bind:cell="cell"></Cell-Errors>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";

export default Vue.component('InlineEdit', {
    name: 'InlineEdit',
    props: {
        'cell': {type: Value},
    },
    computed: {
        isLargeItem: function() : boolean {
            if(this.cell._expr_type === "STR" && this.cell.expr.length > 50){
                return true;
            }
            return false;
        },
    },
    methods: {
        blockClick: function(e: Event) {
            // Block click from propagating upwards and selecing something else while you're editing.
            e.stopPropagation();
        }
    }

});
</script>

<style>
</style>
